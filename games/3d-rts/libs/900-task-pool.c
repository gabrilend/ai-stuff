// 900-task-pool.c
//
// Implementation of the action-array task pool declared in
// 900-task-pool.h. Read the header first; it has the type sketch
// and the mental model. Read issues/114-coroutine-pool-library.md's
// "Iteration 4 — locked scope" section for the rationale of every
// design choice made here.
//
// File layout, top to bottom:
//
//   1. Includes and tunables.
//   2. Internal types: task_state_t, task_t (registry row),
//      task_pool_t (the ten priority queues + registry + workers).
//   3. Registry: open-addressed hashmap keyed on (id & mask).
//   4. Priority cycler: advance() pattern producing
//      1; 1,2; 1,2,3; ...; 1..10; 1,2; ...
//   5. Ready queue ops (arrays-per-priority, swap-with-last splice).
//   6. Promote/demote helpers (task_demote_one,
//      task_promote_one_if_ready).
//   7. Worker loop: pop a task, run one action, dispatch on the
//      action's return code, repeat.
//   8. Public API: pool_create, pool_destroy, pool_spawn, pool_ref,
//      pool_unref, pool_result_slot, pool_is_done.
//
// Iter4 vs iter3: the waiting queue, scanner task, scanner_running
// flag, and wait_set/n_wait fields are all gone. ACT_BLOCK now
// re-pushes onto the ready queue at a higher priority number, and
// optionally promotes the task it's blocking on. Cross-task waits
// are user-driven via pool_result_slot reads + ACT_BLOCK.

#define _XOPEN_SOURCE 600

#include "900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ─── tunables ────────────────────────────────────────────────────

// Number of priority levels. Levels are 1..N_PRIORITIES inclusive.
#define N_PRIORITIES 10

// Initial registry capacity. Power of two. Iter5 (issue 124)
// replaces the registry's value type with int slot indices and
// adds a free-list dense pointer array; iter4 keeps the
// pointer-valued open-addressed hash with tombstones.
#define REGISTRY_CAPACITY 4096
#define REGISTRY_MASK     (REGISTRY_CAPACITY - 1)

// Sentinel for tombstoned (previously-occupied, now-empty) registry
// slots. Lookups must continue past tombstones; inserts may
// overwrite them.
#define TOMBSTONE ((struct task *)(uintptr_t)1)

// Initial capacity of each per-priority ready queue array. The
// queue grows by doubling when full.
#define QUEUE_INITIAL_CAP 8

// Cycler attempt count = one full period of the pattern
// 1; 1,2; 1,2,3; ...; 1..N. Period length = sum(k=2..N) =
// N*(N+1)/2 - 1 = 54 for N=10. Within one period every priority
// p in [1..N] is consulted at least once.
#define CYCLER_PERIOD_STEPS ((N_PRIORITIES * (N_PRIORITIES + 1) / 2) - 1)

// ─── internal types ──────────────────────────────────────────────

typedef struct task task_t;

typedef enum {
    TASK_READY,    // in one of the ten priority queues, awaiting a worker.
    TASK_RUNNING,  // some worker is currently executing it.
    TASK_PARKED,   // not in any queue; sits on a blocker's waiters[] list.
                   //   Will be pushed back to ready when the blocker is DONE.
    TASK_DONE,     // finished. result_slots are filled (or stayed NULL).
} task_state_t;

// {{{ struct task
struct task {
    task_id_t       id;             // GUID assigned at spawn.
    atomic_int      refcount;       // pool holds 1, plus any external pool_ref.

    // State is read by code paths under reg_lk (BLOCK handler, queries)
    // and written by code paths under qlk (queue_push sets READY) and
    // reg_lk (BLOCK handler sets PARKED, DONE handler sets DONE). To
    // avoid a data race on cross-lock reads, state is atomic. Memory
    // order: relaxed is sufficient because the surrounding mutex
    // acquires/releases provide ordering.
    _Atomic task_state_t state;

    // The task body itself. Owned: freed when the task is freed.
    action_fn_t    *actions;        // length n_actions.
    void          **action_args;    // length n_actions; NULL slots are fine.
    int             n_actions;
    int             current_index;  // resume point. Survives across re-queues.

