#!/usr/bin/env python3
"""afm: bounded, machine-readable access to Apple Foundation Models.

A main coding agent uses this CLI to hand small, verifiable text tasks to the
on-device model. Every outcome, success or failure, is a single JSON object on
stdout so the caller never has to parse prose or guess at an exit path.

Standard library only, and compatible with the Python 3.9 that ships with
macOS, so the skill works without any installation step.
"""

from __future__ import annotations

import argparse
import copy
import dataclasses
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, NoReturn

SKILL_ROOT = Path(__file__).resolve().parent.parent
PROMPTS_DIR = SKILL_ROOT / "prompts"
SCHEMAS_DIR = SKILL_ROOT / "schemas"

# Measured on AFM 3 Core Advanced: an 8,025-token prompt is accepted and a
# 9,025-token prompt is rejected. The response shares that window, so the hard
# limit leaves roughly 1,000 tokens for output.
SOFT_TOKEN_LIMIT = 6000
HARD_TOKEN_LIMIT = 7000

DEFAULT_TIMEOUT_SECONDS = 30.0
TOKEN_COUNT_TIMEOUT_SECONDS = 10.0
STDERR_DETAIL_CHARS = 300

ERR_UNAVAILABLE = "afm_unavailable"
ERR_INPUT_TOO_LARGE = "input_too_large"
ERR_EMPTY_INPUT = "empty_input"
ERR_TIMEOUT = "timeout"
ERR_BACKEND = "backend_error"
ERR_GENERATION_OVERFLOW = "generation_overflow"
ERR_INVALID_SCHEMA = "invalid_schema"
ERR_INVALID_RESPONSE = "invalid_response"
ERR_UNSUPPORTED_TASK = "unsupported_task"
ERR_INVALID_ARGUMENTS = "invalid_arguments"

RECOMMENDATIONS = {
    ERR_UNAVAILABLE: "Apple Foundation Models is not usable here. Do the task yourself and do not call afm again this session.",
    ERR_INPUT_TOO_LARGE: "Do not auto-chunk. Narrow the input with grep/head/sed first if delegation is still worthwhile, otherwise do the task yourself.",
    ERR_EMPTY_INPUT: "Pass text as an argument or pipe it on stdin.",
    ERR_TIMEOUT: "Do the task yourself. Do not retry.",
    ERR_BACKEND: "Do the task yourself. Do not retry.",
    ERR_GENERATION_OVERFLOW: "The model generated until its context filled. Do the task yourself. Do not retry.",
    ERR_INVALID_SCHEMA: "A bundled schema is missing or malformed. Do the task yourself.",
    ERR_INVALID_RESPONSE: "The model returned output that does not match the schema. Do the task yourself. Do not retry.",
    ERR_UNSUPPORTED_TASK: "Use one of: ask, summarize, extract, classify, brainstorm, critique, status.",
    ERR_INVALID_ARGUMENTS: "Fix the command line. Run afm --help.",
}

ANSI_PATTERN = re.compile(r"\x1b\[[0-9;]*m")
CONTEXT_EXCEEDED_MARKER = "exceeded the model's context size"
UNAVAILABLE_MARKERS = ("not available", "unavailable", "not enabled", "not supported")
SYSTEM_MODEL_READY_PATTERN = re.compile(r"✓\s+system")


class AFMError(Exception):
    """A failure that maps to one machine-readable error code."""

    def __init__(self, code: str, detail: str = "") -> None:
        super().__init__(detail or code)
        self.code = code
        self.detail = detail


@dataclasses.dataclass(frozen=True)
class TaskSpec:
    name: str
    structured: bool


TASKS: dict[str, TaskSpec] = {
    "ask": TaskSpec("ask", structured=False),
    "summarize": TaskSpec("summarize", structured=True),
    "extract": TaskSpec("extract", structured=True),
    "classify": TaskSpec("classify", structured=True),
    "brainstorm": TaskSpec("brainstorm", structured=True),
    "critique": TaskSpec("critique", structured=True),
}
STATUS_COMMAND = "status"


def strip_ansi(text: str) -> str:
    return ANSI_PATTERN.sub("", text)


class ModelBackend:
    """Interface between the task router and a concrete model runtime."""

    name = "abstract"

    def availability(self) -> tuple[bool, str]:
        raise NotImplementedError

    def count_tokens(self, prompt: str, instructions: str, timeout: float) -> int:
        raise NotImplementedError

    def generate(
        self,
        prompt: str,
        instructions: str,
        schema_path: Path | None,
        timeout: float,
    ) -> str:
        raise NotImplementedError


