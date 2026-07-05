---
name: pre-commit-check
description: >-
  Run the project's verification (tests and static analysis) immediately before
  creating any git commit. Trigger whenever a git commit is about to be made —
  the user asks to commit or push, a task ends with "commit this", or an amend
  is requested. Keywords: "commit", "git commit", "提交", "幫我 commit",
  "commit 前檢查", "push 上去". Applies to every commit, including small ones.
---

# Pre-Commit Check

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/pre-commit-check/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Act as the local CI gate — no commit is created while the project's
verification fails.

**Actions:**

1. Detect the project's verification commands in this order: `Makefile` targets
   (`make test`, `make lint`) → `package.json` scripts (`npm test`, `npm run lint`) →
   language defaults (`go test -race ./...` + `golangci-lint run`,
   `shellcheck <scripts>` for shell projects, `<test-command>` / `<lint-command>`).
2. 🔴 Run the test command. If it fails, fix the cause and re-run; never commit on a
   failing suite and never bypass with `--no-verify` or by skipping the run.
3. 🔴 Run the lint / static-analysis command and treat failures the same way.
4. 🟡 Review `git status` before committing: only stage files related to the change,
   and report any unrelated modified files instead of sweeping them into the commit.
5. 🟡 If the project defines no test or lint command at all, say so in the commit
   summary instead of silently skipping verification.

**Pass criteria:** The test and lint commands both exit 0 in the same working tree
state that gets committed, and the commit contains only files related to the change.
