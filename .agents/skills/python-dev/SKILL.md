---
name: python-dev
description: >-
  Python coding standards. Load before writing or editing .py files, pyproject.toml, or
  requirements.txt, and when discussing Python design, typing, or testing.
---

# Python Development

Follow PEP 8 as enforced by the project's formatter and linter (ruff/black). The rules
below apply on top. Target Python 3.11+ unless the project pins an older version.

## Rules

1. **Type hints** on every new or changed public function (parameters and return), in
   modern syntax: `list[str]`, `X | None`, `typing.Protocol` for structural interfaces.
   `# type: ignore` needs the error code and a reason.
2. **Errors.** Raise specific exception types, with custom ones for domain errors. Catch
   the narrowest type; no bare `except:` and no silent `pass`. Chain with
   `raise ... from err`.
3. **Idioms.** Context managers for resources, `pathlib.Path` over string paths,
   f-strings, `logging` (or the project's logger) rather than `print` in library code,
   no mutable default arguments.
4. **Dependencies.** Reach for the stdlib first (`dataclasses`, `enum`, `itertools`,
   `functools`, `subprocess.run(..., check=True)`). Change dependencies through the
   project's tool (uv/poetry/pip-tools); never hand-edit a lockfile.
5. **Tests** in pytest style: plain `assert`, `pytest.raises`,
   `@pytest.mark.parametrize` for cases that share logic, fixtures over shared globals.
   Do not test the stdlib or third-party internals.
6. Code comments in English, including `TODO:` / `FIXME:` / `XXX:` markers.

**Done when** the changed code follows these rules and the `verify` skill passes
(`ruff check`, `ruff format --check`, `mypy` if configured, `pytest`).
