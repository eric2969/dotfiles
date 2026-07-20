---
name: go-dev
description: >-
  Go development standards for all Go work. Trigger whenever creating or editing
  .go files, go.mod, or discussing Go code design, error handling, testing,
  concurrency, or performance. Keywords: "golang", "Go", "goroutine", "go.mod",
  "寫一個 Go", "Go 專案". Load BEFORE writing any Go code.
---

# Go Development

> ⚠️ This skill is version-controlled in the dotfiles repo at `.claude/skills/go-dev/SKILL.md`.
> Update it there and sync with `make update` (macOS/Linux) or `./setup.ps1 update` (Windows).
> Sync auto-updates unmodified copies; locally modified copies are kept unless `FORCE=1` / `-Force`.

**Purpose:** Apply consistent Go standards (style, errors, testing, modern features)
to every Go change. Target version: Go 1.25+ (minimum 1.25.5).

## Core rules (always apply)

1. 🔴 Code comments in English only. Marker format: `// TODO:` (future work),
   `// FIXME:` (known bug), `// XXX:` (serious hack warning) — always with a clear,
   actionable description.
2. 🔴 Naming: MixedCaps/mixedCaps (never snake_case); acronyms all caps (`HTTP`, `ID`);
   packages short lowercase single words; constants MixedCaps (not ALL_CAPS);
   single-method interfaces end in `-er`.
3. 🔴 Errors: always check them; wrap with `%w` for `errors.Is`/`errors.As`; messages
   lowercase, no trailing punctuation, with context; define sentinel errors as
   package-level vars; panic ONLY for unrecoverable programming/init failures.
4. 🔴 Context: always the first parameter; never stored in a struct; propagate through
   the whole call chain.
5. 🔴 Functions: early returns; `defer` for cleanup; accept interfaces, return structs;
   keep under ~50 lines and 3–4 parameters (use a struct beyond that); errors last in
   return values.
6. 🔴 `nolint` directives only for documented false positives, justified intentional
   violations, or explained test exceptions — always naming the specific linter, never
   blanket suppression.
7. 🔴 Prefer native Go over shelling out: no scattered `exec.Command`; if a CLI call is
   unavoidable, wrap it in a dedicated `internal/cli`/`pkg/cli` package with interfaces
   and tests (e.g. use `go-git`, `net/http`, `encoding/json`, `archive/tar` instead of
   `git`, `curl`, `jq`, `tar`).
8. 🔴 Use modern stdlib: `slices`/`maps`/`cmp`, `min`/`max`/`clear`, `log/slog`
   (never `log.Printf` in new code), `net/http.ServeMux` method+wildcard routing,
   `math/rand/v2`, `sync.WaitGroup.Go`, `any` (not `interface{}`), `//go:build` tags.
9. 🟡 Import groups: stdlib / external / internal, blank-line separated.
10. 🟡 Receivers: short (1–2 chars) and consistent across the type; if any method needs
    a pointer receiver, use pointers on all.

## Verification

Run per the `verify` skill; Go defaults are `golangci-lint run` and
`go test -race ./...` (with a `Makefile`, `make lint` / `make test`).

## References (read the one relevant to the task)

- `references/errors.md` — error handling patterns (retry, timeout, custom types)
- `references/testing.md` — table-driven tests, mocking, coverage philosophy, race detection
- `references/performance-security.md` — memory, profiling, PGO, input validation, os.Root
- `references/concurrency.md` — pipelines, fan-in/out, cancellation, WaitGroup/weak (1.25+)

**Pass criteria:** Changed Go code satisfies every 🔴 rule above, and `verify` passes
(`golangci-lint run` and `go test -race ./...` exit 0).
