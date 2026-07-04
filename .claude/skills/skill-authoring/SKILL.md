---
name: skill-authoring
description: >-
  Guides writing, creating, updating, or reviewing Claude Code skill files (SKILL.md).
  Use this skill whenever the user wants to create a new skill, modify or improve an existing
  skill file, review a skill for quality, check if a skill is correctly formatted, or asks
  about skill file structure or conventions. Also invoke when the user shows you a SKILL.md
  and asks you to evaluate or improve it. Keywords: "寫一個 skill", "新增 skill", "更新 skill",
  "create skill", "update skill", "write skill", "review skill", "check skill", "skill 格式",
  "skill 怎麼寫". Do not skip even for quick tweaks — consistency matters.
---

# Skill Authoring

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/skill-authoring/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync skips skills already present in `~/.claude/skills/` — remove the old copy to pick up changes.

**Purpose:** Enforce a consistent, high-quality standard when authoring or updating any
skill file across all projects.

---

## Required structure for every skill file

Every skill file must start with YAML frontmatter followed by a Markdown body:

```markdown
---
name: skill-name
description: >-
  One or more sentences explaining WHEN to trigger this skill and WHAT it does.
  Be specific and "pushy" — include keywords, file patterns, and context clues.
  The description is the primary triggering mechanism Claude uses to decide whether
  to invoke this skill.
---

# Skill Name

> ⚠️ (project-layer only) sync notice here

**Actions:** ordered numbered or bulleted steps Claude must follow.

**Pass criteria:** explicit, testable definition of "done".
```

The `name` and `description` fields in YAML frontmatter are **mandatory**. The old
inline `**Trigger:**` and `**Purpose:**` format is deprecated — move these into the
`description` field.

---

## Principles — Creating a new skill

1. **Single responsibility**: one skill governs one clearly defined concern. If a skill is
   doing two unrelated things, split it into two files.

2. **Trigger must be unambiguous**: specify exactly one of:
   - Keyword signals in user requests (e.g., "create skill", "新增 skill")
   - File path patterns (e.g., `src/lib/**/*.ts` modified)
   - Explicit invocation command (e.g., `/deps-check`)
   Never use vague triggers like "when relevant" or "as needed".

3. **Severity labels are mandatory**: every check must be labeled 🔴 (blocking) or
   🟡 (advisory). Unlabeled checks are not actionable.
   - 🔴 Blocking: Claude stops and fixes before continuing.
   - 🟡 Advisory: Claude reports with a fix suggestion, then continues.

4. **Pass criteria are mandatory and testable**: "Looks good" is not a pass criterion.
   Good example: "Command exits 0 and no 🔴 violations found."

5. **No duplication**: before creating a new skill, check whether an existing skill
   already covers the concern. Extend the existing skill rather than creating a parallel one.

6. **Sync notice for project-layer skills**: any skill committed to a project's
   `.claude/skills/` must begin with:
   ```
   > ⚠️ This skill is version-controlled in `.claude/skills/<name>/SKILL.md`.
   > When project conventions change, update this file in the same PR.
   > To sync to your user layer: run the project's sync command
   > (in the dotfiles repo: `make update` or `./setup.ps1 update`).
   ```

7. **User-layer generics use placeholders**: user-layer skills must not contain
   project-specific commands. Use `<lint-command>`, `<test-command>`, `<typecheck-command>`
   as placeholders so the skill works across projects.

---

## Principles — Updating an existing skill

1. **Read the full file before editing**: never patch individual lines without understanding
   the whole skill.

2. **Preserve all mandatory sections**: do not remove or reorder Trigger, Purpose, Actions,
   or Pass criteria. Content within sections may change.

3. **Backward compatibility check**: after updating, verify the new version does not
   contradict sibling skills (e.g., `lint` and `style-check` must not conflict on the same topic).

4. **Project-layer update rule**: if the updated skill lives in `.claude/skills/`, the
   update must be in the same PR as the convention change that prompted it.

5. **Sync user-layer**: after updating a project-layer skill, run the project's sync
   command (in the dotfiles repo: `make update` or `./setup.ps1 update`) to update the
   user-layer copy. Note: sync skips skills that already exist in `~/.claude/skills/`,
   so remove the old user-layer copy first when you need to pick up changes.

---

## What NOT to put in a skill

- Project-specific commands in a user-layer skill (use placeholders instead).
- Rationale or background context — that belongs in docs, not skills.
- Aspirational rules Claude cannot verify (e.g., "make sure the code is readable").
- Multiple unrelated trigger types in one skill.

---

**Pass criteria:** The skill file has YAML frontmatter with `name` and an unambiguous,
trigger-bearing `description`, plus Purpose, Actions, and Pass criteria sections in the
body; every check carries a 🔴/🟡 label; the pass criterion is testable; and
project-layer skills carry the sync notice.
