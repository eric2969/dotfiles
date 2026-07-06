---
name: docs-sync
description: >-
  Check whether documentation needs updating after a functional change is completed.
  Trigger when a feature, CLI flag, config option, public API, or workflow is added,
  changed, or removed, or when the user asks whether docs/README are up to date.
  Keywords: "update the docs", "README 要更新嗎", "文件要同步嗎", "docs still accurate?",
  "幫我看 README". Applies before finishing any user-facing change.
---

# Docs Sync

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/docs-sync/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Keep documentation truthful — every user-facing change lands together
with the doc updates it invalidates.

## Actions

1. Identify the docs that describe the changed surface: `README.md`, `docs/`,
   `CLAUDE.md` (indexes/tables), command `--help` text, code-level doc comments,
   and example snippets.
2. 🔴 Fix statements the change made false — renamed/removed commands, flags, targets,
   file paths, defaults, or workflows that docs still describe the old way.
3. 🔴 Document new user-facing surface: a new command/flag/target/config option gets
   at least the same level of documentation its siblings have (e.g. a new Makefile
   target appears wherever the other targets are listed).
4. 🟡 Verify examples still work: run documented commands that are cheap to run, or
   flag ones that can no longer work as written.
5. 🟡 Report (do not fix) documentation debt unrelated to the current change.

**Pass criteria:** No document in the repo describes the changed surface incorrectly,
new surface is documented where siblings are, and unrelated doc debt is reported
rather than silently expanded.
