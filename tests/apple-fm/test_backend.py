"""Unit tests for backend helpers, plus an opt-in check against the real model."""

import os
import shutil
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS_DIR = REPO_ROOT / ".agents" / "skills-optional" / "apple-fm" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
# Bytecode written next to afm.py would change the skill's content hash, which
# skills-sync.sh uses to detect local modifications.
sys.dont_write_bytecode = True

import afm


class ErrorMappingTests(unittest.TestCase):
    CONTEXT_MESSAGE = "Error: The session's transcript exceeded the model's context size."

    def test_context_error_after_token_check_is_generation_overflow(self):
        error = afm.FMCLIBackend._error_from_stderr(self.CONTEXT_MESSAGE, within_limit=True)
        self.assertEqual(error.code, afm.ERR_GENERATION_OVERFLOW)

    def test_context_error_before_token_check_is_input_too_large(self):
        error = afm.FMCLIBackend._error_from_stderr(self.CONTEXT_MESSAGE, within_limit=False)
        self.assertEqual(error.code, afm.ERR_INPUT_TOO_LARGE)

    def test_detail_is_single_line_and_bounded(self):
        error = afm.FMCLIBackend._error_from_stderr("Error: boom\n\n" + "x" * 1000, within_limit=True)
        self.assertEqual(error.code, afm.ERR_BACKEND)
        self.assertNotIn("\n", error.detail)
        self.assertLessEqual(len(error.detail), afm.STDERR_DETAIL_CHARS)


class InputResolutionTests(unittest.TestCase):
    def test_piped_text_is_content_and_arguments_become_hint(self):
        self.assertEqual(afm.resolve_input("focus on errors", "log body\n"), ("log body", "focus on errors"))

    def test_arguments_are_content_when_nothing_is_piped(self):
        self.assertEqual(afm.resolve_input("just a question", ""), ("just a question", ""))

    def test_ask_places_question_before_text(self):
        prompt, _ = afm.build_request("ask", "log body", "Which file failed?", [])
        self.assertTrue(prompt.startswith("Which file failed?"))
        self.assertTrue(prompt.endswith("log body"))


class BundledResourceTests(unittest.TestCase):
    def test_every_task_has_a_prompt(self):
        for task in afm.TASKS:
            self.assertTrue(afm.load_instructions(task), task)

    def test_structured_schemas_use_no_numeric_fields(self):
        # Numeric fields nested in arrays sent the model into runaway
        # generation during evaluation, so bundled schemas stay string-only.
        for task, spec in afm.TASKS.items():
            if not spec.structured:
                continue
            serialized = str(afm.load_schema(task))
            self.assertNotIn("'integer'", serialized, task)
            self.assertNotIn("'number'", serialized, task)


@unittest.skipUnless(
    os.environ.get("AFM_LIVE_TESTS") == "1" and shutil.which("fm"),
    "set AFM_LIVE_TESTS=1 on a Mac with Apple Intelligence to run",
)
class LiveModelTests(unittest.TestCase):
    def test_extract_round_trip(self):
        backend = afm.FMCLIBackend(binary="fm")
        text = "Add CSV export. It must handle 1M rows. Unsure whether Excel is needed."
        result = afm.run_task(backend, "extract", text, "", [], timeout=30.0)
        self.assertEqual(set(result["response"]), {"requirements", "constraints", "unknowns"})
        self.assertGreater(result["input_tokens"], 0)


if __name__ == "__main__":
    unittest.main()