    // Per-action outputs + filled bits. Stable address; arrays do
    // not move when the task moves between queues. result_filled[k]
    // is set to true by the worker after action k returns
    // ACT_ADVANCE/ACT_JUMP/ACT_DONE; it stays false on ACT_BLOCK
    // (the action did not complete this attempt).
    void          **result_slots;   // length n_actions, all NULL initially.
    bool           *result_filled;  // length n_actions, all false initially.

    int             priority;       // 1..N_PRIORITIES. Mutable: demoted on
                                    //   ACT_BLOCK, possibly promoted by a
                                    //   blocked requester. No floor concept;
                                    //   tasks are short-lived enough that
                                    //   accumulation is bounded by lifetime.

    // Position in the priority queue's flat array for the task's
    // current priority. Used for O(1) splice-from-middle via
    // swap-with-last. -1 means "not currently in any queue"
    // (e.g., RUNNING, PARKED, or DONE).
    int             queue_position;

    // Parked-on-me list: ids of tasks that returned ACT_BLOCK with
    // their block_on pointing at THIS task. NULL until first waiter
    // arrives. When this task reaches DONE, the worker walks
    // waiters[], pushes each waiter back to the ready queue, and
    // frees the array. Owned by this task.
    task_id_t      *waiters;
    int             n_waiters;
    int             cap_waiters;
};
// }}}

// {{{ struct task_pool
struct task_pool {
    pthread_t      *workers;
    int             n_workers;
    bool            shutdown;       // set under qlk; broadcast on qcv.

    // ─── registry ─────────────────────────────────────────
    pthread_mutex_t reg_lk;         // guards table[].
    struct task    *table[REGISTRY_CAPACITY];  // open-addressed.
    atomic_uint_least64_t next_id;  // monotonic GUID counter; 0 is reserved.

    // ─── ready queues ────────────────────────────────────
    // One flat array per priority level. Index 0 is unused (priorities
    // start at 1) so queues[priority] is the natural lookup. Each
    // queue is a growable array of task pointers; the task's
    // queue_position field tells us where it sits in queues[priority].
    pthread_mutex_t qlk;            // guards queues[], lens[], caps[],
                                    //   level, step, n_ready_total,
                                    //   shutdown.
    pthread_cond_t  qcv;            // signaled when a task lands in any queue.
    struct task   **queues[N_PRIORITIES + 1];   // queues[p] = task ptr array.
    int             queue_lens[N_PRIORITIES + 1];
    int             queue_caps[N_PRIORITIES + 1];
    int             n_ready_total;  // sum of queue_lens[1..N].

    // Cycler state. (level, step) advances on every pop attempt.
    int             level;          // current level cap, 2..N_PRIORITIES.
    int             step;           // current step within this level, 1..level.
};
// }}}

// ─── registry ────────────────────────────────────────────────────

// {{{ static void registry_insert(task_pool_t *pool, task_t *t)
//
// Open-addressed insert at slot `id & MASK`, linear-probing past
// occupied slots and reusing tombstones. Caller holds reg_lk.
// Asserts on table-full because silently overwriting an existing
// entry would be a memory-corruption nightmare.
static void registry_insert(task_pool_t *pool, struct task *t) {
    size_t i = (size_t)(t->id & REGISTRY_MASK);
    for (size_t probes = 0; probes < REGISTRY_CAPACITY; probes++) {
        size_t k = (i + probes) & REGISTRY_MASK;
        if (pool->table[k] == NULL || pool->table[k] == TOMBSTONE) {
            pool->table[k] = t;
            return;
        }
    }
    abort();  // registry full — better to crash than to lose tasks.
}
// }}}

// {{{ static task_t *registry_lookup(task_pool_t *pool, task_id_t id)
//
// Returns the task with this GUID, or NULL if not present. Skips
// past tombstones (they mean "kept probing past here in the past,
// so a real entry might still be further down"). Caller holds
// reg_lk.
static struct task *registry_lookup(task_pool_t *pool, task_id_t id) {
    if (id == TASK_ID_NONE) return NULL;
    size_t i = (size_t)(id & REGISTRY_MASK);
    for (size_t probes = 0; probes < REGISTRY_CAPACITY; probes++) {
        size_t k = (i + probes) & REGISTRY_MASK;
        struct task *t = pool->table[k];
        if (t == NULL) return NULL;
        if (t == TOMBSTONE) continue;
        if (t->id == id) return t;
    }
    return NULL;
}
// }}}

