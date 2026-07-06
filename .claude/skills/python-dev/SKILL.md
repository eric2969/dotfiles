---
name: python-dev
description: >-
  Python development standards. Trigger whenever creating or editing .py files,
  pyproject.toml, requirements.txt, or discussing Python code design, typing, or
  testing. Keywords: "Python", "py", "pytest", "pip", "uv", "寫一個 Python",
  "型別註記". Load BEFORE writing any Python code.
---

# Python Development

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/python-dev/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Apply consistent Python standards (typing, style, testing, packaging) to
every Python change. Target: Python 3.11+ unless the project pins older.

## Core rules

1. 🔴 Code comments in English only. Markers: `# TODO:` / `# FIXME:` / `# XXX:` with
   clear, actionable descriptions.
2. 🔴 Type hints on all new/changed public functions and methods (params + return).
   Use modern syntax: `list[str]`, `X | None`, `typing.Protocol` for structural
   interfaces. No `# type: ignore` without naming the error code and a reason.
3. 🔴 Follow PEP 8 via the project's formatter/linter (ruff/black); naming:
   `snake_case` functions/variables, `PascalCase` classes, `UPPER_CASE` constants.
4. 🔴 Errors: raise specific exception types (define custom exceptions for domain
   errors); never bare `except:`; catch the narrowest exception; use
   `raise ... from err` to preserve the chain; no silent `pass` in except blocks.
5. 🔴 Resource handling with context managers (`with`); `pathlib.Path` over string
   paths; f-strings over `%`/`.format()`; `logging` (or the project's logger) over
   `print` in library code.
6. 🔴 Dependency changes go through the project's tool (uv/poetry/pip-tools) so the
   lockfile stays consistent — never hand-edit a lockfile.
7. 🟡 Prefer stdlib (`dataclasses`, `enum`, `itertools`, `functools`, `json`,
   `subprocess.run` with `check=True`) before adding a dependency.
8. 🟡 Keep functions small and focused; early returns over deep nesting; avoid mutable
   default arguments.
9. 🟡 Tests with pytest style: plain `assert`, `pytest.raises` for errors,
   `@pytest.mark.parametrize` for same-logic cases; fixtures over shared globals;
   do not test stdlib or third-party internals.

## Verification

Run per the `verify` skill; Python defaults are `ruff check` (+ `ruff format --check`),
`mypy` (if configured), and `pytest`.

**Pass criteria:** Changed Python code satisfies every 🔴 rule above, and `verify`
passes (lint, type check, and tests exit 0).
