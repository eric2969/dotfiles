# Backend notes

## Layout

```text
afm.py
  main()            argument parsing, JSON envelope, metrics
  run_task()        token pre-check, schema handling, response validation
  ModelBackend      interface: availability / count_tokens / generate
  FMCLIBackend      the only place that invokes `fm`
```

`scripts/afm` is a symlink to `afm.py`, which resolves its own real path to find `prompts/` and `schemas/`. Symlinking `afm` onto your `PATH` therefore works.

The skill lives in the dotfiles repo under `.agents/skills-optional/apple-fm/`. `setup.sh` installs it to `~/.agents/skills/apple-fm/` only on an Apple silicon Mac where `fm` exists, its Legal Notice & Terms have been agreed to, and `fm models` reports the system model ready; `skill-links.sh` then links it into `~/.claude/skills` and `~/.codex/skills`.

Requirements: macOS with Apple Intelligence enabled and `/usr/bin/fm`. Python 3.9+ standard library only, so the system Python is enough.

## Why the `fm` CLI and not the Python SDK

`apple-fm-sdk` compiles Swift bindings at install time and needs a full Xcode installation plus Python 3.10+. `fm` ships with macOS and covers everything this skill needs: stdin input, instructions, structured output, token counting. The SDK only becomes interesting for a long-lived process that reuses sessions, which V1 deliberately avoids. Add it as a second `ModelBackend` if that day comes.

## How `fm` is invoked

```text
fm count-tokens --quiet -i <instructions>              < prompt
fm respond --no-stream -i <instructions> [--schema f]   < prompt
fm models
```

Behaviours the wrapper compensates for:

- stderr ignores `NO_COLOR`; ANSI codes are stripped before anything is reported.
- `fm models` exits 1 whenever any model is unavailable, including Private Cloud Compute. Availability is read from the `✓ system` line, not the exit code.
- A response that fills the context produces the same "exceeded the model's context size" message as an oversized input. Because input size is checked first, that message after a passed check is reported as `generation_overflow`.
- Runaway generation can last minutes. `subprocess.run(timeout=...)` kills the child, so the timeout is a hard stop.
- `--greedy` is never passed. Greedy decoding hung on every run of a 3.8K-token jest log during evaluation. Sampling still hangs on some inputs, which is why the timeout exists; results are consequently not reproducible run to run.

Stdin is read only when it is a pipe or a regular file. Agent harnesses attach stdin to a socket that never closes; reading it would hang forever.

## Schemas

Plain JSON Schema works; `fm schema object` is not required. Supported and relied on: `type`, `properties`, `required`, `items`, `enum`, `description`, `additionalProperties`. Keep fields as strings. A schema with `integer` fields inside an array of objects caused runaway generation during evaluation, and `tests/apple-fm/test_backend.py` fails if a bundled schema reintroduces numeric fields.

For `classify --labels`, the CLI copies `schemas/classify.json`, injects the labels as an `enum`, and writes it to a temporary file for that call.

## Error codes

| Code | Meaning |
|---|---|
| `afm_unavailable` | `fm` missing, not executable, or the model reports it is not available |
| `input_too_large` | Prompt plus instructions exceed 7,000 tokens; rejected before generation |
| `empty_input` | No argument text and nothing piped |
| `timeout` | Time budget exhausted; the `fm` process was killed |
| `generation_overflow` | The response filled the context window |
| `backend_error` | Any other non-zero exit from `fm`; `detail` holds the first 300 characters of stderr |
| `invalid_response` | Structured output was not JSON, lacked a required key, or used a label outside `--labels` |
| `invalid_schema` | A bundled prompt or schema file is missing or malformed |
| `unsupported_task` | Unknown task name |
| `invalid_arguments` | Bad flags or flag combination |

Exit status is 0 when `ok` is true and 1 otherwise. Stdout is always exactly one JSON line.

## Metrics

One JSON line per call is appended to `$XDG_STATE_HOME/apple-fm-skill/metrics.jsonl` (default `~/.local/state/apple-fm-skill/`):

```json
{"timestamp": "2026-09-21T01:10:00+0800", "task": "summarize", "backend": "fm-cli", "input_chars": 7248, "input_tokens": 1810, "elapsed_ms": 931, "success": true, "outcome": "ok"}
```

Prompts, source text and responses are never written. If the file cannot be written the call still succeeds and the envelope carries a warning. Set `AFM_METRICS=0` to disable.

Useful for judging whether delegation pays off:

```bash
jq -s 'group_by(.task)[] | {task: .[0].task, calls: length, ok: (map(select(.success)) | length), median_ms: (map(.elapsed_ms) | sort | .[length/2|floor])}' \
  ~/.local/state/apple-fm-skill/metrics.jsonl
```

## Environment variables

| Variable | Purpose |
|---|---|
| `AFM_FM_BIN` | Path to the `fm` binary; tests point this at `tests/fixtures/fake_fm.py` |
| `AFM_METRICS` | `0` disables metrics |
| `XDG_STATE_HOME` | Relocates the metrics file |

## Tests

```bash
make test                                                  # whole dotfiles suite, includes the two below
python3 -m unittest discover -s tests/apple-fm            # fake backend, no model needed
AFM_LIVE_TESTS=1 python3 -m unittest discover -s tests/apple-fm   # adds a real-model round trip
```

## Adding a backend

Subclass `ModelBackend`, implement `availability`, `count_tokens` and `generate`, raise `AFMError` with one of the codes above on failure, and select it in `main()`. Tasks, prompts, schemas and the JSON envelope stay unchanged, which is what lets an MCP server or another local runtime reuse them later.
