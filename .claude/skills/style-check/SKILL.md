---
name: style-check
description: >-
  Check newly added or modified components, pages, and API routes against the
  project's own conventions (auth handling, directory placement, styling rules,
  framework directives). Trigger whenever the user says they created or updated a
  component/page/route and asks if it follows the conventions, or mentions a specific
  project rule such as auth checks, dark mode classes, or inline styles. Keywords:
  "follows the conventions?", "check my new component", "有沒有違反規範",
  "verify auth", "幫我看看新的 route".
---

# Style Check

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/style-check/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync skips skills already present in `~/.claude/skills/` — remove the old copy to pick up changes.

**Purpose:** Enforce project-specific conventions that linters cannot express, on every
new or changed component, page, or API route.

**Actions:**

1. Locate the project's convention source: the project-layer `CLAUDE.md`, a project
   `style-check` skill, or a conventions doc. If the project defines its own
   `style-check` skill, follow that one instead of this generic version.
2. 🔴 Verify each convention that the project declares as mandatory for the changed
   file type (e.g., auth/session check present in API routes, required framework
   directives such as `'use client'` when hooks are used, code placed in the
   prescribed directory). Fix violations before continuing.
3. 🟡 Check stylistic conventions (e.g., no inline styles, theme/dark-mode classes
   present, naming patterns). Report each violation with a concrete fix and apply it
   unless the user objects.
4. 🟡 If the project has no written conventions for the changed file type, say so and
   suggest recording them instead of guessing.

**Pass criteria:** Every 🔴 convention declared by the project passes for the changed
files, and all 🟡 findings are either fixed or explicitly reported.
