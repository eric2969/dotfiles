---
name: verify
description: >-
  Run the project's full verification — lint, type check, and tests — whenever code
  changes are completed or a git commit is about to be made. Trigger when the user
  finishes writing/fixing/refactoring code, asks to verify it, mentions lint, type
  errors, tests, or compile checks, and ALWAYS before any commit or push. Keywords:
  "run lint", "check types", "run tests", "跑 lint", "跑測試", "commit", "git commit",
  "提交", "幫我 commit", "push 上去", "tests still passing?", "verify". Applies to
  every commit, including small ones.
---

# Verify

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/verify/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Single verification gate for all code changes — catch lint, type, and test
failures immediately after edits, and act as the local CI gate before every commit.

## Command detection (do once, reuse for all steps)

Detect each command in this order, stopping at the first match:

1. `Makefile` targets: `make lint`, `make test`
2. `package.json` scripts: `npm run lint`, `npm test`, `npm run typecheck`
3. Language defaults: `golangci-lint run` + `go vet ./...` + `go test -race ./...`,
   `tsc --noEmit`, `ruff check` + `mypy` + `pytest`, `shellcheck <scripts>`,
   or `<lint-command>` / `<typecheck-command>` / `<test-command>`

## Actions

Scope by situation: after a code edit, run steps 1–3. Before a commit, run steps 1–5.

1. 🔴 **Lint** — run the lint command. On non-zero exit, fix every reported issue in
   the files just changed, then re-run until clean. Never suppress with `nolint`/
   `eslint-disable`-style directives without written justification.
2. 🔴 **Type check** — run the type-check command and fix all errors the same way.
3. 🔴 **Test** — run tests scoped to the changed package/module first, then the full
   suite. If a test fails, fix the code (or the test, only if the behavior change is
   intentional and the user confirmed) and re-run until green. If the change added or
   modified exported behavior with no test, write a focused unit test (happy path +
   the edge case the change addresses); do not write tests solely for coverage numbers.
4. 🔴 **Commit gate** (commit situations only) — never commit on a failing step and
   never bypass with `--no-verify` or by skipping the run. Verification must pass in
   the same working-tree state that gets committed.
5. 🟡 **Staging hygiene** (commit situations only) — review `git status`: stage only
   files related to the change; report unrelated modified files instead of sweeping
   them into the commit.

**Advisory notes (all situations):**

- 🟡 Issues in files NOT touched by the current change: report with a suggested fix,
  but do not modify unrelated files.
- 🟡 Tests already failing before the change: report separately; do not silently fix
  or skip them.
- 🟡 If the project defines no lint or test command at all, say so explicitly (in the
  commit summary when committing) instead of silently skipping verification.

**Pass criteria:** Lint, type-check, and test commands all exit 0 with no 🔴 issue
remaining in the changed files; for commits, the commit contains only files related to
the change and was created from the verified working-tree state.
