"""End-to-end tests for the afm CLI, driven through a fake `fm` binary."""

import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
AFM = REPO_ROOT / ".agents" / "skills-optional" / "apple-fm" / "scripts" / "afm.py"
FAKE_FM = REPO_ROOT / "tests" / "apple-fm" / "fixtures" / "fake_fm.py"


class CLITestCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.state_home = Path(self._tmp.name) / "state"
        self.call_log = Path(self._tmp.name) / "calls.jsonl"

    def run_afm(self, args, stdin_text=None, stdin=None, **fake_env):
        env = dict(os.environ)
        env.update(
            AFM_FM_BIN=str(FAKE_FM),
            XDG_STATE_HOME=str(self.state_home),
            FAKE_FM_LOG=str(self.call_log),
        )
        env.pop("AFM_METRICS", None)
        # Bytecode written next to afm.py would change the skill's content hash,
        # which skills-sync.sh uses to detect local modifications.
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        env.update(fake_env)
        kwargs = {"input": stdin_text} if stdin is None else {"stdin": stdin}
        completed = subprocess.run(
            [sys.executable, str(AFM)] + args,
            capture_output=True,
            text=True,
            timeout=20,
            env=env,
            # Failure tests assert on a non-zero exit, so it must not raise.
            check=False,
            **kwargs,
        )
        lines = completed.stdout.strip().splitlines()
        self.assertEqual(len(lines), 1, f"afm must print exactly one line: {completed.stdout!r}")
        return completed.returncode, json.loads(lines[0])

    def calls(self):
        return [json.loads(line) for line in self.call_log.read_text().splitlines()]

    def metrics(self):
        path = self.state_home / "apple-fm-skill" / "metrics.jsonl"
        return [json.loads(line) for line in path.read_text().splitlines()]


class SuccessTests(CLITestCase):
    def test_summarize_from_stdin_returns_structured_response(self):
        code, out = self.run_afm(["summarize"], stdin_text="a long build log")
        self.assertEqual(code, 0)
        self.assertTrue(out["ok"])
        self.assertEqual(out["task"], "summarize")
        self.assertEqual(out["backend"], "fm-cli")
        self.assertEqual(out["response"], {"summary": "s", "key_points": ["k"]})
        self.assertEqual(out["input_tokens"], 120)
        self.assertIn("elapsed_ms", out)
        self.assertNotIn("warnings", out)

    def test_structured_task_passes_schema_and_never_greedy(self):
        # Greedy decoding sent the real model into runaway generation.
        self.run_afm(["summarize"], stdin_text="text")
        respond = next(call for call in self.calls() if call["argv"][0] == "respond")
        self.assertIn("--no-stream", respond["argv"])
        self.assertNotIn("--greedy", respond["argv"])
        self.assertNotIn("-g", respond["argv"])
        self.assertEqual(respond["schema"]["title"], "Summary")

    def test_ask_returns_plain_text_without_schema(self):
        code, out = self.run_afm(["ask", "What is a mutex?"], FAKE_FM_RESPONSE="A lock.")
        self.assertEqual(code, 0)
        self.assertEqual(out["response"], "A lock.")
        respond = next(call for call in self.calls() if call["argv"][0] == "respond")
        self.assertNotIn("--schema", respond["argv"])

    def test_classify_labels_become_schema_enum_and_follow_options(self):
        response = '{"items": [{"input": "x", "label": "net"}]}'
        code, out = self.run_afm(
            ["classify", "--labels", "net, cfg", "net = network"],
            stdin_text="x",
            FAKE_FM_RESPONSE=response,
        )
        self.assertEqual(code, 0, out)
        respond = next(call for call in self.calls() if call["argv"][0] == "respond")
        label_schema = respond["schema"]["properties"]["items"]["items"]["properties"]["label"]
        self.assertEqual(label_schema["enum"], ["net", "cfg"])
        instructions = respond["argv"][respond["argv"].index("-i") + 1]
        self.assertIn("Allowed labels: net, cfg.", instructions)
        self.assertIn("net = network", instructions)

    def test_soft_limit_adds_warning(self):
        code, out = self.run_afm(["summarize"], stdin_text="text", FAKE_FM_TOKENS="6500")
        self.assertEqual(code, 0)
        self.assertIn("soft limit", out["warnings"][0])

    def test_socket_stdin_is_not_read(self):
        # Agent harnesses attach stdin to a socket that never closes. afm must
        # answer from its arguments instead of blocking on that socket.
        ours, theirs = socket.socketpair()
        self.addCleanup(ours.close)
        self.addCleanup(theirs.close)
        code, out = self.run_afm(["ask", "hello"], stdin=theirs, FAKE_FM_RESPONSE="hi")
        self.assertEqual(code, 0)
        self.assertEqual(out["response"], "hi")


