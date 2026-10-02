---
name: refactor
description: >-
  Behavior-preserving refactoring workflow: tests first, one code smell at a time. Use
  when asked to refactor, restructure, clean up, or simplify existing code, or to fix
  duplication, long functions, or deep nesting.
---

# Refactor

A refactor changes structure and nothing else. Tests are what prove that, so they come
first, and the scope stays narrow enough to review.

## Steps

1. **Baseline tests.** Before touching the code, make sure tests cover the target's
   current behavior and edge cases. Where they are missing, write them and see them
   pass. Do not refactor code that has no tests.
2. **Small steps.** One transformation at a time (extract function, introduce parameter
   object, replace magic number, …), running the tests after each. Never continue on a
   red test.
3. **Behavior stays the same.** If a behavior change turns out to be needed, stop and
   raise it as a separate task.
4. **One smell per session.** Report other problems you notice instead of fixing them
   on the way through. Stop when the smell is resolved; do not gold-plate.
5. **Finish** with the `verify` skill's full run, and use a `refactor:` commit type.

Smells worth acting on: duplicated code, a function over about 50 lines or doing
several things, more than 4 parameters, nesting deeper than 3 levels, an oversized
type, logic living far from the data it uses.

**Done when** baseline tests existed before the change, they passed after every step,
the diff addresses one smell, and `verify` passes on the final state.
