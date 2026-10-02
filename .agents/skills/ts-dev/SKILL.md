---
name: ts-dev
description: >-
  TypeScript/JavaScript coding standards. Load before writing or editing .ts/.tsx/.js/.jsx
  files, package.json, or tsconfig.json, and when discussing TypeScript design, typing,
  or testing.
---

# TypeScript Development

Follow the project's existing module system, lint config, and style first. The rules
below apply on top, and decide the matter for new code.

## Rules

1. **Strict typing.** Respect the project's `tsconfig` (assume `strict: true` in a new
   project). Never add `any` to silence an error: use `unknown` with narrowing,
   generics, or a real type. No `@ts-ignore`; `@ts-expect-error` only with a comment
   giving the reason.
2. **Types at the boundary.** Annotate exported signatures explicitly and let inference
   handle the rest. Model states as discriminated unions rather than bags of optional
   fields.
3. **Errors and promises.** No floating promises (`await` it, or `void` it on purpose).
   Catch as `unknown` and narrow. Fail fast with early returns.
4. **New code:** ESM, named exports over default exports, `const` by default,
   `readonly` on public fields and arrays that need no mutation, no mutating of
   function parameters.
5. **Dependencies.** Prefer the platform (`Array`/`Map`/`Set`, `structuredClone`,
   `Intl`) over utility packages like lodash for simple operations.
6. **Tests** use the project's runner (vitest/jest/node:test), with `it.each` for cases
   that share logic. Do not test framework internals.
7. **`eslint-disable`** only with a comment naming the rule and the reason.
8. Code comments in English, including `TODO:` / `FIXME:` / `XXX:` markers.

**Done when** the changed code follows these rules and the `verify` skill passes (the
project's lint script, `tsc --noEmit`, and tests).
