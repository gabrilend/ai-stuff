// 900-coroutine-pool.c
//
// Implementation of the M:N coroutine scheduler declared in
// 900-coroutine-pool.h. Read the header first; it has the
// one-paragraph mechanical description.
//
// Layout of this file, top to bottom:
//
//   1. Includes and tunables.
//   2. Internal types (state enum, struct co, struct cpool).
//   3. Thread-local scheduler state (current coroutine, sched ctx).
//   4. Ready queue: q_push / q_pop_blocking.
//   5. The trampoline that ucontext starts each coroutine in.
//   6. The worker_main scheduler loop.
//   7. Public API: cpool_create, cpool_destroy, cpool_spawn,
//      co_yield, co_join.
//
// The stack-switch primitive is `swapcontext` from <ucontext.h>.
// That function is the only POSIX-obsolete dependency in this file;
// if a future port needs a different primitive, it would be
// confined to the trampoline setup in cpool_spawn and the two
// swapcontext call sites in worker_main and co_yield.

#define _XOPEN_SOURCE 600  // ucontext.h needs this on glibc.

#include "900-coroutine-pool.h"

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <ucontext.h>

// 64 KB per coroutine stack. Small enough that ten thousand
// coroutines fit in well under a gigabyte; large enough for normal
// C call depth without page-fault recursion. If a real workload
// shows this is the wrong size, expose it as a cpool_create_ex
// parameter — do not silently grow it here.
#define CO_STACK_SIZE (64 * 1024)

// Coroutine lifecycle. A coroutine is READY in the queue, RUNNING
// while a worker is swapped into it, and DONE after its top-level
// function returned. There is no SUSPENDED state because yield in
// this minimal version always re-queues immediately — there is no
// channel/sleep/wait primitive that would hold a coroutine off the
// queue. Adding one is the natural next feature; it would introduce
// a SUSPENDED state and a wakeup path.
typedef enum {
    CO_READY,
    CO_RUNNING,
    CO_DONE
} co_state_t;

// {{{ struct co
struct co {
    ucontext_t      ctx;        // the coroutine's saved register frame.
    void           *stack;      // owning pointer to the coroutine's stack.
    co_fn_t         fn;         // user-provided entry point.
    void           *arg;        // user-provided arg to fn.
    co_state_t      state;      // READY | RUNNING | DONE.
    bool            finished;   // set by trampoline when fn returns.
    pthread_mutex_t lk;         // guards state + done_cv for joiner.
    pthread_cond_t  done_cv;    // joiner waits here until state==DONE.
    struct co      *next;       // intrusive link in the ready queue.
    cpool_t        *pool;       // back-pointer; needed by future yield variants.
};
// }}}

// {{{ struct cpool
struct cpool {
    pthread_t      *workers;     // length n_workers.
    int             n_workers;
    bool            shutdown;    // set under qlk; broadcast on qcv.

    pthread_mutex_t qlk;         // guards q_head, q_tail, shutdown.
    pthread_cond_t  qcv;         // signals queue non-empty OR shutdown.
    co_t           *q_head;      // FIFO of ready coroutines, NULL if empty.
    co_t           *q_tail;      // tail pointer for O(1) push.
};
// }}}

// Per-worker scheduler state. tls_current names the coroutine the
// worker is currently swapped into (or NULL between coroutines).
// tls_sched_ctx is the worker's own ucontext, written by swapcontext
// when entering a coroutine and restored when the coroutine yields
// or returns.
//
// __thread is used in preference to C11 _Thread_local because every
// compiler this project targets (gcc/clang on Linux) supports it
// without a feature-test macro.
static __thread co_t      *tls_current = NULL;
static __thread ucontext_t tls_sched_ctx;

// {{{ static void q_push(cpool_t *pool, co_t *co)
static void q_push(cpool_t *pool, co_t *co) {
    pthread_mutex_lock(&pool->qlk);
    co->next = NULL;
    if (pool->q_tail) pool->q_tail->next = co;
    else              pool->q_head = co;
    pool->q_tail = co;
    pthread_cond_signal(&pool->qcv);
    pthread_mutex_unlock(&pool->qlk);
}
// }}}

// {{{ static co_t *q_pop_blocking(cpool_t *pool)
//
// Returns the next ready coroutine, blocking on qcv if the queue is
// empty. Returns NULL when shutdown has been requested and the queue
// is drained — the worker uses NULL as its exit signal.
static co_t *q_pop_blocking(cpool_t *pool) {
    pthread_mutex_lock(&pool->qlk);
    while (!pool->q_head && !pool->shutdown) {
        pthread_cond_wait(&pool->qcv, &pool->qlk);
    }
    co_t *co = pool->q_head;
    if (co) {
        pool->q_head = co->next;
        if (!pool->q_head) pool->q_tail = NULL;
        co->next = NULL;
    }
    pthread_mutex_unlock(&pool->qlk);
    return co;
}
// }}}

// {{{ static void co_trampoline(unsigned int hi, unsigned int lo)
//
// makecontext can only pass int-sized arguments. On a 64-bit system
// a co_t* is 64 bits, so we split the pointer into two 32-bit halves
// at spawn and reassemble it here. This is the standard portable
// workaround documented in glibc's makecontext(3) example.
//
// When fn returns, control falls through to ctx.uc_link, which the
// worker sets to &tls_sched_ctx before each swap-in. The worker
// resumes after its swapcontext() call, sees co->finished == true,
// and runs the join handshake. We do NOT take co->lk and broadcast
// from inside the trampoline, because doing so would require the
// joiner to wait for the *worker* to finish unwinding rather than
// the *coroutine*, and would also race with any worker-side
// bookkeeping that runs after the swapcontext returns.
static void co_trampoline(unsigned int hi, unsigned int lo) {
    uintptr_t p = ((uintptr_t)hi << 32) | (uintptr_t)lo;
    co_t *co = (co_t *)p;
    co->fn(co->arg);
    co->finished = true;
    // implicit return → uc_link → tls_sched_ctx in the worker.
}
// }}}