// {{{ static void registry_remove(task_pool_t *pool, task_id_t id)
//
// Replaces the slot with a tombstone so subsequent lookups for
// other ids that probed past this slot still find their target.
// Caller holds reg_lk.
static void registry_remove(task_pool_t *pool, task_id_t id) {
    size_t i = (size_t)(id & REGISTRY_MASK);
    for (size_t probes = 0; probes < REGISTRY_CAPACITY; probes++) {
        size_t k = (i + probes) & REGISTRY_MASK;
        struct task *t = pool->table[k];
        if (t == NULL) return;
        if (t == TOMBSTONE) continue;
        if (t->id == id) {
            pool->table[k] = TOMBSTONE;
            return;
        }
    }
}
// }}}

// ─── task lifetime ───────────────────────────────────────────────

// {{{ static void task_free(task_t *t)
//
// Destroys a task struct and all its owned arrays. Called when
// refcount hits zero. Does NOT touch the registry — the caller is
// expected to have removed the registry entry before the last
// pool_unref drops the count.
static void task_free(struct task *t) {
    free(t->actions);
    free(t->action_args);
    free(t->result_slots);
    free(t->result_filled);
    free(t->waiters);
    free(t);
}
// }}}

// ─── priority cycler ─────────────────────────────────────────────

// {{{ static void advance_cycler(task_pool_t *pool)
//
// Implements the pattern: 1; 1,2; 1,2,3; ...; 1..N; then back to
// 1; 1,2; 1,2,3; ... as `level` resets to 2 and grows again. Caller
// holds qlk.
static void advance_cycler(task_pool_t *pool) {
    pool->step++;
    if (pool->step > pool->level) {
        pool->step = 1;
        pool->level++;
        if (pool->level > N_PRIORITIES) pool->level = 2;
    }
}
// }}}

// ─── ready queues (arrays per priority, swap-with-last splice) ───

// {{{ static void queue_push(task_pool_t *pool, task_t *t)
//
// Append a task to the tail of queues[t->priority]. Grows the
// queue's storage if needed. Updates t->queue_position to its new
// index. Signals qcv so any worker blocked on an empty pool wakes.
// Caller holds qlk.
static void queue_push(task_pool_t *pool, struct task *t) {
    int p = t->priority;
    if (pool->queue_lens[p] >= pool->queue_caps[p]) {
        int new_cap = pool->queue_caps[p] * 2;
        if (new_cap < QUEUE_INITIAL_CAP) new_cap = QUEUE_INITIAL_CAP;
        pool->queues[p] = realloc(pool->queues[p],
                                   (size_t)new_cap * sizeof(struct task *));
        pool->queue_caps[p] = new_cap;
    }
    int idx = pool->queue_lens[p]++;
    pool->queues[p][idx] = t;
    t->queue_position = idx;
    atomic_store_explicit(&t->state, TASK_READY, memory_order_relaxed);
    pool->n_ready_total++;
    pthread_cond_signal(&pool->qcv);
}
// }}}

// {{{ static void queue_remove_at(task_pool_t *pool, int p, int idx)
//
// Swap-with-last removal from queues[p][idx]. The task that was
// at the last slot moves into the vacated position; its
// queue_position is updated so future swap-with-last operations
// targeting it work correctly. The removed task's queue_position
// is set to -1 (not in any queue). Caller holds qlk.
//
// FIFO ordering at priority p is not preserved; this is intentional
// per iter4's design (priority is the throttle, not order).
static void queue_remove_at(task_pool_t *pool, int p, int idx) {
    int last = pool->queue_lens[p] - 1;
    struct task *removed = pool->queues[p][idx];
    if (idx != last) {
        struct task *moved = pool->queues[p][last];
        pool->queues[p][idx] = moved;
        moved->queue_position = idx;
    }
    pool->queue_lens[p]--;
    removed->queue_position = -1;
    pool->n_ready_total--;
}
// }}}

// {{{ static task_t *queue_pop_one(task_pool_t *pool, int p)
//
// Remove and return queues[p][0]. Returns NULL if the queue is
// empty. Uses swap-with-last to fill the hole at index 0. Caller
// holds qlk.
static struct task *queue_pop_one(task_pool_t *pool, int p) {
    if (pool->queue_lens[p] == 0) return NULL;
    struct task *t = pool->queues[p][0];
    queue_remove_at(pool, p, 0);
    return t;
}
// }}}

