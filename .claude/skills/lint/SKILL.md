---
name: lint
description: >-
  Run the project's lint and type checks after any source-code edit is completed.
  Trigger whenever the user says they finished writing, fixing, or refactoring code
  and asks to verify it, or mentions lint, ESLint, golangci-lint, tsc, type errors,
  or compile checks. Keywords: "run lint", "check types", "跑 lint", "確認沒有
  TypeScript 錯誤", "make sure eslint is happy", "verify no type issues".
---

# Lint

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/lint/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Catch lint and type errors immediately after code changes, before the user
moves on or commits.

**Actions:**

1. Detect the project's lint command in this order: `Makefile` target (`make lint`) →
   `package.json` script (`npm run lint`) → language default (`golangci-lint run`,
   `<lint-command>`). Detect the type-check command the same way (`tsc --noEmit`,
   `go vet ./...`, `<typecheck-command>`).
2. 🔴 Run the lint command. If it exits non-zero, fix every reported issue in the files
   just changed, then re-run until clean. Do not suppress warnings with `nolint`/
   `eslint-disable` style directives without justification.
3. 🔴 Run the type-check command and fix all errors the same way.
4. 🟡 If lint reports issues in files NOT touched by the current change, report them
   with a suggested fix but do not modify unrelated files.

**Pass criteria:** Both the lint command and the type-check command exit 0, and no 🔴
issue remains in the changed files.