// {{{ static void *worker_main(void *arg)
//
// One worker pthread. Loops: pop a coroutine, swap into it, decide
// whether it's done or just yielding, repeat. Exits when q_pop_blocking
// returns NULL with shutdown set, which it only does when the queue
// is also empty.
static void *worker_main(void *arg) {
    cpool_t *pool = (cpool_t *)arg;
    while (1) {
        co_t *co = q_pop_blocking(pool);
        if (!co) {
            // pool->shutdown is set and the queue is empty: time to leave.
            break;
        }

        tls_current  = co;
        co->state    = CO_RUNNING;

        // uc_link is set per-run because tls_sched_ctx is per-worker;
        // a coroutine can be picked up by any worker, so the link has
        // to point at *this* worker's scheduler context, not the one
        // captured at spawn time.
        co->ctx.uc_link = &tls_sched_ctx;

        swapcontext(&tls_sched_ctx, &co->ctx);

        // Returned from the coroutine, either via yield or via the
        // trampoline reaching the end of fn. tls_current is cleared
        // before either re-queueing or the join handshake, because
        // the coroutine could be picked up by another worker (or
        // freed by a joiner) the instant we touch the queue or the
        // condvar.
        tls_current = NULL;

        if (co->finished) {
            // Join handshake. After the unlock the joiner is free to
            // wake up, observe DONE, and call free() on co — so we
            // must not touch co again after this point.
            pthread_mutex_lock(&co->lk);
            co->state = CO_DONE;
            pthread_cond_broadcast(&co->done_cv);
            pthread_mutex_unlock(&co->lk);
        } else {
            co->state = CO_READY;
            q_push(pool, co);
        }
    }
    return NULL;
}
// }}}

// {{{ cpool_t *cpool_create(int n_workers)
cpool_t *cpool_create(int n_workers) {
    if (n_workers < 1) return NULL;

    cpool_t *pool = calloc(1, sizeof *pool);
    if (!pool) return NULL;

    pool->workers   = calloc((size_t)n_workers, sizeof(pthread_t));
    pool->n_workers = n_workers;
    pthread_mutex_init(&pool->qlk, NULL);
    pthread_cond_init(&pool->qcv, NULL);

    for (int i = 0; i < n_workers; i++) {
        pthread_create(&pool->workers[i], NULL, worker_main, pool);
    }
    return pool;
}
// }}}

// {{{ void cpool_destroy(cpool_t *pool)
void cpool_destroy(cpool_t *pool) {
    pthread_mutex_lock(&pool->qlk);
    pool->shutdown = true;
    pthread_cond_broadcast(&pool->qcv);
    pthread_mutex_unlock(&pool->qlk);

    for (int i = 0; i < pool->n_workers; i++) {
        pthread_join(pool->workers[i], NULL);
    }

    pthread_mutex_destroy(&pool->qlk);
    pthread_cond_destroy(&pool->qcv);
    free(pool->workers);
    free(pool);
}
// }}}

// {{{ co_t *cpool_spawn(cpool_t *pool, co_fn_t fn, void *arg)
co_t *cpool_spawn(cpool_t *pool, co_fn_t fn, void *arg) {
    co_t *co = calloc(1, sizeof *co);
    if (!co) return NULL;

    co->fn       = fn;
    co->arg      = arg;
    co->state    = CO_READY;
    co->finished = false;
    co->pool     = pool;
    co->stack    = malloc(CO_STACK_SIZE);
    pthread_mutex_init(&co->lk, NULL);
    pthread_cond_init(&co->done_cv, NULL);

    // ucontext setup. getcontext seeds the struct with valid signal
    // mask + flags for this platform; without it, makecontext on
    // glibc produces undefined behavior.
    getcontext(&co->ctx);
    co->ctx.uc_stack.ss_sp   = co->stack;
    co->ctx.uc_stack.ss_size = CO_STACK_SIZE;
    co->ctx.uc_link          = NULL;  // worker overwrites per-run.

    // Split the co_t* pointer into two int-sized halves so it can
    // be passed through makecontext's varargs (which only accept
    // int). The trampoline reassembles them.
    uintptr_t    p  = (uintptr_t)co;
    unsigned int hi = (unsigned int)(p >> 32);
    unsigned int lo = (unsigned int)(p & 0xFFFFFFFFu);
    makecontext(&co->ctx, (void (*)(void))co_trampoline, 2, hi, lo);

    q_push(pool, co);
    return co;
}
// }}}

// {{{ void co_yield(void)
void co_yield(void) {
    co_t *me = tls_current;
    // Called outside a coroutine: documented as a no-op, not a crash.
    // The reasoning is in the header.
    if (!me) return;
    swapcontext(&me->ctx, &tls_sched_ctx);
}
// }}}

// {{{ void co_join(co_t *co)
void co_join(co_t *co) {
    pthread_mutex_lock(&co->lk);
    while (co->state != CO_DONE) {
        pthread_cond_wait(&co->done_cv, &co->lk);
    }
    pthread_mutex_unlock(&co->lk);

    // After unlock, the worker that finished this coroutine has no
    // remaining reference to it (see the comment in worker_main),
    // so we can safely tear it down.
    pthread_mutex_destroy(&co->lk);
    pthread_cond_destroy(&co->done_cv);
    free(co->stack);
    free(co);
}
// }}}
