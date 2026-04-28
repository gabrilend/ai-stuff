// 900-coroutine-pool.h
//
// Multiplexed coroutines on a fixed pool of pthreads (M:N).
//
// Why this exists: a place to run many cooperative tasks on a small
// set of OS threads, when the task graph is bigger than the thread
// budget. Not a fit when work is purely batch-parallel — for that, a
// plain parallel-for thread pool is simpler and has no stack-switch
// overhead. See issues/114-coroutine-pool-library.md for the full
// design rationale and the explicit non-adoption note relative to
// the project's two-thread architecture.
//
// Mechanics in one paragraph: each worker pthread runs a scheduler
// loop that pops a ready coroutine off a shared FIFO, swapcontext()s
// into the coroutine's own ucontext_t stack, and runs it until it
// yields or returns. On yield the coroutine is re-queued; on return
// a `finished` flag tells the worker to mark it DONE and broadcast
// to any joiner. The yield primitive uses a thread-local pointer to
// the currently-running coroutine, so callers do not pass a handle.

#ifndef COROUTINE_POOL_H
#define COROUTINE_POOL_H

#include <stddef.h>

// Opaque types. Consumers only ever hold pointers; the layout is an
// implementation detail of 900-coroutine-pool.c.
typedef struct cpool cpool_t;
typedef struct co    co_t;

// A coroutine entry point. Receives the arg passed to cpool_spawn.
// Returning from this function transitions the coroutine to DONE.
typedef void (*co_fn_t)(void *arg);

// Create a pool of n_workers pthreads. Returns NULL on allocation
// failure. n_workers must be >= 1.
cpool_t *cpool_create(int n_workers);

// Signal shutdown, join every worker, free the pool. The caller is
// responsible for having already joined every coroutine they spawned;
// any coroutine still in the queue or mid-yield at destroy time is
// leaked. This is intentional — silently freeing a coroutine that
// is mid-execution would be worse than the leak.
void cpool_destroy(cpool_t *pool);

// Allocate a coroutine, set up its ucontext on a fresh stack, and
// push it onto the ready queue. Returns a handle suitable for
// co_join. The handle remains valid until co_join returns.
co_t *cpool_spawn(cpool_t *pool, co_fn_t fn, void *arg);

// Block until the coroutine finishes, then free its resources.
// Calling co_join on the same coroutine from two threads is undefined.
void co_join(co_t *co);

// Cooperatively yield. Only valid from inside a coroutine running on
// a worker pthread; called from anywhere else it is a no-op rather
// than a crash, because the alternative (assert + abort) is hostile
// to library users who want to write code that runs in either
// context.
void co_yield(void);

#endif
