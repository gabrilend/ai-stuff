# 114 — Coroutine Pool Library (M:N over pthreads)

## Status

TODO

## Current behavior

`libs/` is empty. The project's only described concurrency primitives
are the two dedicated pthreads from issue 102 (main + sim) and the two
mutexes that guard the input queue and snapshot pointer swap.

There is no general-purpose mechanism for spawning many cooperative
tasks onto a small set of OS threads — every concurrent piece of work
would need its own bespoke thread, queue, and lifecycle.

## Intended behavior

`libs/` contains a small, self-contained C library that multiplexes
many coroutines onto a fixed pool of pthreads. A consumer can:

- Create a pool of N worker pthreads.
- Spawn coroutines onto the pool. Each runs on its own ucontext stack.
- Cooperatively yield from inside a coroutine to release the worker.
- Join on a coroutine to wait for completion.
- Destroy the pool and reclaim resources.

The library has no dependency on raylib, no dependency on game state,
and no global mutable state aside from the per-thread "currently-running
coroutine" pointer that the yield primitive needs.

The library is **available** to the rest of the project but **not yet
adopted** by it. The two-thread architecture in `docs/004-architecture.md`
remains the design of record. See "Why this exists separately from 102"
below.

## Suggested implementation steps

1. Create `libs/900-coroutine-pool.h` declaring the public API:
   `cpool_create`, `cpool_destroy`, `cpool_spawn`, `co_yield`, `co_join`,
   plus the opaque `cpool_t` and `co_t` handle types.
2. Create `libs/900-coroutine-pool.c` implementing the worker loop,
   the FIFO ready queue (mutex + condvar), the ucontext-based stack
   switch, and the coroutine lifecycle (READY → RUNNING → DONE, with
   join handshake).
3. Create `libs/900-coroutine-pool.info.md` listing each external
   function with its inputs, outputs, and call-site constraints (e.g.
   `co_yield` is only valid from inside a coroutine running on a worker).
4. Add a `libs/` section to `docs/000-table-of-contents.md` so the new
   files are discoverable.
5. Add a "Related libraries" cross-reference to
   `issues/102-threading-model.md` pointing at this library, with a
   sentence explaining that adoption is a separate decision.

## Mechanical description

A worker pthread is a scheduler loop. Each iteration:

1. Pop the next ready coroutine off the shared FIFO (block on a condvar
   if the queue is empty).
2. `swapcontext` from the worker's own scheduler context into the
   coroutine's ucontext. The coroutine now runs on its own stack on
   this OS thread.
3. The coroutine runs until it either calls `co_yield` (which
   `swapcontext`s back to the worker) or returns from its top-level
   function (which falls through `uc_link` back to the worker).
4. The worker inspects a `finished` flag set by the trampoline. If
   set, it takes the coroutine's lock, marks it `DONE`, and broadcasts
   to any joiner. If not set, it re-pushes the coroutine onto the
   ready queue.

`co_yield` is implemented as a `swapcontext` from the current
coroutine's context back to a thread-local "scheduler context"
established by the worker before each `swapcontext` in. The
thread-local also names the currently-running coroutine, so
`co_yield` does not need its handle as an argument.

The ready queue is a mutex-guarded singly-linked list with one
condvar. A condvar broadcast signals workers to re-check the queue.
`shutdown` is a flag plus a broadcast.

Pointer-into-ucontext: `makecontext` only accepts `int`-sized
arguments, so the coroutine handle pointer is split into two
`unsigned int` halves (high/low) and reassembled inside the
trampoline. This is the standard portable workaround on 64-bit
platforms.

## Why this exists separately from 102

Issue 102 commits to *exactly two* pthreads with a clear data
boundary. The argument for the two-thread design is that game state
is owned by one thread and the rendering-thread reads only a
snapshot; introducing more threads would require either re-locking
game state or replicating snapshots.

A coroutine pool is the right tool when many tasks need to share a
small thread budget without per-task pthreads. Concrete fits inside
this project would be:

- Parallel per-tick subsystems inside the sim thread (LOS checks,
  projectile integration, AI evaluation) — but only if profiling
  shows the sim thread is CPU-bound.
- A future asset/audio loader that wants to overlap I/O with sim work
  without dedicating a permanent thread to each loader.

Adopting it for any of those is a *separate* design decision,
deserving its own issue. This issue only delivers the library.

## Related documents

- `docs/003-tech-stack.md` — pthreads is the threading primitive of
  record; this library is built on top of it, not in place of it.
- `docs/004-architecture.md` — current two-thread design.
- `issues/102-threading-model.md` — the issue that lands the two
  pthreads this library would, in some hypothetical future, multiplex.

## Notes

`ucontext.h` is marked obsolete in POSIX 2008 but remains present
and functional on glibc/Linux, which is the project's target. If the
project ever needs to run elsewhere, the stack-switch primitive
becomes the only file that needs replacing — the queue, scheduler
loop, and public API stay the same. That is part of the reason the
stack-switch happens in exactly one function.

A future enhancement could replace the single-mutex FIFO with a
per-worker runqueue plus work stealing, which is what Go's runtime
and Tokio's multi-thread executor do. The single queue is the
simplest version that demonstrates the model and is sufficient until
profiling justifies the more complex design.

## Deprecation candidates

- `tmp/test-coroutine-pool.c` — the smoke test used to validate the
  initial implementation (5 coroutines × 3 yields → 15 ticks, exit 0
  under `-Wall -Wextra -Wpedantic`). Per the mono-repo's "keep
  temporary tests for at least one commit" rule it lives in `tmp/`
  for now. It should either be promoted to a proper phase demo (the
  natural fit is the Phase 1 demo in `issues/completed/demos/`) or
  renamed `test-coroutine-pool-done.c` and removed in a subsequent
  commit. Decision deferred until the Phase 1 demo skeleton exists.
