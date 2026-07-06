# Claude Behavior Rules

## Skills System

Skills are reusable workflow guides stored in `~/.claude/skills/`. Each skill defines a
precise trigger, purpose, and ordered action steps for a specific concern.

**MANDATORY: Check for applicable skills before taking any action.**

### How to invoke a skill

Use the `Skill` tool with the skill name:

```
Skill("skill-authoring")   # invoke by name
```

### When to invoke skills

| Situation | Action |
|-----------|--------|
| Writing or editing code in a language below | Invoke the matching `*-dev` skill FIRST |
| Code change completed, or a commit/push is about to happen | Invoke `verify` |
| Any other task that matches a skill's trigger | Invoke that skill first |
| No skill matches | Proceed without one |

### Skills directory

`~/.claude/skills/` — each subdirectory contains a `SKILL.md` file (long material lives
in the skill's `references/` and is loaded only when needed).

| Skill | When |
|-------|------|
| `go-dev` | any Go work (`.go`, `go.mod`) — standards, errors, testing, concurrency |
| `ts-dev` | any TypeScript/JavaScript work (`.ts/.tsx/.js`, tsconfig) |
| `python-dev` | any Python work (`.py`, pyproject) |
| `verify` | after code edits and before EVERY commit — lint + type check + tests |
| `refactor` | restructuring existing code — test-first, one code smell at a time |
| `docs-sync` | after user-facing changes — keep README/docs truthful |
| `style-check` | new/changed components, pages, API routes vs project conventions |
| `deps-check` | dependency manifest changes, CVEs, audits, upgrades |
| `skill-authoring` | creating, updating, or reviewing any SKILL.md |

(The table is a quick index — each skill's `description` frontmatter is the source of truth.)

### Rules

1. **Skills override defaults** — follow the skill's Actions exactly.
2. **User instructions override skills** — if CLAUDE.md or the user contradicts a skill,
   follow the user.
3. **Never skip skills** — if even a 1% chance a skill applies, invoke it first.

---

## Universal Coding Rules (all languages)

1. Code comments in English only (e.g. `// Initialize database connection`, never
   `// 初始化資料庫連線`). Markers: `TODO:` future work, `FIXME:` known bug,
   `XXX:` serious hack warning — always with an actionable description.
2. Explicit is better than implicit — clarity over cleverness; no hidden magic.
3. Never suppress linters (`nolint`, `eslint-disable`, `# type: ignore`, …) without a
   comment naming the specific rule and the reason.
4. Small, focused functions; early returns over deep nesting; meaningful names.
5. Handle every error explicitly; never swallow failures silently.
6. All language-specific standards live in the `*-dev` skills — load the matching one
   before writing code instead of guessing conventions.