class FMCLIBackend(ModelBackend):
    """Drives the `fm` command line tool that ships with macOS.

    Every `fm` invocation lives in this class because the tool is new and its
    flags and messages may change between macOS releases.
    """

    name = "fm-cli"

    def __init__(self, binary: str | None = None) -> None:
        self._binary = binary or os.environ.get("AFM_FM_BIN") or "fm"

    def _run(self, args: list[str], stdin_text: str, timeout: float) -> subprocess.CompletedProcess:
        if shutil.which(self._binary) is None:
            raise AFMError(ERR_UNAVAILABLE, "The fm command was not found on PATH.")
        env = dict(os.environ, NO_COLOR="1")
        try:
            # subprocess.run kills the child on timeout, which is what stops a
            # runaway generation from outliving this call.
            return subprocess.run(
                [self._binary] + args,
                input=stdin_text,
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env,
                check=False,
            )
        except subprocess.TimeoutExpired:
            raise AFMError(ERR_TIMEOUT, f"No response within {timeout:.1f} seconds.")
        except OSError as exc:
            raise AFMError(ERR_UNAVAILABLE, f"Could not execute fm: {exc}")

    def availability(self) -> tuple[bool, str]:
        # `fm models` exits non-zero when any listed model is unavailable, such
        # as Private Cloud Compute, so the text is the signal, not the code.
        try:
            completed = self._run(["models"], "", TOKEN_COUNT_TIMEOUT_SECONDS)
        except AFMError as exc:
            return False, exc.detail
        listing = strip_ansi(completed.stdout + completed.stderr)
        if SYSTEM_MODEL_READY_PATTERN.search(listing):
            return True, "On-device system model is ready."
        return False, "fm is installed but the on-device system model is not ready."

    def count_tokens(self, prompt: str, instructions: str, timeout: float) -> int:
        completed = self._run(["count-tokens", "--quiet", "-i", instructions], prompt, timeout)
        if completed.returncode != 0:
            raise self._error_from_stderr(completed.stderr, within_limit=False)
        try:
            return int(completed.stdout.strip())
        except ValueError:
            raise AFMError(ERR_BACKEND, "fm count-tokens did not print an integer.")

    def generate(
        self,
        prompt: str,
        instructions: str,
        schema_path: Path | None,
        timeout: float,
    ) -> str:
        # Sampling is deliberate. With --greedy the model fell into endless
        # generation on a 3.8K-token test log that sampling handled in 9 s.
        args = ["respond", "--no-stream", "-i", instructions]
        if schema_path is not None:
            args += ["--schema", str(schema_path)]
        completed = self._run(args, prompt, timeout)
        if completed.returncode != 0:
            raise self._error_from_stderr(completed.stderr, within_limit=True)
        return strip_ansi(completed.stdout).strip()

    @staticmethod
    def _error_from_stderr(stderr: str, within_limit: bool) -> AFMError:
        message = " ".join(strip_ansi(stderr).split())[:STDERR_DETAIL_CHARS]
        lowered = message.lower()
        if CONTEXT_EXCEEDED_MARKER in lowered:
            # When the input already passed the token check, the window was
            # filled by the response, not by the caller's input.
            code = ERR_GENERATION_OVERFLOW if within_limit else ERR_INPUT_TOO_LARGE
            return AFMError(code, message)
        if any(marker in lowered for marker in UNAVAILABLE_MARKERS):
            return AFMError(ERR_UNAVAILABLE, message)
        return AFMError(ERR_BACKEND, message)


def read_piped_stdin() -> str:
    """Read stdin only when it is a pipe or a redirected file.

    Agent harnesses often attach stdin to a socket that never closes, so an
    unconditional read would hang forever. Terminals are skipped for the same
    reason.
    """
    try:
        mode = os.fstat(sys.stdin.fileno()).st_mode
    except (OSError, ValueError):
        return ""
    if stat.S_ISFIFO(mode) or stat.S_ISREG(mode):
        return sys.stdin.read()
    return ""


def resolve_input(arg_text: str, stdin_text: str) -> tuple[str, str]:
    """Return (content, hint).

    Piped text is always the content. Arguments are the content when nothing is
    piped, and otherwise a short hint that steers the task.
    """
    arg_text = arg_text.strip()
    stdin_text = stdin_text.strip()
    if stdin_text:
        return stdin_text, arg_text
    return arg_text, ""