// {{{ static task_t *ready_pop_locked(task_pool_t *pool)
//
// Pop the next task using the cycler; advance on every consultation
// (whether successful or not) so a single popular priority can't
// bias the rotation. Returns NULL only if all ten queues are empty.
// Caller holds qlk.
static struct task *ready_pop_locked(task_pool_t *pool) {
    if (pool->n_ready_total == 0) return NULL;
    for (int attempts = 0; attempts < CYCLER_PERIOD_STEPS; attempts++) {
        int p = pool->step;
        struct task *t = queue_pop_one(pool, p);
        advance_cycler(pool);
        if (t) return t;
    }
    return NULL;  // n_ready_total was stale; should not normally happen.
}
// }}}

// {{{ static task_t *ready_pop_blocking(task_pool_t *pool)
//
// Standard "wait until there's something to pop or we're shutting
// down" loop. Returns NULL only if shutdown was requested AND no
// ready tasks remain — that's the worker's exit signal.
static struct task *ready_pop_blocking(task_pool_t *pool) {
    pthread_mutex_lock(&pool->qlk);
    while (pool->n_ready_total == 0 && !pool->shutdown) {
        pthread_cond_wait(&pool->qcv, &pool->qlk);
    }
    struct task *t = (pool->n_ready_total > 0) ? ready_pop_locked(pool) : NULL;
    pthread_mutex_unlock(&pool->qlk);
    return t;
}
// }}}

// ─── promote + park ──────────────────────────────────────────────
//
// Iter4.5 parking: instead of demote-and-spin on ACT_BLOCK, the
// task parks on its blocker's waiters[] list and consumes zero
// CPU until woken. Promote-on-blocked-target stays — promoting B
// so it runs sooner means parked A unparks sooner.
//
// Lock order across all sites: reg_lk → qlk. Both helpers and the
// BLOCK handler call into queue ops while holding reg_lk; nothing
// takes the locks in the opposite order.

// {{{ static void task_promote_one_if_ready(task_pool_t *pool, task_t *t)
//
// If task t is currently in the ready queue, splice it out of its
// current priority's array, decrement its priority (toward more
// urgent), and re-push onto the new priority's array. If t is
// RUNNING, PARKED, or DONE, do nothing — RUNNING is executing
// flat-out, PARKED is waiting for someone else (its priority
// doesn't matter while parked), DONE is finished.
//
// Caller holds reg_lk. This function acquires qlk internally
// (lock order reg_lk → qlk).
static void task_promote_one_if_ready(task_pool_t *pool, struct task *t) {
    if (atomic_load_explicit(&t->state, memory_order_relaxed) != TASK_READY) {
        return;
    }
    if (t->priority <= 1) return;        // already at top.

    pthread_mutex_lock(&pool->qlk);
    // Re-check state under qlk; pop could have happened between the
    // outer check and acquiring the lock.
    if (atomic_load_explicit(&t->state, memory_order_relaxed) == TASK_READY
        && t->queue_position >= 0
        && t->priority > 1) {
        int old_p = t->priority;
        queue_remove_at(pool, old_p, t->queue_position);
        t->priority = old_p - 1;
        queue_push(pool, t);
    }
    pthread_mutex_unlock(&pool->qlk);
}
// }}}

// {{{ static void waiters_append(task_t *blocker, task_id_t waiter_id)
//
// Append waiter_id to blocker->waiters[], growing the array if
// needed. Caller holds reg_lk.
static void waiters_append(struct task *blocker, task_id_t waiter_id) {
    if (blocker->n_waiters >= blocker->cap_waiters) {
        int new_cap = blocker->cap_waiters * 2;
        if (new_cap < 4) new_cap = 4;
        blocker->waiters = realloc(blocker->waiters,
                                    (size_t)new_cap * sizeof(task_id_t));
        blocker->cap_waiters = new_cap;
    }
    blocker->waiters[blocker->n_waiters++] = waiter_id;
}
// }}}

// ─── worker loop ─────────────────────────────────────────────────

