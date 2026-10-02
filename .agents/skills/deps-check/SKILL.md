---
name: deps-check
description: >-
  Audit dependencies for known vulnerabilities and risky upgrades. Use when a dependency
  manifest changes (package.json, lockfiles, go.mod, requirements.txt, pyproject.toml)
  and when asked about CVEs, security advisories, outdated packages, or upgrading a
  dependency.
---

# Dependency Check

## Steps

1. **Run the ecosystem's audit:** `npm audit` / `pnpm audit` / `yarn audit`,
   `govulncheck ./...`, or `pip-audit`.
2. **High or critical findings in a direct dependency:** apply the recommended upgrade
   or replacement and re-run until none remain. If one cannot be fixed, report why.
3. **Moderate or low findings, and vulnerable transitive dependencies:** report them
   with the available remediation. Do not force a major-version bump for these.
4. **Major-version upgrades:** read the changelog or release notes and summarize the
   breaking changes that affect this codebase.
5. **After any dependency change:** run the project's install command, then the
   `verify` skill's full run, to confirm the lockfile is consistent and nothing broke.

**Done when** the audit reports no high or critical vulnerability in a direct
dependency (or each remaining one has a stated reason), and install and `verify` pass.
