# Claude Behavior Rules

## Skills System

Skills are reusable workflow guides stored in `~/.claude/skills/`. Each skill defines a precise
trigger, purpose, and ordered action steps for a specific concern.

**MANDATORY: Check for applicable skills before taking any action.**

### How to invoke a skill

Use the `Skill` tool with the skill name:

```
Skill("skill-authoring")   # invoke by name
```

### When to invoke skills

| Situation | Action |
|-----------|--------|
| User asks to create / update / review a skill file | Invoke `skill-authoring` |
| Any other task that matches a skill's trigger | Invoke that skill first |
| No skill matches | Proceed without one |

### Skills directory

`~/.claude/skills/` — each subdirectory contains a `SKILL.md` file.

Current skills:

| Skill | Trigger keywords |
|-------|-----------------|
| `skill-authoring` | "寫一個 skill", "新增 skill", "更新 skill", "create skill", "update skill", "write skill", "review skill", "check skill" |
| `lint` | "run lint", "check types", "跑 lint", "確認沒有 TypeScript 錯誤", "make sure eslint is happy" |
| `test` | "run tests", "tests still passing?", "跑一下測試", "do I need to add tests" |
| `style-check` | "follows the conventions?", "check my new component", "有沒有違反規範", "verify auth" |
| `deps-check` | "any security issues?", "check for CVEs", "npm audit", "有沒有漏洞", "should we update our deps" |

(The table is a quick index — each skill's `description` frontmatter is the source of truth.)

### Rules

1. **Skills override defaults** — follow the skill's Actions exactly.
2. **User instructions override skills** — if CLAUDE.md or the user contradicts a skill, follow the user.
3. **Never skip skills** — if even a 1% chance a skill applies, invoke it first.

---

# Go Development Standards

## Go Coding Standards

**Target Version:** Go 1.25+ (minimum Go 1.25.5)

Follow official Go style guidelines and community best practices.

**References:**
- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)

### 1. Code Comments
- **MANDATORY**: All code comments MUST be written in English only
- **PROHIBITED**: Chinese or any other non-English language in code comments
- Example:
  - Good: `// Initialize database connection`
  - Bad: `// 初始化資料庫連線`

### 2. Special Comment Markers

**TODO**
- **PURPOSE**: Mark incomplete features or planned improvements
- **URGENCY**: Low - for future work
- **FORMAT**: `// TODO: <clear description>`

**FIXME**
- **PURPOSE**: Mark known bugs or incorrect implementations
- **URGENCY**: Medium to High
- **FORMAT**: `// FIXME: <clear description>`

**XXX**
- **PURPOSE**: Strong warning for serious issues, hacky code, or workarounds
- **URGENCY**: Medium to High
- **FORMAT**: `// XXX: <clear warning and explanation>`

**Best Practices:**
- Always provide clear, actionable descriptions
- Prefer fixing issues immediately over adding markers when possible

### 3. Core Philosophy
- **Explicit is better than implicit** - Prefer clarity over cleverness
- Write code that clearly expresses intent
- Avoid hidden behaviors, magic, or implicit conversions

### 4. Naming Conventions

**General Rules:**
- Use **MixedCaps** or **mixedCaps**, not snake_case
- Acronyms should be all caps: `HTTP`, `URL`, `ID`, `API`
- Be concise but clear

**Packages:** Short, lowercase, single-word names (e.g., `user`, `http`, `auth`)

**Functions:** MixedCaps for exported, mixedCaps for unexported

**Variables:** Short names in small scopes (`i`, `n`, `err`), descriptive in larger scopes

**Constants:** MixedCaps, not ALL_CAPS (e.g., `MaxRetries`)

**Interfaces:** Single-method interfaces end in `-er` (e.g., `Reader`, `Writer`)

### 5. Code Organization

**File Structure:**
- One main concept per file
- Order: types → constructors → methods → helpers

**Import Groups:** Separate into three groups with blank lines:
```go
import (
    // Standard library
    "context"
    "fmt"

    // External dependencies
    "github.com/gin-gonic/gin"

    // Internal packages
    "yourproject/pkg/auth"
)
```