// {{{ static void run_task(task_pool_t *pool, task_t *t)
//
// Execute exactly one action of the task, dispatch on the result.
// On ADVANCE/JUMP, requeue the task at its current priority. On
// BLOCK, demote self, promote block_on (if applicable), requeue.
// On DONE or fall-through, mark complete and drop the pool ref.
//
// Why one action per call rather than a tight loop: cooperative
// fairness. Other tasks get a turn between each action of any one
// task. The cost is one queue push+pop per action; this is cheap
// (no syscalls, just lock-protected array ops).
static void run_task(task_pool_t *pool, struct task *t) {
    atomic_store_explicit(&t->state, TASK_RUNNING, memory_order_relaxed);

    // Build the per-call context.
    task_ctx_t ctx;
    ctx.self_id        = t->id;
    ctx.current_index  = t->current_index;
    ctx.args           = t->action_args ? t->action_args[t->current_index] : NULL;
    ctx.result_slots   = t->result_slots;
    ctx.n_slots        = t->n_actions;
    ctx.pool           = pool;
    ctx.priority       = t->priority;
    ctx.jump_to        = -1;
    ctx.block_on       = TASK_ID_NONE;

    action_result_t r = t->actions[t->current_index](&ctx);

    switch (r) {
        case ACT_ADVANCE:
            // Action completed; mark the slot filled (regardless of
            // whether the action wrote a value). Bump current_index.
            t->result_filled[t->current_index] = true;
            t->current_index++;
            break;

        case ACT_JUMP:
            // Action completed; mark filled. Trust the jump target;
            // an out-of-range jump falls off the end on the next
            // iteration's bounds check.
            t->result_filled[t->current_index] = true;
            t->current_index = ctx.jump_to;
            break;

        case ACT_BLOCK: {
            // Action did NOT complete this attempt — leave
            // result_filled[current_index] alone (still false).
            //
            // Park self on block_on's waiters[] list. ctx.block_on
            // must be a valid id of a non-self task; this is a hard
            // contract.
            //
            // Lock order: reg_lk first, qlk acquired internally by
            // task_promote_one_if_ready when it needs to splice.
            // The DONE handler also takes reg_lk first then qlk;
            // no site takes them in the opposite order.
            if (ctx.block_on == TASK_ID_NONE) {
                fprintf(stderr,
                        "task-pool: ACT_BLOCK without block_on (task %llu, action %d)\n",
                        (unsigned long long)t->id, t->current_index);
                abort();
            }
            if (ctx.block_on == t->id) {
                fprintf(stderr,
                        "task-pool: ACT_BLOCK on self (task %llu, action %d)\n",
                        (unsigned long long)t->id, t->current_index);
                abort();
            }

            pthread_mutex_lock(&pool->reg_lk);
            struct task *blocker = registry_lookup(pool, ctx.block_on);

            if (!blocker) {
                fprintf(stderr,
                        "task-pool: ACT_BLOCK on unknown id %llu (task %llu, action %d)\n",
                        (unsigned long long)ctx.block_on,
                        (unsigned long long)t->id, t->current_index);
                pthread_mutex_unlock(&pool->reg_lk);
                abort();
            }

            task_state_t bstate = atomic_load_explicit(&blocker->state,
                                                        memory_order_relaxed);
            if (bstate == TASK_DONE) {
                // Blocker already finished — parking would be
                // pointless. Re-push self so the action runs
                // again immediately and observes the filled slot.
                pthread_mutex_lock(&pool->qlk);
                queue_push(pool, t);
                pthread_mutex_unlock(&pool->qlk);
            } else {
                // Park self on blocker's waiters list.
                waiters_append(blocker, t->id);
                atomic_store_explicit(&t->state, TASK_PARKED,
                                      memory_order_relaxed);
                t->queue_position = -1;
                // Promote blocker if it's READY at non-top priority.
                task_promote_one_if_ready(pool, blocker);
            }
            pthread_mutex_unlock(&pool->reg_lk);
            return;
        }

        case ACT_DONE:
            // Skip remaining actions. Mark the action that returned
            // DONE as filled; later actions stay unfilled because
            // they never ran.
            t->result_filled[t->current_index] = true;
            t->current_index = t->n_actions;
            break;
    }

    if (t->current_index < t->n_actions) {
        // More work to do; requeue at the task's current priority.
        pthread_mutex_lock(&pool->qlk);
        queue_push(pool, t);
        pthread_mutex_unlock(&pool->qlk);
        return;
    }

    // Fell off the end. Mark DONE and wake any parked waiters.
    //
    // Wake pass under reg_lk: walk t->waiters[]. For each id,
    // look up the waiter; if it's still PARKED, push it back
    // onto its current priority's queue (state → READY via
    // queue_push). Skip waiters that are no longer PARKED
    // (e.g., the user dropped a refcount on them) or no longer
    // in the registry. Lock order reg_lk → qlk.
    pthread_mutex_lock(&pool->reg_lk);
    atomic_store_explicit(&t->state, TASK_DONE, memory_order_relaxed);

    if (t->n_waiters > 0) {
        pthread_mutex_lock(&pool->qlk);
        for (int i = 0; i < t->n_waiters; i++) {
            struct task *w = registry_lookup(pool, t->waiters[i]);
            if (!w) continue;
            task_state_t ws = atomic_load_explicit(&w->state,
                                                    memory_order_relaxed);
            if (ws == TASK_PARKED) {
                queue_push(pool, w);
            }
        }
        pthread_mutex_unlock(&pool->qlk);
        // Free the waiters array now; we won't be re-using this task.
        free(t->waiters);
        t->waiters     = NULL;
        t->n_waiters   = 0;
        t->cap_waiters = 0;
    }

    bool last_ref = (atomic_fetch_sub(&t->refcount, 1) == 1);
    if (last_ref) {
        registry_remove(pool, t->id);
    }
    pthread_mutex_unlock(&pool->reg_lk);

    if (last_ref) task_free(t);
}
// }}}

