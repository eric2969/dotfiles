---
name: refactor
description: >-
  Test-driven refactoring workflow for restructuring existing code without changing
  behavior. Trigger whenever the user asks to refactor, restructure, clean up, or
  simplify existing code, or mentions code smells like duplication, long functions,
  or deep nesting. Keywords: "refactor", "重構", "整理這段程式碼", "clean up this code",
  "拆成小函式", "too complex", "simplify this module".
---

# Refactor

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/refactor/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Keep refactoring safe and scoped — behavior-preserving changes backed by
tests, one code smell at a time.

## When to refactor (code smells)

Duplicated code · function > ~50 lines or doing multiple things · more than 3–4
parameters · oversized class/struct · nesting deeper than 3 levels · feature envy
(logic living far from the data it uses).

## Actions

1. 🔴 **Tests first** — before touching the code, ensure the target has tests covering
   its current behavior and edge cases. If missing, write them and confirm they pass
   as the baseline. Refactoring without tests is prohibited.
2. 🔴 **Small steps** — one improvement at a time (extract function, extract interface,
   introduce parameter object, replace magic number with constant…). Run the tests
   after each step; never proceed on red.
3. 🔴 **Behavior preservation** — refactoring must not change observable behavior. If a
   behavior change is needed, stop and surface it as a separate task.
4. 🔴 **Scope control** — one code smell per session/PR. Report other problems found
   along the way instead of fixing them inline ("while I'm here" is scope creep).
5. 🟡 **Design direction** — favor single responsibility, small focused interfaces, and
   depending on abstractions; stop when the smell is resolved (YAGNI — don't gold-plate).
6. 🔴 **Final verification** — run the `verify` skill (lint + type check + full tests)
   before declaring the refactor done; commit with a `refactor:` type message.

**Pass criteria:** Baseline tests existed (or were written) before the change, all
tests pass after every step, the diff addresses exactly one code smell, and `verify`
exits 0 on the final state.