### 6. Function Guidelines

- Keep functions under 50 lines when possible
- Limit to 3-4 parameters; use structs for more
- Return errors as the last return value
- Context should always be the first parameter

### 7. Methods and Receivers

**Receiver Naming:**
- Use consistent, short receiver names (1-2 characters)
- Same receiver name across all methods of a type

**Pointer vs Value:**
- Use pointer receivers when method needs to modify receiver or struct is large
- Use value receivers for small, immutable types
- Be consistent: if any method uses pointer, all should

**Context:**
- Context should always be first parameter
- Never store Context in a struct
- Pass Context explicitly through the call chain

### 8. Common Go Idioms

**Early Return:**
```go
func ProcessData(data []byte) error {
    if len(data) == 0 {
        return errors.New("empty data")
    }
    // main logic
    return nil
}
```

**Defer for Cleanup:**
```go
func ReadFile(path string) ([]byte, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer f.Close()
    return io.ReadAll(f)
}
```

**Accept Interfaces, Return Structs:**
```go
func ProcessData(r io.Reader) (*Result, error) {
    // ...
}
```

### 9. Concurrency Patterns

**References:**
- [Go Concurrency Patterns: Pipelines and cancellation](https://go.dev/blog/pipelines)
- [Go Concurrency Patterns: Context](https://go.dev/blog/context)

**Pipeline Pattern:**
- Series of stages connected by channels
- Each stage is a group of goroutines running the same function
- Efficient use of I/O and multiple CPUs

**Key Principles:**
- Use context for cancellation and timeout propagation
- Close channels to broadcast "done" signals
- Handle goroutine lifecycle properly to avoid leaks
- Use `select` with `context.Done()` for cancellation

**Common Patterns:**
- **Fan-out**: Multiple goroutines reading from the same channel
- **Fan-in**: Multiple inputs multiplexed to single channel
- **Pipeline**: Chain of stages processing data sequentially

**WaitGroup Simplification (Go 1.25+):**
```go
var wg sync.WaitGroup
wg.Go(func() { doWork() })  // Automatically calls Add(1) and defer Done()
wg.Wait()
```

### 10. Modern Go Features (Go 1.17 - 1.25+)

#### Foundation (Go 1.17)
- **Build tags**: Use `//go:build` syntax (not `// +build`)
- **Slice to array pointer**: `arr := (*[4]byte)(slice)`

#### Generics (Go 1.18+)
- Use type parameters for generic functions and types
- Prefer standard library generic packages when available
- Use `any` instead of `interface{}` for unconstrained type parameters
- Use `comparable` constraint for types that support `==` and `!=`

#### Fuzzing (Go 1.18+)
- Use `go test -fuzz=FuzzName` for native fuzzing support
- Write fuzz tests with `func FuzzXxx(f *testing.F)` signature
- Add seed corpus with `f.Add()` and use `f.Fuzz()` for testing

#### Atomic Operations (Go 1.19+)
- Use new typed atomic values: `atomic.Int64`, `atomic.Uint32`, `atomic.Pointer[T]`, `atomic.Bool`
- Easier and safer than old `atomic.LoadInt64()` / `atomic.StoreInt64()` functions
- Memory model aligned with C/C++/Java/Rust standards

#### Conversions & Safety (Go 1.20+)
- **Slice to array**: `arr := [4]byte(slice)` (not just pointer)
- **unsafe helpers**: `unsafe.Slice()`, `unsafe.SliceData()`, `unsafe.String()`, `unsafe.StringData()`
- Use for low-level optimizations only, prefer safe alternatives first

**Use Standard Library Generics (Go 1.21+):**
- Prefer `slices` package over custom slice utilities
- Prefer `maps` package over custom map utilities
- Use `cmp.Compare()` and `cmp.Or()` for comparisons

**Examples:**
```go
// Sorting with slices package
slices.Sort(numbers)
slices.SortFunc(users, func(a, b User) int {
    return cmp.Compare(a.Name, b.Name)
})

// Checking containment
if slices.Contains(items, target) { /* ... */ }

// Map operations
clone := maps.Clone(original)
maps.DeleteFunc(data, func(k string, v int) bool {
    return v < 0
})
```

**Built-in Functions (Go 1.21+):**
```go
// Use min/max for simple comparisons
result := max(a, b, c)
smallest := min(x, y)

// Use clear() for zeroing
clear(myMap)     // Remove all entries
clear(mySlice)   // Zero all elements
```

**Structured Logging (Go 1.21+):**
- Use `log/slog` for all new logging code
- Avoid `log.Printf()` and third-party logging libraries unless necessary

```go
slog.Info("user logged in", "user_id", userID, "ip", remoteIP)
slog.Error("database connection failed", "error", err, "retry", attempt)
```

**HTTP Routing (Go 1.22+):**
- Use enhanced `net/http.ServeMux` patterns with methods and wildcards
- Avoid third-party routers unless advanced features required

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /users/{id}", getUserHandler)
mux.HandleFunc("POST /users", createUserHandler)
mux.HandleFunc("DELETE /users/{id}", deleteUserHandler)
```

**For Loop Best Practices (Go 1.22+):**
- Loop variables are now per-iteration (no more capture bugs)
- Use integer range for simple iterations: `for i := range 10`

**Random Numbers (Go 1.22+):**
- Use `math/rand/v2` for new code (ChaCha8 or PCG generators)
- Old `math/rand` only for compatibility

**Iterator Support (Go 1.23+):**
- Use `for range` with iterator functions for custom iteration
- Standard iterators: `slices.All()`, `slices.Values()`, `maps.Keys()`, `maps.Values()`, `maps.All()`
- Create custom iterators using `iter.Seq[T]` and `iter.Seq2[K,V]` types

**Generic Type Aliases (Go 1.24+):**
```go
// Type aliases can now be parameterized
type Stack[T any] = []T
type Result[T any] = struct {
    Value T
    Error error
}
```

**Tool Dependencies (Go 1.24+):**
- Use `tool` directive in `go.mod` instead of tools.go pattern

```go
// go.mod
tool golang.org/x/tools/cmd/stringer
tool github.com/golangci/golangci-lint/cmd/golangci-lint
```

#### WaitGroup & Concurrency (Go 1.25+)
- Use `sync.WaitGroup.Go` to launch goroutines that automatically manage the WaitGroup counter
- Returns `false` if `Wait` has already been called

```go
var wg sync.WaitGroup
if wg.Go(func() { doWork() }) {
    // Goroutine started and counter incremented
}
wg.Wait()
```

#### Weak Pointers (Go 1.25+)
- Use the `weak` package for pointers that don't prevent garbage collection of the referenced object
- Useful for caches and canonicalization maps

```go
import "weak"

type Cache struct {
    m map[string]weak.Pointer[Value]
}
```

### 11. External Command Execution Policy

**Core Principles:**
1. **Prefer native Go solutions** - Use Go standard library or well-maintained packages instead of shelling out to CLI tools
2. **Avoid `exec.Command`** - Only use `os/exec` when no Go-native alternative exists
3. **Wrap CLI calls** - If CLI execution is unavoidable, create a dedicated package to encapsulate all external command calls

**Rationale:**
- Better error handling and type safety
- Improved testability (no external dependencies)
- Cross-platform compatibility
- Reduced security attack surface

**Decision Process:**
1. First, search for Go standard library solution
2. If not available, look for well-maintained Go packages
3. Only as last resort, use `exec.Command` with proper wrapper package

**Wrapper Package Requirements:**
- Create a dedicated `internal/cli` or `pkg/cli` package
- Define clear interfaces for each external tool
- Implement proper error handling and output parsing
- Add comprehensive tests with mocked commands
- Document why native Go solution was not possible

**Example Structure:**
```go
// internal/cli/git.go
package cli

type GitClient interface {
    Status(ctx context.Context) (*StatusResult, error)
    Commit(ctx context.Context, message string) error
}

type gitClient struct {
    execPath string
}

func NewGitClient() GitClient {
    return &gitClient{execPath: "git"}
}
```

**Prohibited Patterns:**
- Inline `exec.Command` calls scattered throughout codebase
- Direct shell command execution without wrapper
- Using CLI tools when Go packages exist (e.g., use `go-git` instead of `exec.Command("git", ...)`)

**Common Alternatives:**
| CLI Tool | Go Alternative |
|----------|----------------|
| `git` | `github.com/go-git/go-git/v5` |
| `docker` | `github.com/docker/docker/client` |
| `kubectl` | `k8s.io/client-go` |
| `curl/wget` | `net/http` |
| `jq` | `encoding/json` |
| `tar/gzip` | `archive/tar`, `compress/gzip` |
| `openssl` | `crypto/*` |

## Go Error Handling Rules

**References:**
- [Effective Go - Errors](https://go.dev/doc/effective_go#errors)
- [Uber Go Style Guide - Error Handling](https://github.com/uber-go/guide/blob/master/style.md#error-handling)

### 1. Core Principles

1. **Always Check Errors**: Never ignore errors with `_` unless you have a very good reason

2. **Error Wrapping**: Use `%w` to maintain error chain for `errors.Is()` and `errors.As()`
   ```go
   return fmt.Errorf("process data failed: %w", err)
   ```

3. **Error Messages**: Use lowercase, no trailing punctuation, provide context

4. **Sentinel Errors**: Define package-level error variables for expected errors
   ```go
   var (
       ErrNotFound     = errors.New("resource not found")
       ErrUnauthorized = errors.New("unauthorized access")
   )
   ```

5. **Custom Error Types**: For errors needing additional context, implement `Error()` and `Unwrap()`

6. **When to Panic**: ONLY for unrecoverable programming errors or initialization failures

### 2. Common Patterns

**Early Return:**
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

**Retry with Context:**
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
        // Exponential backoff with jitter
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

**Timeout with Context:**
```go
func FetchWithTimeout(userID string) (*User, error) {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    return FetchUser(ctx, userID)
}
```

**Check Wrapped Errors:**
```go
// Check for specific sentinel errors
if errors.Is(err, ErrNotFound) {
    return nil, fmt.Errorf("user not found: %w", err)
}

// Extract typed errors for additional context
var validationErr *ValidationError
if errors.As(err, &validationErr) {
    log.Printf("validation failed on field: %s", validationErr.Field)
    return nil, err
}
```

**Context Guidelines:**
- Use `context.Background()` as the top-level context for main/init functions
- Use `context.TODO()` when context is unclear or will be added later (during refactoring)
- Always pass context as first parameter, never store in structs
- Propagate context through the entire call chain for cancellation support

## Go Linter and Code Quality Rules

### nolint Directive Usage

**MANDATORY RULE:** Do NOT use `// nolint` directives arbitrarily or as a shortcut to bypass linter checks.

**Prohibited Patterns:**
- `// nolint` - Generic suppression of all linter warnings
- `// nolint: errcheck` - Suppressing errors without justification
- Bulk suppression of multiple errors at once

**Allowed Usage (ONLY in these cases):**
1. **False Positive Suppression** - When linter produces incorrect warnings despite correct code
   - Document why it's a false positive in a comment above
   - Example: `// nolint: staticcheck // False positive: var is used via reflection`

2. **Intentional Violations with Clear Justification** - When deliberately breaking a rule for valid reasons
   - Include explanation comment immediately above the directive
   - Must document the reason and alternative approaches considered
   - Example: `// nolint: gocyclo // Complex state machine requires multiple branches; refactoring would reduce clarity`

3. **Test Code Exceptions** - Specific test scenarios that intentionally violate rules
   - Use within test functions only
   - Include explanation of what behavior is being tested
   - Example: `// nolint: errcheck // Testing error path, intentionally ignoring cleanup errors`

**Proper Format When nolint is Necessary:**
```go
// This error must be ignored because [clear, specific reason]
// The proper solution would be [alternative approach], but that would [explain constraint]
// nolint: <specific linters> // Brief reason
statement()
```

**Standard Process:**
1. Run `make lint` to identify all issues
2. Fix issues through code changes (first choice)
3. If suppression is truly necessary:
   - Add clear comment explaining why
   - Specify exact linters (not blanket suppression)
   - Get approval through code review
4. Never use as substitute for proper refactoring

**Validation:**
- `make lint` must pass with minimal and justified nolint directives
- Code reviews will reject arbitrary nolint usage
- Suppressed warnings must be documented and traceable

## Go Testing Rules

### 1. Best Practices
- Tests MUST be clear, meaningful, and maintainable
- Use table-driven tests for multiple similar cases
- Each test should focus on a single behavior

### 2. Test Organization

**Unit Tests:**
- Test single function/method in isolation
- No external dependencies
- Fast execution (milliseconds)
- File naming: `*_test.go`

**Integration Tests:**
- Test interaction between components
- May use external dependencies
- Use build tags: `//go:build integration`
- Run separately: `go test -tags=integration ./...`

### 3. Table-Driven Tests

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

**When to Use Table-Driven vs Separate t.Run():**

| Approach | When to Use |
|----------|-------------|
| **Table-Driven** | Same validation logic, different input/output data |
| **Separate t.Run()** | Different validation logic, testing distinct behaviors |

**Table-Driven is ideal when:**
- All test cases share identical setup and assertion patterns
- Only input values and expected outputs differ
- Adding new cases requires just one line in the table

**Separate t.Run() is better when:**
- Each subtest verifies different aspects of behavior
- Validation logic varies significantly between cases
- Forcing table structure would require many boolean flags or conditional checks

**Example - When NOT to use Table-Driven:**
```go
// ❌ Forced table-driven becomes complex and hard to read
tests := []struct {
    name           string
    checkUserID    bool
    checkClaims    bool
    checkAborted   bool
}{...}

// ✅ Separate t.Run() is clearer when each case tests different things
t.Run("sets default user context", func(t *testing.T) {
    // Verify UserIDKey and JWTClaimsKey
})
t.Run("does not abort request", func(t *testing.T) {
    // Only verify c.IsAborted()
})
```

### 4. Mocking Philosophy

**Hand-Written Mocks First:**
- Go's interface design makes manual mocking straightforward
- Use mocking tools only for large interfaces (10+ methods)

**Simple Mock Example:**
```go
type mockUserRepository struct {
    users map[string]*User
    err   error
}

func (m *mockUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
    if m.err != nil {
        return nil, m.err
    }
    return m.users[id], nil
}
```

**Function Fields Pattern (Recommended for Flexible Testing):**
- Use struct fields containing functions to control mock behavior without creating new struct types for each test case
- Provides flexibility to change behavior per test while maintaining single mock implementation
- Reduces code duplication and improves test readability

**Function Fields Example:**
```go
type mockUserRepository struct {
    // Function fields control behavior
    getByIDFunc func(ctx context.Context, id string) (*User, error)
    saveFunc    func(ctx context.Context, u *User) error
}

func (m *mockUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
    if m.getByIDFunc != nil {
        return m.getByIDFunc(ctx, id)
    }
    return nil, errors.New("getByIDFunc not set")
}

func (m *mockUserRepository) Save(ctx context.Context, u *User) error {
    if m.saveFunc != nil {
        return m.saveFunc(ctx, u)
    }
    return errors.New("saveFunc not set")
}

// Usage in test
func TestCreateUser(t *testing.T) {
    mock := &mockUserRepository{
        saveFunc: func(ctx context.Context, u *User) error {
            if u.Name == "" {
                return errors.New("name required")
            }
            return nil
        },
    }

    service := NewUserService(mock)
    err := service.Create(context.Background(), &User{Name: "John"})
    if err != nil {
        t.Errorf("Create failed: %v", err)
    }
}
```

**Function Fields Benefits:**
- No need to define multiple mock struct types
- Behavior can be easily customized per test case
- Makes test intent clearer by showing exact behavior expectations
- Reduces boilerplate code

### 5. Coverage Philosophy
- **DO NOT** write tests solely to increase coverage percentage
- **ONLY** test meaningful scenarios that verify actual behavior
- Focus on business logic, edge cases, and error handling
- Coverage metrics are indicators, not goals

### 6. Test Naming and Independence

**Naming Convention:**
- Descriptive names: `TestFunctionName_InputDescription_ExpectedOutcome`
- Subtests: Use clear, non-ambiguous names in `t.Run()`
- Example: `TestParseConfig_InvalidJSON_ReturnsError`

**Independence Principles:**
- Each test must be executable independently, in any order
- **NO** shared state between tests (use separate setup per test)
- Always clean up resources (files, connections, goroutines)
- Tests should not depend on other tests' results

### 7. Error Checking Patterns and Edge Cases

**Verify Sentinel Errors:**
```go
err := DoSomething()
if !errors.Is(err, ErrExpected) {
    t.Errorf("got %v, want %v", err, ErrExpected)
}
```

**Extract Custom Error Types:**
```go
var customErr *MyError
if !errors.As(err, &customErr) {
    t.Errorf("expected MyError, got %T", err)
}
if customErr.Code != expectedCode {
    t.Errorf("error code: got %d, want %d", customErr.Code, expectedCode)
}
```

**Edge Cases to Test:**
- Nil/empty inputs: `nil`, `""`, `[]`, `map[string]int{}`
- Boundary values: `0`, `-1`, `MaxInt`, `MinInt`
- Out-of-range: negative indices, overflow conditions
- Special cases: duplicate items, single item, very large inputs

### 8. Setup, Teardown, and Test Helpers

**Using t.Cleanup():**
```go
func TestWithResource(t *testing.T) {
    f := openFile(t, "test.txt")
    t.Cleanup(func() { f.Close() })
    // Use f in test
}
```

**Helper Functions:**
```go
func createTestUser(t *testing.T) *User {
    t.Helper()  // Skip helper in error line numbers
    u := &User{Name: "test"}
    if err := saveUser(u); err != nil {
        t.Fatalf("setup failed: %v", err)
    }
    return u
}
```

**When to Extract Helpers:**
- Setup logic repeated in 3+ tests
- Complex data structure creation
- Resource allocation/deallocation
- Keep helpers focused and reusable

### 9. Concurrent Testing and Race Detection

**Mandatory Race Detector:**
```bash
# Always run with race detection
go test -race ./...
go test -race -run TestName
```

**Goroutine Leak Testing:**
```go
func TestGoroutineLeaks(t *testing.T) {
    before := runtime.NumGoroutine()
    DoWorkWithGoroutines()
    time.Sleep(100*time.Millisecond)  // Allow cleanup
    after := runtime.NumGoroutine()
    if after > before {
        t.Errorf("goroutine leak: before %d, after %d", before, after)
    }
}
```

**Key Rules:**
- `-race` flag MUST pass in CI/CD
- Test concurrent access with multiple goroutines
- Verify channel closure and timeout behavior

### 10. What NOT to Test

**DO NOT Test:**
- Standard library behavior (trust Go team)
- Third-party package implementations
- Compiler/runtime guarantees (e.g., slice bounds checking)
- External services in unit tests (use mocks or integration tests)
- Unexported package details unless critical for behavior

**Example of Bad Tests:**
```go
// ❌ Bad: Testing standard library
func TestMakeMakesSlice(t *testing.T) {
    s := make([]int, 5)
    if len(s) != 5 { t.Error("make failed") }  // Pointless
}

// ✅ Good: Testing your code's behavior
func TestProcessSlice(t *testing.T) {
    result := ProcessSlice(make([]int, 5))
    if result != expectedValue { t.Error(...) }
}
```

## Go Performance Best Practices

### 1. Memory Optimization
- Use `sync.Pool` for frequently allocated objects to reduce GC pressure
- Avoid string concatenation in loops; use `strings.Builder` instead
- Pre-allocate slices when size is known: `make([]T, 0, capacity)`
- Use `clear()` instead of creating new maps/slices when reusing

### 2. Profiling
```bash
# CPU profiling
go test -cpuprofile=cpu.prof -bench=.
go tool pprof cpu.prof

# Memory profiling
go test -memprofile=mem.prof -bench=.
go tool pprof mem.prof

# Benchmarking
go test -bench=. -benchmem ./...
```

### 3. Profile-Guided Optimization (PGO)
**MANDATORY for production builds** - Enables 2-7% performance improvement

**Workflow:**
```bash
# Step 1: Build with profiling enabled
go build -o myapp

# Step 2: Run in production/staging and collect profile
./myapp  # Collects CPU profile to default.pgo

# Step 3: Rebuild with PGO (automatic if default.pgo exists)
go build -o myapp

# Or specify custom profile location
go build -pgo=/path/to/profile.pgo -o myapp
```

**Best Practices:**
- Collect profiles from representative production workloads
- Update profiles periodically (monthly or after major changes)
- Commit `default.pgo` to version control for CI/CD builds
- Profile collection duration: at least 30-60 seconds of steady-state load

## Go Security Best Practices

### 1. Input Validation
- Validate all external inputs at system boundaries (HTTP, gRPC, CLI)
- Use allowlists instead of denylists for validation
- Sanitize user input before logging to prevent log injection

### 2. Common Vulnerabilities Prevention
- **SQL Injection**: Always use parameterized queries or ORMs
- **Command Injection**: Avoid `os/exec` with user input; use allowlists if necessary
- **Path Traversal**: Use `os.Root` (Go 1.24+) for sandboxed filesystem operations
- **Sensitive Data**: Never log passwords, tokens, or API keys; use masking with `slog.LogValuer`

### 3. Filesystem Security (Go 1.24+)
```go
// Use os.Root for sandboxed file operations
root, err := os.OpenRoot("/data/uploads")
if err != nil {
    return err
}
defer root.Close()

// All operations are confined within /data/uploads
file, err := root.Open(userFilename)  // Path traversal attacks prevented
```

### 4. Validation Workflow
- **WITH Makefile**: Execute `make lint` and `make test`
- **WITHOUT Makefile**: Execute `golangci-lint run` and `go test -v ./...`
- **REQUIREMENT**: Both must pass before considering work complete

## Code Refactoring Rules

### 1. Core Principles
- **PROHIBITED**: Refactoring without tests
- **MANDATORY**: Write tests before every refactoring
- **PHILOSOPHY**: Small steps, frequent commits, always working code

### 2. When to Refactor (Code Smells)

1. **Duplicated Code** - Same logic in multiple places
2. **Long Function** - Function > 50 lines or does multiple things
3. **Long Parameter List** - More than 3-4 parameters
4. **Large Struct** - Too many fields/methods
5. **Deep Nesting** - More than 3 levels of if/for
6. **Feature Envy** - Function uses more data from another struct

### 3. Test-Driven Refactoring (TDR) Workflow

**Step 1: Write Tests First**
- Write comprehensive tests for code to be refactored
- Tests MUST cover existing functionality and edge cases
- Execute tests to ensure all pass (baseline)

**Step 2: Refactor in Small Steps**
- Make ONE improvement at a time
- Run tests after each step
- Commit after each successful refactoring

**Step 3: Verify and Commit**
- Execute `make lint && make test`
- Ensure all tests still pass
- Commit with `refactor:` type

### 4. Common Refactoring Techniques

| Technique | When to Use |
|-----------|-------------|
| **Extract Function** | Function > 50 lines or does multiple things |
| **Extract Interface** | Need polymorphism or testability |
| **Introduce Parameter Object** | More than 3-4 parameters |
| **Replace Magic Number with Constant** | Hardcoded numbers without context |

### 5. Scope Control

**Golden Rule**: One code smell, one PR

- Focus on ONE specific issue per session
- Avoid "While I'm here, let me also fix..." (scope creep)
- Create separate branches for other problems

### 6. SOLID Principles Reference
- **S (Single Responsibility)**: Each function/struct does only one thing
- **O (Open/Closed)**: Extensible without modifying existing code
- **L (Liskov Substitution)**: Subtypes substitutable for parent types
- **I (Interface Segregation)**: Small, focused interfaces
- **D (Dependency Inversion)**: Depend on abstractions, not concrete implementations

### 7. When to Stop Refactoring
- Code smell is resolved
- Code is clear and maintainable
- Further changes don't add practical value
- **YAGNI**: You Aren't Gonna Need It