// {{{ static void *worker_main(void *arg)
//
// Standard pop/run/repeat worker loop. Exits when ready_pop_blocking
// returns NULL with shutdown set.
static void *worker_main(void *arg) {
    task_pool_t *pool = (task_pool_t *)arg;
    while (1) {
        struct task *t = ready_pop_blocking(pool);
        if (!t) break;
        run_task(pool, t);
    }
    return NULL;
}
// }}}

// ─── public API ──────────────────────────────────────────────────

// {{{ task_pool_t *pool_create(int n_workers)
task_pool_t *pool_create(int n_workers) {
    if (n_workers < 1) return NULL;
    task_pool_t *pool = calloc(1, sizeof *pool);
    if (!pool) return NULL;

    pool->n_workers = n_workers;
    pool->workers   = calloc((size_t)n_workers, sizeof(pthread_t));

    pthread_mutex_init(&pool->reg_lk, NULL);
    pthread_mutex_init(&pool->qlk,    NULL);
    pthread_cond_init (&pool->qcv,    NULL);

    atomic_store(&pool->next_id, 1);  // 0 is reserved as TASK_ID_NONE.

    // Cycler initial state: (level=2, step=1) so the first ten
    // pops produce the sequence 1, 2 (first cycle), 1, 2, 3
    // (second), and so on — matching the documented pattern.
    pool->level = 2;
    pool->step  = 1;

    // Per-priority queues are lazily allocated on first push to
    // keep a fresh pool's allocation footprint small. queue_caps
    // and queue_lens are zeroed by calloc; queues[p] starts NULL.

    for (int i = 0; i < n_workers; i++) {
        pthread_create(&pool->workers[i], NULL, worker_main, pool);
    }
    return pool;
}
// }}}

// {{{ void pool_destroy(task_pool_t *pool)
void pool_destroy(task_pool_t *pool) {
    pthread_mutex_lock(&pool->qlk);
    pool->shutdown = true;
    pthread_cond_broadcast(&pool->qcv);
    pthread_mutex_unlock(&pool->qlk);

    for (int i = 0; i < pool->n_workers; i++) {
        pthread_join(pool->workers[i], NULL);
    }

    // Drop pool refs on any tasks still in the registry. Anything
    // still reachable here was never naturally completed.
    pthread_mutex_lock(&pool->reg_lk);
    for (size_t k = 0; k < REGISTRY_CAPACITY; k++) {
        struct task *t = pool->table[k];
        if (t == NULL || t == TOMBSTONE) continue;
        if (atomic_fetch_sub(&t->refcount, 1) == 1) {
            task_free(t);
        }
        pool->table[k] = TOMBSTONE;
    }
    pthread_mutex_unlock(&pool->reg_lk);

    // Free per-priority queue storage. queues[p] may still contain
    // dangling task pointers if shutdown happened mid-queue, but
    // those tasks were freed above; we just free the array storage
    // here.
    for (int p = 0; p <= N_PRIORITIES; p++) {
        free(pool->queues[p]);
    }

    pthread_mutex_destroy(&pool->reg_lk);
    pthread_mutex_destroy(&pool->qlk);
    pthread_cond_destroy (&pool->qcv);
    free(pool->workers);
    free(pool);
}
// }}}