def load_instructions(task: str) -> str:
    path = PROMPTS_DIR / f"{task}.txt"
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise AFMError(ERR_INVALID_SCHEMA, f"Cannot read prompt {path.name}: {exc}")


def load_schema(task: str) -> dict[str, Any]:
    path = SCHEMAS_DIR / f"{task}.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise AFMError(ERR_INVALID_SCHEMA, f"Cannot load schema {path.name}: {exc}")


def parse_labels(raw: str | None) -> list[str]:
    if not raw:
        return []
    labels = [label.strip() for label in raw.split(",") if label.strip()]
    if len(labels) < 2:
        raise AFMError(ERR_INVALID_ARGUMENTS, "--labels needs at least two comma-separated labels.")
    return labels


def schema_with_labels(schema: dict[str, Any], labels: list[str]) -> dict[str, Any]:
    """Constrain classify output to the allowed labels with a JSON Schema enum."""
    constrained = copy.deepcopy(schema)
    try:
        constrained["properties"]["items"]["items"]["properties"]["label"]["enum"] = labels
    except (KeyError, TypeError) as exc:
        raise AFMError(ERR_INVALID_SCHEMA, f"classify schema has an unexpected shape: {exc}")
    return constrained


def build_request(task: str, content: str, hint: str, labels: list[str]) -> tuple[str, str]:
    """Return (prompt, instructions) for the model."""
    instructions = load_instructions(task)
    if labels:
        instructions += " Allowed labels: {}.".format(", ".join(labels))
    if task == "ask":
        prompt = f"{hint}\n\nText:\n{content}" if hint else content
        return prompt, instructions
    if hint:
        instructions += f" Requester guidance: {hint}"
    return content, instructions


def parse_structured(raw: str, schema: dict[str, Any], labels: list[str]) -> dict[str, Any]:
    try:
        parsed = json.loads(raw)
    except ValueError:
        raise AFMError(ERR_INVALID_RESPONSE, "Model output is not valid JSON.")
    if not isinstance(parsed, dict):
        raise AFMError(ERR_INVALID_RESPONSE, "Model output is not a JSON object.")
    missing = [key for key in schema.get("required", []) if key not in parsed]
    if missing:
        raise AFMError(ERR_INVALID_RESPONSE, "Missing keys: {}".format(", ".join(missing)))
    if labels:
        used = {item.get("label") for item in parsed.get("items", []) if isinstance(item, dict)}
        unexpected = sorted(str(label) for label in used - set(labels))
        if unexpected:
            raise AFMError(ERR_INVALID_RESPONSE, "Labels outside the allowed set: {}".format(", ".join(unexpected)))
    return parsed


def run_task(
    backend: ModelBackend, task: str, content: str, hint: str, labels: list[str], timeout: float
) -> dict[str, Any]:
    """Execute one delegated task and return the success fields of the envelope."""
    spec = TASKS[task]
    if not content:
        raise AFMError(ERR_EMPTY_INPUT, "No input text was provided.")
    deadline = time.monotonic() + timeout
    prompt, instructions = build_request(task, content, hint, labels)

    input_tokens = backend.count_tokens(prompt, instructions, min(TOKEN_COUNT_TIMEOUT_SECONDS, timeout))
    if input_tokens > HARD_TOKEN_LIMIT:
        raise AFMError(
            ERR_INPUT_TOO_LARGE,
            f"Input is {input_tokens} tokens; the limit is {HARD_TOKEN_LIMIT}.",
        )
    warnings = []
    if input_tokens > SOFT_TOKEN_LIMIT:
        warnings.append(f"Input is {input_tokens} tokens, above the {SOFT_TOKEN_LIMIT} soft limit; quality may drop.")

    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise AFMError(ERR_TIMEOUT, "Time budget was spent before generation started.")

    if not spec.structured:
        text = backend.generate(prompt, instructions, None, remaining)
        if not text:
            raise AFMError(ERR_INVALID_RESPONSE, "Model returned an empty response.")
        return {"response": text, "input_tokens": input_tokens, "warnings": warnings}

    schema = load_schema(task)
    if labels:
        schema = schema_with_labels(schema, labels)
    with tempfile.TemporaryDirectory(prefix="afm-") as workdir:
        schema_path = Path(workdir) / "schema.json"
        schema_path.write_text(json.dumps(schema), encoding="utf-8")
        raw = backend.generate(prompt, instructions, schema_path, remaining)
    return {"response": parse_structured(raw, schema, labels), "input_tokens": input_tokens, "warnings": warnings}


