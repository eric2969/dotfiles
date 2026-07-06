# Go Error Handling Patterns

References: [Effective Go — Errors](https://go.dev/doc/effective_go#errors),
[Uber Go Style Guide — Error Handling](https://github.com/uber-go/guide/blob/master/style.md#error-handling)

## Sentinel errors and custom types

```go
var (
    ErrNotFound     = errors.New("resource not found")
    ErrUnauthorized = errors.New("unauthorized access")
)
```

For errors needing extra context, implement `Error()` and `Unwrap()`.

## Checking wrapped errors

```go
if errors.Is(err, ErrNotFound) {
    return nil, fmt.Errorf("user not found: %w", err)
}

var validationErr *ValidationError
if errors.As(err, &validationErr) {
    slog.Error("validation failed", "field", validationErr.Field)
    return nil, err
}
```

## Early return

```go
func ProcessRequest(req *Request) error {
    if req == nil {
        return errors.New("request is nil")
    }
    if err := validateRequest(req); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }
    return nil
}
```

## Retry with context

```go
func DoWithRetry(ctx context.Context, maxRetries int, fn func() error) error {
    var lastErr error
    for attempt := 0; attempt < maxRetries; attempt++ {
        if ctx.Err() != nil {
            return ctx.Err()
        }
        if err := fn(); err == nil {
            return nil
        } else {
            lastErr = err
        }
        if attempt < maxRetries-1 {
            backoff := time.Duration(100*(1<<uint(attempt))) * time.Millisecond
            select {
            case <-time.After(backoff):
            case <-ctx.Done():
                return ctx.Err()
            }
        }
    }
    return fmt.Errorf("failed after %d attempts: %w", maxRetries, lastErr)
}
```

## Timeout with context

```go
func FetchWithTimeout(userID string) (*User, error) {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    return FetchUser(ctx, userID)
}
```

## Context guidelines

- `context.Background()` as the top-level context in main/init.
- `context.TODO()` only when the context is unclear during refactoring.
- Always first parameter; never stored in structs; propagate through the chain.