// {{{ task_id_t pool_spawn(...)
task_id_t pool_spawn(task_pool_t *pool,
                     const action_fn_t *actions,
                     void *const      *action_args,
                     int               n_actions,
                     int               priority) {
    if (!pool || !actions || n_actions <= 0) return TASK_ID_NONE;

    if (priority < 1)             priority = 1;
    if (priority > N_PRIORITIES)  priority = N_PRIORITIES;

    struct task *t = calloc(1, sizeof *t);
    if (!t) return TASK_ID_NONE;

    t->id             = (task_id_t)atomic_fetch_add(&pool->next_id, 1);
    atomic_store(&t->refcount, 1);  // pool's reference.
    t->n_actions      = n_actions;
    t->current_index  = 0;
    t->priority       = priority;
    t->queue_position = -1;  // not yet in any queue.

    t->actions = malloc((size_t)n_actions * sizeof(action_fn_t));
    memcpy(t->actions, actions, (size_t)n_actions * sizeof(action_fn_t));

    if (action_args) {
        t->action_args = malloc((size_t)n_actions * sizeof(void *));
        memcpy(t->action_args, action_args, (size_t)n_actions * sizeof(void *));
    } else {
        t->action_args = NULL;
    }

    t->result_slots  = calloc((size_t)n_actions, sizeof(void *));
    t->result_filled = calloc((size_t)n_actions, sizeof(bool));

    // Insert into registry first so the GUID is resolvable
    // immediately after pool_spawn returns. No deps in iter4 — the
    // task is always immediately ready.
    pthread_mutex_lock(&pool->reg_lk);
    registry_insert(pool, t);
    pthread_mutex_unlock(&pool->reg_lk);

    pthread_mutex_lock(&pool->qlk);
    queue_push(pool, t);
    pthread_mutex_unlock(&pool->qlk);

    return t->id;
}
// }}}

// {{{ void pool_ref(task_pool_t *pool, task_id_t id)
void pool_ref(task_pool_t *pool, task_id_t id) {
    pthread_mutex_lock(&pool->reg_lk);
    struct task *t = registry_lookup(pool, id);
    if (t) atomic_fetch_add(&t->refcount, 1);
    pthread_mutex_unlock(&pool->reg_lk);
}
// }}}

// {{{ void pool_unref(task_pool_t *pool, task_id_t id)
void pool_unref(task_pool_t *pool, task_id_t id) {
    pthread_mutex_lock(&pool->reg_lk);
    struct task *t = registry_lookup(pool, id);
    if (!t) {
        pthread_mutex_unlock(&pool->reg_lk);
        return;
    }
    bool last = (atomic_fetch_sub(&t->refcount, 1) == 1);
    if (last) {
        registry_remove(pool, id);
    }
    pthread_mutex_unlock(&pool->reg_lk);
    if (last) task_free(t);
}
// }}}

// {{{ slot_status_t pool_result_slot(...)
slot_status_t pool_result_slot(task_pool_t *pool,
                                task_id_t id,
                                int slot,
                                void **out) {
    pthread_mutex_lock(&pool->reg_lk);
    struct task *t = registry_lookup(pool, id);
    if (!t) {
        pthread_mutex_unlock(&pool->reg_lk);
        return SLOT_UNKNOWN_ID;
    }
    if (slot < 0 || slot >= t->n_actions) {
        pthread_mutex_unlock(&pool->reg_lk);
        return SLOT_OUT_OF_RANGE;
    }
    bool   filled = t->result_filled[slot];
    void  *value  = t->result_slots[slot];
    pthread_mutex_unlock(&pool->reg_lk);

    if (!filled) return SLOT_PENDING;
    if (out) *out = value;
    return SLOT_FILLED;
}
// }}}

// {{{ int pool_is_done(task_pool_t *pool, task_id_t id)
int pool_is_done(task_pool_t *pool, task_id_t id) {
    pthread_mutex_lock(&pool->reg_lk);
    struct task *t = registry_lookup(pool, id);
    int r;
    if (t == NULL) {
        r = -1;
    } else {
        task_state_t s = atomic_load_explicit(&t->state, memory_order_relaxed);
        r = (s == TASK_DONE) ? 1 : 0;
    }
    pthread_mutex_unlock(&pool->reg_lk);
    return r;
}
// }}}
