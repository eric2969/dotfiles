---
name: deps-check
description: >-
  Audit dependencies for vulnerabilities and freshness whenever dependency manifests
  change or the user asks about package security. Trigger on edits to package.json,
  package-lock.json, go.mod, requirements.txt, pyproject.toml, or when the user
  mentions CVEs, security advisories, npm audit, outdated packages, or upgrading a
  dependency. Keywords: "any security issues?", "check for CVEs", "npm audit",
  "有沒有漏洞", "套件多久沒更新", "should we update our deps".
---

# Dependency Check

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/deps-check/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Keep dependency changes safe by auditing for known vulnerabilities and
flagging risky upgrades.

**Actions:**

1. Detect the ecosystem's audit command: `npm audit` / `pnpm audit` / `yarn audit`
   for Node, `govulncheck ./...` for Go, `pip-audit` for Python, or `<audit-command>`.
2. 🔴 Run the audit. For each high/critical finding that affects a direct dependency,
   apply the recommended fix (upgrade or replacement) and re-run until no high/critical
   findings remain in direct dependencies, or report why a fix is not possible.
3. 🟡 Report moderate/low findings and vulnerable transitive dependencies with the
   available remediation, but do not force major-version bumps for them.
4. 🟡 When the user upgrades across a major version, check the package's changelog or
   release notes for breaking changes and summarize the ones that affect this codebase.
5. 🔴 After any dependency change, run the project's install and test commands
   (`<install-command>`, `<test-command>`) to confirm the lockfile is consistent and
   nothing breaks.

**Pass criteria:** The audit command reports no high/critical vulnerabilities in direct
dependencies (or each remaining one has a documented reason), and install + tests exit 0
after the change.
