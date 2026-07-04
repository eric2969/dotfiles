---
name: test
description: >-
  Run the project's unit tests after business logic, library code, or shared helpers
  are added or modified. Trigger whenever the user says they changed a function in a
  lib/util/service module, fixed a bug, or asks whether tests still pass or whether
  new tests are needed. Keywords: "run tests", "tests still passing?", "跑一下測試",
  "need to check test coverage", "do I need to add tests", "幫我跑測試".
---

# Test

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/test/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Verify changed logic with unit tests immediately, and ensure new exported
behavior is covered by meaningful tests.

**Actions:**

1. Detect the project's test command in this order: `Makefile` target (`make test`) →
   `package.json` script (`npm test`) → language default (`go test -race ./...`,
   `<test-command>`).
2. 🔴 Run the tests scoped to the changed package/module first, then the full suite.
   If any test fails, fix the code (or the test, if the behavior change is intentional
   and the user confirmed it) and re-run until green.
3. 🔴 If the change added or modified exported behavior that has no test, write a
   focused unit test for it (happy path + the edge case the change addresses). Do not
   write tests solely to raise coverage numbers.
4. 🟡 If unrelated tests were already failing before the change, report them separately
   and do not silently fix or skip them.

**Pass criteria:** The test command exits 0, and every exported behavior introduced or
changed in this session has at least one meaningful test.
