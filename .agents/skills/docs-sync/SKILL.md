---
name: docs-sync
description: >-
  Keep documentation truthful after a user-facing change. Use before finishing any
  change that adds, changes, or removes a feature, command, flag, config option, public
  API, or workflow, and when asked whether the README or docs are up to date.
---

# Docs Sync

A user-facing change lands together with the doc updates it makes necessary.

## Steps

1. **Find the docs that describe the changed surface:** `README.md`, `docs/`,
   `CLAUDE.md` indexes and tables, `--help` text, doc comments, example snippets.
2. **Fix what the change made false:** renamed or removed commands, flags, targets,
   paths, defaults, or workflows still described the old way.
3. **Document new surface** to the level its siblings have. A new Makefile target, for
   example, appears everywhere the other targets are listed.
4. **Check the examples.** Run documented commands that are cheap to run, and flag any
   that can no longer work as written.

Doc problems unrelated to the current change: report them, do not fix them here.

**Done when** no document describes the changed surface incorrectly and new surface is
documented where its siblings are.
