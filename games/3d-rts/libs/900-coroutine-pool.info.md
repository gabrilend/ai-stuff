# 900-coroutine-pool — external API

A small M:N scheduler: many coroutines multiplexed onto a fixed pool
of pthreads. Headers in `900-coroutine-pool.h`, implementation in
`900-coroutine-pool.c`. Design rationale and project-fit caveats are
in `issues/114-coroutine-pool-library.md`.

## Types

- `cpool_t` — opaque pool handle.
- `co_t` — opaque coroutine handle.
- `co_fn_t` — `typedef void (*co_fn_t)(void *arg)`. Coroutine entry
  point.

## Functions

### `cpool_t *cpool_create(int n_workers)`
- **Inputs:** `n_workers` ≥ 1, the number of pthreads to spawn.
- **Returns:** owning pool handle, or `NULL` on bad arg / allocation
  failure.
- **Notes:** workers start immediately and block on the (initially
  empty) ready queue.

### `void cpool_destroy(cpool_t *pool)`
- **Inputs:** pool returned by `cpool_create`.
- **Returns:** nothing.
- **Caller obligation:** must have already `co_join`ed every
  coroutine spawned on this pool. Coroutines still in the queue at
  destroy time are leaked, by design — see header for why.

### `co_t *cpool_spawn(cpool_t *pool, co_fn_t fn, void *arg)`
- **Inputs:** pool, a function pointer, an arbitrary user pointer.
- **Returns:** coroutine handle. The handle is valid until the
  matching `co_join` returns.
- **Notes:** the coroutine is scheduled immediately; a worker may
  begin running it before `cpool_spawn` returns to the caller.

### `void co_join(co_t *co)`
- **Inputs:** coroutine handle from `cpool_spawn`.
- **Returns:** nothing.
- **Notes:** blocks until the coroutine's top-level function has
  returned, then frees the coroutine. Joining the same handle from
  two threads concurrently is undefined.

### `void co_yield(void)`
- **Inputs:** none. Reads the per-thread "currently running
  coroutine" pointer set by the worker.
- **Returns:** nothing. Returns when the scheduler has re-selected
  this coroutine off the ready queue.
- **Call-site constraint:** only meaningful from inside a coroutine
  running on a worker pthread. Called from anywhere else (e.g. the
  main thread) it is a no-op. The deliberate choice is documented
  in the header.

## Call-site constraints summary

| Function         | Where it may be called           |
|------------------|----------------------------------|
| `cpool_create`   | anywhere                         |
| `cpool_destroy`  | anywhere; not from a worker      |
| `cpool_spawn`    | anywhere, including from inside a coroutine |
| `co_join`        | anywhere except the coroutine being joined  |
| `co_yield`       | only inside a coroutine; otherwise no-op    |

## Linking

- Requires `-lpthread`.
- Requires `ucontext.h` (glibc-provided on Linux; obsolete in POSIX
  2008 but still functional). The Makefile's existing `-lpthread`
  satisfies this; no extra link flag for ucontext.

## What is NOT in this library (yet)

- No channels, mailboxes, or wait-on-event primitive. `co_yield`
  always re-queues immediately. A `SUSPENDED` state plus a wakeup
  primitive would be the natural next addition.
- No work stealing. The single shared FIFO is the simplest design
  that demonstrates the model. A per-worker runqueue with stealing
  is the upgrade path.
- No timers. A coroutine that wants to sleep must call `nanosleep`,
  which blocks the worker. Adding a timer wheel would require the
  SUSPENDED state.