class FailureTests(CLITestCase):
    def assert_error(self, result, error_code):
        code, out = result
        self.assertEqual(code, 1)
        self.assertFalse(out["ok"])
        self.assertEqual(out["error"], error_code)
        self.assertTrue(out["recommendation"])

    def test_input_too_large_is_rejected_before_generation(self):
        self.assert_error(self.run_afm(["summarize"], stdin_text="text", FAKE_FM_TOKENS="7001"), "input_too_large")
        self.assertFalse([call for call in self.calls() if call["argv"][0] == "respond"])

    def test_empty_input(self):
        self.assert_error(self.run_afm(["summarize"], stdin_text=""), "empty_input")

    def test_unsupported_task(self):
        self.assert_error(self.run_afm(["translate", "hi"]), "unsupported_task")

    def test_usage_errors_are_json(self):
        self.assert_error(self.run_afm(["ask", "--nope"]), "invalid_arguments")
        self.assert_error(self.run_afm(["ask", "--labels", "a,b", "hi"]), "invalid_arguments")
        self.assert_error(self.run_afm(["classify", "--labels", "only-one", "hi"]), "invalid_arguments")
        self.assert_error(self.run_afm(["ask", "--timeout", "0", "hi"]), "invalid_arguments")

    def test_timeout_kills_hanging_backend(self):
        result = self.run_afm(["summarize", "--timeout", "1"], stdin_text="text", FAKE_FM_MODE="hang")
        self.assert_error(result, "timeout")
        self.assertLess(result[1]["elapsed_ms"], 5000)

    def test_overflow_after_passing_token_check(self):
        result = self.run_afm(["summarize"], stdin_text="text", FAKE_FM_MODE="overflow")
        self.assert_error(result, "generation_overflow")
        self.assertNotIn("\x1b", result[1]["detail"])

    def test_model_unavailable(self):
        self.assert_error(self.run_afm(["summarize"], stdin_text="text", FAKE_FM_MODE="unavailable"), "afm_unavailable")

    def test_missing_binary(self):
        self.assert_error(
            self.run_afm(["summarize"], stdin_text="text", AFM_FM_BIN="/nonexistent/fm"), "afm_unavailable"
        )

    def test_backend_crash(self):
        self.assert_error(self.run_afm(["summarize"], stdin_text="text", FAKE_FM_MODE="crash"), "backend_error")

    def test_non_json_structured_output(self):
        self.assert_error(
            self.run_afm(["summarize"], stdin_text="text", FAKE_FM_RESPONSE="Sure! Here you go"), "invalid_response"
        )

    def test_structured_output_missing_required_key(self):
        self.assert_error(
            self.run_afm(["summarize"], stdin_text="text", FAKE_FM_RESPONSE='{"summary": "s"}'), "invalid_response"
        )

    def test_label_outside_allowed_set(self):
        result = self.run_afm(
            ["classify", "--labels", "a,b"],
            stdin_text="x",
            FAKE_FM_RESPONSE='{"items": [{"input": "x", "label": "c"}]}',
        )
        self.assert_error(result, "invalid_response")


class StatusTests(CLITestCase):
    def test_ready_despite_nonzero_exit_from_fm_models(self):
        code, out = self.run_afm(["status"])
        self.assertEqual(code, 0)
        self.assertTrue(out["ok"])
        self.assertEqual(out["hard_token_limit"], 7000)

    def test_model_not_ready(self):
        code, out = self.run_afm(["status"], FAKE_FM_MODE="model_not_ready")
        self.assertEqual(code, 1)
        self.assertFalse(out["ok"])


class MetricsTests(CLITestCase):
    SECRET = "SECRET-SOURCE-CODE"

    def test_records_sizes_and_outcome_but_never_content(self):
        self.run_afm(
            ["summarize"], stdin_text=self.SECRET, FAKE_FM_RESPONSE='{"summary": "SECRET-REPLY", "key_points": []}'
        )
        self.run_afm(["summarize"], stdin_text=self.SECRET, FAKE_FM_MODE="crash")
        ok_record, failed_record = self.metrics()
        self.assertTrue(ok_record["success"])
        self.assertEqual(ok_record["input_chars"], len(self.SECRET))
        self.assertEqual(failed_record["outcome"], "backend_error")
        raw = (self.state_home / "apple-fm-skill" / "metrics.jsonl").read_text()
        self.assertNotIn("SECRET", raw)

    def test_can_be_disabled(self):
        self.run_afm(["summarize"], stdin_text="text", AFM_METRICS="0")
        self.assertFalse((self.state_home / "apple-fm-skill").exists())

    def test_unwritable_location_warns_without_failing(self):
        blocker = Path(self._tmp.name) / "blocker"
        blocker.write_text("a file where a directory is expected")
        code, out = self.run_afm(["summarize"], stdin_text="text", XDG_STATE_HOME=str(blocker))
        self.assertEqual(code, 0)
        self.assertIn("Metrics were not recorded", out["warnings"][0])


if __name__ == "__main__":
    unittest.main()
