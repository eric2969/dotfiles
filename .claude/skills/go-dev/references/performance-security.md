# Go Performance & Security

## Memory

- `sync.Pool` for frequently allocated objects (reduces GC pressure).
- `strings.Builder` instead of string concatenation in loops.
- Pre-allocate slices when size is known: `make([]T, 0, capacity)`.
- `clear()` to reuse maps/slices instead of reallocating.

## Profiling & benchmarking

```bash
go test -cpuprofile=cpu.prof -bench=. && go tool pprof cpu.prof
go test -memprofile=mem.prof -bench=. && go tool pprof mem.prof
go test -bench=. -benchmem ./...
```

## Profile-Guided Optimization (production builds)

Collect a CPU profile from a representative workload (30–60s steady state), save as
`default.pgo` in the main package (commit it), and `go build` picks it up
automatically (or `go build -pgo=/path/profile.pgo`). Refresh profiles periodically.

## Security

- Validate all external inputs at boundaries (HTTP/gRPC/CLI); allowlists over denylists;
  sanitize user input before logging.
- SQL injection: parameterized queries only. Command injection: avoid `os/exec` with
  user input.
- Path traversal: use `os.Root` (Go 1.24+) for sandboxed filesystem access:

```go
root, err := os.OpenRoot("/data/uploads")
if err != nil {
    return err
}
defer root.Close()
file, err := root.Open(userFilename) // confined to /data/uploads
```

- Never log passwords, tokens, or API keys; mask with `slog.LogValuer`.
