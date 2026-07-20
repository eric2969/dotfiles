---
name: ts-dev
description: >-
  TypeScript/JavaScript development standards. Trigger whenever creating or editing
  .ts/.tsx/.js/.jsx files, package.json, tsconfig.json, or discussing TypeScript
  code design, typing, or testing. Keywords: "TypeScript", "TS", "tsx", "Node",
  "寫一個 TS", "型別". Load BEFORE writing any TypeScript code.
---

# TypeScript Development

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/ts-dev/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Apply consistent TypeScript standards (strict typing, module hygiene,
testing) to every TS/JS change.

## Core rules

1. 🔴 Code comments in English only. Markers: `// TODO:` / `// FIXME:` / `// XXX:`
   with clear, actionable descriptions.
2. 🔴 Strict typing: respect the project's `tsconfig` strictness (assume `strict: true`
   for new projects). Never introduce `any` to silence errors — use `unknown` +
   narrowing, generics, or proper types. No `@ts-ignore`; `@ts-expect-error` only with
   a justifying comment.
3. 🔴 Prefer `type` inference where obvious; annotate exported/public API signatures
   explicitly. Model states with discriminated unions instead of optional-field soups.
4. 🔴 Handle errors and promises explicitly: no floating promises (`await` or `void`
   with intent), narrow caught errors (`catch (err: unknown)`), fail fast with early
   returns.
5. 🔴 Follow the project's existing module system and style; for new code use ESM,
   named exports over default exports, and `const` by default.
6. 🔴 No `eslint-disable`-style suppressions without a justifying comment naming the
   specific rule.
7. 🟡 Immutability first: `readonly` on public fields/arrays where mutation is not
   required; avoid mutating function parameters.
8. 🟡 Keep functions small and focused; extract when a function does multiple things.
   Prefer standard library (`Array`/`Object`/`Map`/`Set`, `structuredClone`,
   `Intl`) over utility dependencies like lodash for simple operations.
9. 🟡 New tests follow the project's test runner (vitest/jest/node:test); use
   table-style `it.each`/loops for same-logic cases; do not test framework internals.

## Verification

Run per the `verify` skill; TS defaults are the project's lint script, `tsc --noEmit`,
and the project's test script.

**Pass criteria:** Changed TS code satisfies every 🔴 rule above, and `verify` passes
(lint, `tsc --noEmit`, and tests exit 0).
