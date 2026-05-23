# Go for C# Developers: Interview Cheat Sheet

## 1. Big Mental Model

- Go is small by design: fewer language features, more explicit code.
- No classes, inheritance, constructors, exceptions, async/await, LINQ, attributes, nullable reference types, or generics-heavy framework style.
- Composition beats inheritance: structs hold data, interfaces describe behavior.
- Formatting is standardized with `gofmt`; do not fight it.
- Visibility is by name: `Exported` is public outside the package, `unexported` is private to the package.
- Package names matter more than namespaces. A folder is usually one package.

## 2. Project Shape

```go
module github.com/OmerMachluf/go-interview-prep

go 1.22
```

- `go.mod` defines the module.
- `main` package builds an executable.
- Other packages are libraries.
- Tests live next to code as `*_test.go`.
- Run: `go test ./...`, `go run .`, `go build ./...`, `go fmt ./...`, `go vet ./...`.

## 3. Syntax Essentials

```go
package main

import "fmt"

func main() {
    name := "Omer"      // infer local variable
    var count int = 3   // explicit
    fmt.Println(name, count)
}
```

- `:=` works only inside functions.
- Unused imports and variables are compile errors.
- Braces are mandatory.
- Semicolons exist but are inserted automatically.
- No ternary operator.
- `if`, `for`, and `switch` do not require parentheses.

```go
if n := len(items); n == 0 {
    return
}

for i := 0; i < 10; i++ {}
for _, item := range items {}
for condition {}
for {} // infinite loop
```

## 4. Types and Zero Values

- Every type has a zero value:
- `int`: `0`
- `bool`: `false`
- `string`: `""`
- pointers, slices, maps, channels, funcs, interfaces: `nil`
- structs: each field gets its zero value.

```go
var s string // ""
var p *User  // nil
```

Landmine: zero value can be useful, but nil maps panic on assignment.

```go
var m map[string]int
// m["x"] = 1 // panic
m = make(map[string]int)
m["x"] = 1
```

## 5. Structs Instead of Classes

```go
type User struct {
    ID   int
    Name string
}

func (u User) DisplayName() string {
    return u.Name
}

func (u *User) Rename(name string) {
    u.Name = name
}
```

- Methods are functions with receivers.
- Value receiver copies the value.
- Pointer receiver can mutate and avoids copying.
- No constructor syntax; use factory functions when needed.

```go
func NewUser(name string) *User {
    return &User{Name: name}
}
```

## 6. Interfaces Are Implicit

```go
type Reader interface {
    Read(p []byte) (int, error)
}
```

- A type implements an interface automatically by having its methods.
- Small interfaces are idiomatic.
- Prefer accepting interfaces and returning concrete types.
- `interface{}` or `any` means anything; use sparingly.

Landmine: an interface value can be non-nil while holding a nil concrete pointer.

## 7. Error Handling

```go
value, err := doWork()
if err != nil {
    return fmt.Errorf("do work: %w", err)
}
```

- Errors are ordinary return values.
- No exceptions for normal flow.
- Wrap with `%w`.
- Check with `errors.Is` and `errors.As`.
- `panic` is for programmer bugs or unrecoverable states, not routine validation.

## 8. Defer

```go
f, err := os.Open(path)
if err != nil {
    return err
}
defer f.Close()
```

- `defer` runs when the surrounding function returns.
- Deferred calls run last-in, first-out.
- Arguments to deferred calls are evaluated immediately.

Landmine: deferring inside huge loops can keep resources open too long.

## 9. Slices and Arrays

```go
nums := []int{1, 2, 3}
nums = append(nums, 4)
```

- Arrays have fixed length and are less common: `[3]int`.
- Slices are descriptors over arrays: pointer, length, capacity.
- `append` may reallocate; always use its returned slice.
- Slicing can keep a large backing array alive.
- `len(s)` length, `cap(s)` capacity.

Landmine: modifying a slice can modify shared backing storage.

## 10. Maps

```go
counts := map[string]int{"a": 1}
value, ok := counts["missing"]
```

- Missing keys return zero value.
- Use comma-ok to distinguish missing from present-zero.
- Maps are reference-like.
- Built-in maps are not safe for concurrent writes.

## 11. Pointers

```go
x := 10
p := &x
fmt.Println(*p)
```

