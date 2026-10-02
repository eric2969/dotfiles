---
name: style-check
description: >-
  Check new or changed components, pages, and API routes against the project's own
  written conventions (auth handling, directory placement, styling rules, framework
  directives). Use when asked whether such a file follows the conventions or a specific
  project rule.
---

# Style Check

Covers the project conventions a linter cannot express.

## Steps

1. **Find the conventions:** the project's `CLAUDE.md`, a conventions doc, or a
   project-level `style-check` skill. If the project has its own `style-check` skill,
   follow that one instead of this generic version.
2. **Mandatory conventions** for the changed file type (an auth/session check in API
   routes, a required directive such as `'use client'`, code in the prescribed
   directory): verify each one and fix violations.
3. **Stylistic conventions** (no inline styles, theme/dark-mode classes, naming
   patterns): report each violation with a concrete fix, and apply it unless the user
   objects.
4. **No written conventions** for this file type: say so and suggest recording them.
   Do not infer rules from a guess.

**Done when** every mandatory convention passes for the changed files and each
stylistic finding is fixed or reported.
