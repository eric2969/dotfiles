---
name: go-dev
description: >-
  Go coding standards. Load before writing or editing Go code (.go files, go.mod) and
  when discussing Go design, error handling, testing, concurrency, or performance.
---

# Go Development

Write idiomatic Go as `gofmt`, `golangci-lint`, and Effective Go define it. The rules
below are the choices that go beyond those defaults. Target Go 1.25+.

## Rules

1. **Modern stdlib.** `slices`/`maps`/`cmp`, `min`/`max`/`clear`, `log/slog` (not
   `log.Printf` in new code), `net/http.ServeMux` method and wildcard routing,
   `math/rand/v2`, `sync.WaitGroup.Go`, `any`, `//go:build`.
2. **Errors.** Check every one. Wrap with `%w` and add context; messages are lowercase
   with no trailing punctuation. Sentinel errors are package-level vars. Panic only for
   unrecoverable programming or init failures.
3. **Context.** First parameter, passed down the whole call chain, never stored in a
   struct.
4. **Functions.** Accept interfaces, return structs. Past about 50 lines or 4
   parameters, split the function or introduce a parameter struct.
5. **Native Go over shelling out.** Use `go-git`, `net/http`, `encoding/json`,
   `archive/tar` rather than `git`, `curl`, `jq`, `tar`. When a CLI call is unavoidable,
   put it behind an interface in one dedicated package (`internal/cli`) with tests, not
   scattered `exec.Command` calls.
6. **`nolint`** only for a documented false positive or a justified intentional
   violation, always naming the specific linter.
7. Code comments in English, including `TODO:` / `FIXME:` / `XXX:` markers.

## References

Read the one that matches the task:

- `references/errors.md` — retry, timeout, custom error types
- `references/testing.md` — table-driven tests, mocking, coverage philosophy, race detection
- `references/concurrency.md` — pipelines, fan-in/out, cancellation, WaitGroup/weak
- `references/performance-security.md` — memory, profiling, PGO, input validation, os.Root

**Done when** the changed code follows these rules and the `verify` skill passes
(`golangci-lint run`, `go test -race ./...`).
