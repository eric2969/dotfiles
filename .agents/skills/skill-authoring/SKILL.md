---
name: skill-authoring
description: >-
  Conventions for writing, updating, and reviewing skill files (SKILL.md). Use when
  creating a new skill, editing or improving an existing one, or reviewing a skill's
  structure and quality.
---

# Skill Authoring

A skill is a briefing for a capable model that has none of your context. Write what it
could not work out on its own: the choices specific to this user or project, the reason
behind each, and what "done" means. Leave out what any good engineer already does.

## Shape

```markdown
---
name: skill-name
description: >-
  What the skill does, then when to use it, in plain sentences.
---

# Skill Name

One or two sentences on the goal and why it matters.

## Steps (or Rules)

Ordered steps for a workflow; a short rule list for standards.

**Done when** <a condition that can be checked>.
```

## Writing the description

The description is all the model sees when deciding whether to load the skill, and
every description is loaded into every session, so each word costs.

- State what the skill does and the situations that call for it. Name file types or
  events ("before every commit") when they are the trigger.
- Skip keyword lists, quoted example phrases, and capitals for emphasis. The model
  matches on meaning in any language, and loud wording makes a skill fire where it does
  not belong.
- If a skill is easy to miss because nothing in the request names it (it must run
  *before* some action, say), put that timing in the description.

## Writing the body

- **One concern per skill.** Before adding a skill, check whether an existing one
  covers the concern, and extend that one.
- **Give the reason with the rule** when the reason is not obvious. A rule with a
  reason gets applied sensibly in cases the rule did not foresee.
- **Spend words on the judgment calls**, not on what the model does by default.
  Restating standard practice (PEP 8 naming, checking errors) only dilutes the rules
  that are yours.
- **Separate "fix it" from "report it".** Say plainly which findings the skill fixes
  and which it only reports. Out-of-scope cleanup is the usual thing to report.
- **Calm, direct wording.** No `MUST`/`NEVER` in capitals, no severity emoji. If
  something matters, one sentence of reasoning does more than volume.
- **Done criteria that can be checked:** "lint and tests exit 0", not "looks good".
- **Portable.** A shared skill names no project-specific command. Describe how to find
  the command (Makefile target, package script, language default).
- **Lean.** Keep SKILL.md to the rules that always apply, well under 100 lines. Long
  material (pattern catalogs, code examples) goes in `references/*.md` next to it,
  listed with a line on when to read each (`go-dev` shows the layout).

## Updating a skill

1. Read the whole file first.
2. Check the result against sibling skills so two skills never give conflicting
   instructions. `verify` owns lint, type check, and tests; other skills point to it.
3. If the skill has a `trigger-eval.json`, check that its queries still match the
   description.
4. Shared skills are installed from the dotfiles repo: edit
   `.agents/skills/<name>/` there (`.agents/skills-optional/` for machine-specific
   ones) and run `make update` (`.\setup.ps1 -Action update` on Windows). An edit made
   directly under `~/.agents/skills` is kept by the sync but never reaches the repo.

**Done when** the frontmatter has `name` and a description saying what the skill does
and when to use it, the body states its goal, steps or rules, and a checkable done
condition, and nothing in it contradicts a sibling skill.
