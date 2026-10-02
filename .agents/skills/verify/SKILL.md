---
name: verify
description: >-
  Run the project's lint, type check, and tests. Use after finishing any code change,
  when asked to check lint/types/tests, and before every commit or push, however small.
---

# Verify

The local CI gate: a change is not done, and must not be committed, until lint, type
check, and tests pass on the working tree as it stands. It runs at two depths so the
loop after each edit stays fast and the full cost is paid once, before the commit.

## Find the commands

Use the first source that defines them:

1. `Makefile` targets. `make lint` / `make test` (or `make check`) are the full run. A
   target the project provides for a quick pass (`check-fast`, `test-fast`, or similar)
   is the quick run.
2. `package.json` scripts (`lint`, `typecheck`, `test`)
3. Language defaults: `golangci-lint run` + `go test -race ./...`; `tsc --noEmit`;
   `ruff check` + `mypy` + `pytest`; `shellcheck` for shell scripts

If the project has no lint or test command at all, say so in your summary rather than
skipping silently.

## Quick run: after a code change

Use the project's quick target if it has one. Otherwise:

1. **Lint** the changed files or packages only (`golangci-lint run ./pkg/...`,
   `ruff check <files>`, `eslint --cache <files>`).
2. **Type check** the whole project. A type error usually shows up in a file that
   imports the changed one, so this step is not narrowed; incremental caches keep it
   cheap.
3. **Test** the packages or test files the change affects (`go test ./pkg/...`,
   `vitest related <files>`, `pytest <test files>`). `-race` can wait for the full run.

When the whole suite takes only a few seconds, skip the narrowing and do the full run.

## Full run: before a commit or push

1. Run lint, type check, and the whole test suite, with `-race` for Go. If a full run
   already passed on exactly this working tree, it does not need repeating.
2. Commit only from the state that just passed: no `--no-verify`, no edits between the
   passing run and the commit.
3. Stage only files that belong to the change and mention any unrelated modified files
   instead of sweeping them in.

## Handling failures (both runs)

- Fix every lint and type issue in the files you changed and re-run until clean. Do not
  silence a finding with a suppression directive unless it is a real false positive,
  and then name the rule and the reason.
- On a test failure, fix the code. Change the test only when the behavior change is
  intended and the user confirmed it.
- If you added or changed exported behavior that no test covers, add a focused test for
  it (the happy path and the edge case the change addresses).
- Report, don't fix: issues in files the change did not touch, and tests that were
  already failing before the change.

**Done when** the run for the situation exits 0: the quick run after a change, the full
run before a commit, with the commit holding only the change's files and created from
the verified state.