- No pointer arithmetic.
- Use pointers for mutation, optional-ish values, large structs, and shared identity.
- Use values for small immutable-ish data.
- Escape analysis decides stack vs heap; `new` is rare.

## 12. Initialization Behavior

Order:

1. Imported packages initialize first.
2. Package-level variables initialize in file/package order determined by dependencies.
3. `init()` functions run.
4. `main()` runs.

```go
var defaultTimeout = 5 * time.Second

func init() {
    log.SetFlags(log.LstdFlags)
}
```

- Avoid complex `init()`; it hides dependencies.
- Prefer explicit setup functions for testability.
- Package-level mutable state is a concurrency and testing landmine.

## 13. Goroutines, Not Coroutines

Go uses goroutines: lightweight concurrent functions scheduled by the Go runtime.

```go
go func() {
    doWork()
}()
```

- `go f()` starts `f` concurrently and returns immediately.
- A program exits when `main` returns, even if goroutines are still running.
- Use `sync.WaitGroup`, channels, or contexts to coordinate.
- Goroutines are cheap, not free.

## 14. Channels

```go
ch := make(chan int)

go func() {
    ch <- 42
    close(ch)
}()

for v := range ch {
    fmt.Println(v)
}
```

- Send: `ch <- value`
- Receive: `value := <-ch`
- Close by sender when no more values will be sent.
- Receiving from closed channel gives zero value plus `ok=false`.
- Unbuffered channels block until sender and receiver meet.
- Buffered channels block only when full or empty.

Landmines:

- Sending on a closed channel panics.
- Closing a channel twice panics.
- Nil channels block forever.
- Do not use channels when a mutex is clearer.

## 15. Select

```go
select {
case v := <-ch:
    return v
case <-ctx.Done():
    return 0
}
```

- `select` waits on multiple channel operations.
- Add `default` only when non-blocking behavior is intended.
- Common with `context.Context` for cancellation and timeouts.

## 16. Context

```go
func Fetch(ctx context.Context, id string) error {
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return err
    }
    _ = req
    return nil
}
```

- Pass `context.Context` as the first parameter.
- Do not store context in structs.
- Do not pass nil context; use `context.Background()` or `context.TODO()`.
- Use for cancellation, deadlines, and request-scoped values.

## 17. Concurrency Safety

```go
var mu sync.Mutex
mu.Lock()
defer mu.Unlock()
```

- Race conditions are easy; run `go test -race ./...`.
- Maps are unsafe for concurrent writes.
- Prefer ownership: one goroutine owns mutable state.
- Use `sync.Mutex`, `sync.RWMutex`, `sync.Once`, `atomic`, channels, or `errgroup` depending on shape.

## 18. Generics

```go
func First[T any](items []T) (T, bool) {
    if len(items) == 0 {
        var zero T
        return zero, false
    }
    return items[0], true
}
```

- Type parameters exist, but Go style still favors simple concrete code.
- Use generics for containers, algorithms, and type-safe helpers.
- Avoid C#-style abstraction towers.

## 19. Testing

```go
func TestAdd(t *testing.T) {
    got := Add(2, 3)
    if got != 5 {
        t.Fatalf("got %d, want %d", got, 5)
    }
}
```

- Table-driven tests are common.
- `t.Fatal` stops the test; `t.Error` continues.
- Use `t.Helper()` inside test helpers.
- Use `go test ./...`.

## 20. Goland Tips

- Let Goland run `gofmt` and organize imports on save.
- Use "Generate" for tests, methods, and interface implementations.
- Use "Show Implementations" because interfaces are implicit.
- Configure Go SDK and module indexing before interview practice.
- Run package tests and `go test ./...` from the IDE terminal.

## 21. Interview Landmines Checklist

- Did you check every `err`?
- Did you accidentally shadow a variable with `:=`?
- Did you use the returned slice from `append`?
- Did you initialize maps before writing?
- Did you coordinate goroutines before `main` exits?
- Did you close channels only from the sender?
- Did you pass `context.Context` first?
- Did you avoid shared mutable state or protect it?
- Did you choose pointer vs value receiver intentionally?
- Did you keep interfaces small and behavior-focused?
- Did you avoid overengineering with generics?
- Did you run `gofmt`, `go test ./...`, and maybe `go test -race ./...`?

