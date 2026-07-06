# Go Concurrency Patterns

References: [Pipelines and cancellation](https://go.dev/blog/pipelines),
[Context](https://go.dev/blog/context)

## Principles

- Use context for cancellation and timeout propagation; `select` with `ctx.Done()`.
- Close channels to broadcast "done"; manage goroutine lifecycles to avoid leaks.

## Common shapes

- **Pipeline**: stages connected by channels, each stage a goroutine group.
- **Fan-out**: multiple goroutines reading the same channel.
- **Fan-in**: multiplex multiple inputs onto one channel.

## WaitGroup (Go 1.25+)

```go
var wg sync.WaitGroup
wg.Go(func() { doWork() }) // auto Add(1) + defer Done(); returns false after Wait()
wg.Wait()
```

## Typed atomics (Go 1.19+)

Use `atomic.Int64`, `atomic.Uint32`, `atomic.Pointer[T]`, `atomic.Bool` instead of the
old function-style APIs.

## Weak pointers (Go 1.25+)

Use the `weak` package for caches/canonicalization maps where entries must not block GC:

```go
import "weak"

type Cache struct {
    m map[string]weak.Pointer[Value]
}
```

## Loop variables (Go 1.22+)

Loop variables are per-iteration — no capture bugs. Use `for i := range 10` for simple
counted loops. Iterators (Go 1.23+): `slices.All/Values`, `maps.Keys/Values/All`,
custom `iter.Seq[T]` / `iter.Seq2[K,V]`.