def metrics_path() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state_home) / "apple-fm-skill" / "metrics.jsonl"


def record_metrics(record: dict[str, Any]) -> str | None:
    """Append one metrics line. Returns a warning string when it cannot.

    Only sizes, timings and outcome codes are recorded. Prompts, source text
    and model responses never reach this file.
    """
    if os.environ.get("AFM_METRICS", "1") == "0":
        return None
    path = metrics_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError as exc:
        return f"Metrics were not recorded: {exc}"
    return None


class JSONArgumentParser(argparse.ArgumentParser):
    """Reports usage errors as AFMError so they reach stdout as JSON."""

    def error(self, message: str) -> NoReturn:
        raise AFMError(ERR_INVALID_ARGUMENTS, message)


def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(
        prog="afm",
        description="Delegate a small, verifiable text task to Apple Foundation Models. Always prints one JSON object.",
        epilog="Tasks: ask, summarize, extract, classify, brainstorm, critique, status. "
        "Piped stdin is the content; arguments are the content when nothing is piped, otherwise a steering hint.",
    )
    parser.add_argument("task", help="task name, or 'status' to check availability")
    parser.add_argument("text", nargs="*", help="input text, or a hint when stdin is piped")
    parser.add_argument(
        "--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS, help="seconds before giving up (default 30)"
    )
    parser.add_argument("--labels", help="classify only: comma-separated allowed labels")
    return parser


def status_envelope(backend: ModelBackend) -> dict[str, Any]:
    available, detail = backend.availability()
    return {
        "ok": available,
        "task": STATUS_COMMAND,
        "backend": backend.name,
        "detail": detail,
        "soft_token_limit": SOFT_TOKEN_LIMIT,
        "hard_token_limit": HARD_TOKEN_LIMIT,
        "default_timeout_seconds": DEFAULT_TIMEOUT_SECONDS,
    }


def error_envelope(task: str | None, backend_name: str, error: AFMError, elapsed_ms: int) -> dict[str, Any]:
    return {
        "ok": False,
        "task": task,
        "backend": backend_name,
        "error": error.code,
        "detail": error.detail,
        "recommendation": RECOMMENDATIONS.get(error.code, "Do the task yourself."),
        "elapsed_ms": elapsed_ms,
    }


def main(argv: list[str] | None = None) -> int:
    started = time.monotonic()
    backend: ModelBackend = FMCLIBackend()
    task: str | None = None
    content = ""

    def elapsed_ms() -> int:
        return int((time.monotonic() - started) * 1000)

    try:
        # Intermixed parsing lets a hint follow an option, as in
        # `afm classify --labels a,b "hint"`.
        args = build_parser().parse_intermixed_args(argv)
        task = args.task
        if task == STATUS_COMMAND:
            envelope = status_envelope(backend)
            print(json.dumps(envelope, ensure_ascii=False))
            return 0 if envelope["ok"] else 1
        if task not in TASKS:
            raise AFMError(ERR_UNSUPPORTED_TASK, f"Unknown task: {task}")
        if args.timeout <= 0:
            raise AFMError(ERR_INVALID_ARGUMENTS, "--timeout must be positive.")
        if args.labels and task != "classify":
            raise AFMError(ERR_INVALID_ARGUMENTS, "--labels only applies to classify.")
        labels = parse_labels(args.labels)
        content, hint = resolve_input(" ".join(args.text), read_piped_stdin())
        result = run_task(backend, task, content, hint, labels, args.timeout)
    except AFMError as error:
        envelope = error_envelope(task, backend.name, error, elapsed_ms())
        outcome = error.code
    else:
        envelope = {"ok": True, "task": task, "backend": backend.name}
        envelope.update(result)
        envelope["elapsed_ms"] = elapsed_ms()
        if not envelope["warnings"]:
            del envelope["warnings"]
        outcome = "ok"

    metrics_warning = record_metrics(
        {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "task": task,
            "backend": backend.name,
            "input_chars": len(content),
            "input_tokens": envelope.get("input_tokens"),
            "elapsed_ms": envelope["elapsed_ms"],
            "success": envelope["ok"],
            "outcome": outcome,
        }
    )
    if metrics_warning:
        envelope.setdefault("warnings", []).append(metrics_warning)

    print(json.dumps(envelope, ensure_ascii=False))
    return 0 if envelope["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
