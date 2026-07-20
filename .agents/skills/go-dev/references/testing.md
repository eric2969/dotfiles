# Go Testing Standards

## Organization

- **Unit tests**: single function in isolation, no external deps, fast, `*_test.go`.
- **Integration tests**: `//go:build integration` tag, run via `go test -tags=integration ./...`.
- Naming: `TestFunctionName_InputDescription_ExpectedOutcome`
  (e.g. `TestParseConfig_InvalidJSON_ReturnsError`).
- Independence: every test runs alone and in any order; no shared state; clean up with
  `t.Cleanup()`.

## Table-driven vs separate t.Run()

| Approach | When |
|----------|------|
| Table-driven | same validation logic, different input/output data |
| Separate `t.Run()` | different validation logic per case; forcing a table would need many boolean flags |

```go
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {"valid", "user@example.com", false},
        {"invalid", "not-an-email", true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if (err != nil) != tt.wantErr {
                t.Errorf("got error %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

## Mocking

Hand-written mocks first; mocking tools only for large interfaces (10+ methods).
Prefer the **function fields pattern** — one mock struct, behavior set per test:

```go
type mockUserRepository struct {
    getByIDFunc func(ctx context.Context, id string) (*User, error)
    saveFunc    func(ctx context.Context, u *User) error
}

func (m *mockUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
    if m.getByIDFunc != nil {
        return m.getByIDFunc(ctx, id)
    }
    return nil, errors.New("getByIDFunc not set")
}
```

## Error assertions and edge cases

```go
if !errors.Is(err, ErrExpected) {
    t.Errorf("got %v, want %v", err, ErrExpected)
}

var customErr *MyError
if !errors.As(err, &customErr) {
    t.Errorf("expected MyError, got %T", err)
}
```

Edge cases to cover: nil/empty inputs, boundary values (`0`, `-1`, `MaxInt`),
out-of-range indices, duplicates, single item, very large inputs.

## Helpers

Extract a helper when setup repeats in 3+ tests; mark with `t.Helper()`; use
`t.Fatalf` for setup failures.

## Race detection and goroutine leaks

- `go test -race ./...` MUST pass — always run with `-race`.
- For goroutine-spawning code, compare `runtime.NumGoroutine()` before/after
  (with a short sleep for cleanup) to catch leaks.

## Coverage philosophy — what NOT to test

- Never write tests solely to raise coverage; coverage is an indicator, not a goal.
- Do not test: stdlib behavior, third-party internals, compiler guarantees,
  external services in unit tests (mock them), unexported details unless critical.
