// 009-task-pool-many-waiters-burst.c
//
// Tests: libs/900-task-pool — iter4.5 wake-many-waiters semantics.
//
// What this verifies:
//   - Many tasks (50) parking on a single blocker B all wake when
//     B reaches DONE.
//   - All 50 waiters' downstream actions run after B finishes.
//   - No waiter is dropped, duplicated, or stuck parked.
//
// Pattern under test: 50 distinct A_i tasks each block on B's slot
// 0. B sleeps long enough that all 50 are parked before B starts
// producing. When B's last action returns, the wake pass walks
// B's waiters[] (length 50) and pushes all of them; the pool's
// workers then drain them.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N_WAITERS 50

static atomic_int waiters_woken = 0;
static atomic_int total_blocks  = 0;

static action_result_t b_step(task_ctx_t *ctx) {
    // Sleep long enough that all 50 A_i tasks have spawned and
    // returned ACT_BLOCK before B starts producing.
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 80 * 1000 * 1000 };
    nanosleep(&ts, NULL);
    int *v = malloc(sizeof *v);
    *v = 99;
    ctx->result_slots[ctx->current_index] = v;
    return ACT_ADVANCE;
}

static action_result_t a_wait(task_ctx_t *ctx) {
    task_id_t b_id = *(task_id_t *)ctx->args;
    void *raw = NULL;
    slot_status_t s = pool_result_slot(ctx->pool, b_id, 0, &raw);
    if (s == SLOT_PENDING) {
        atomic_fetch_add(&total_blocks, 1);
        ctx->block_on = b_id;
        return ACT_BLOCK;
    }
    if (s == SLOT_FILLED) {
        atomic_fetch_add(&waiters_woken, 1);
        return ACT_ADVANCE;
    }
    return ACT_DONE;
}

int main(void) {
    task_pool_t *pool = pool_create(4);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    action_fn_t b_acts[1] = { b_step };
    task_id_t   b_id = pool_spawn(pool, b_acts, NULL, 1, /*priority=*/5);
    pool_ref(pool, b_id);

    static task_id_t b_holder;
    b_holder = b_id;

    // Brief sleep so B is in the ready queue / running before A_i's
    // start spawning. This isn't required for correctness — the
    // BLOCK handler handles the "B is already DONE" case — but it
    // makes the test exercise the parking path rather than the
    // re-push-on-already-done path.
    struct timespec startup = { .tv_sec = 0, .tv_nsec = 5 * 1000 * 1000 };
    nanosleep(&startup, NULL);

    for (int i = 0; i < N_WAITERS; i++) {
        action_fn_t  a_acts[1] = { a_wait };
        void        *a_argv[1] = { &b_holder };
        pool_spawn(pool, a_acts, a_argv, 1, /*priority=*/3);
    }

    // 500ms generous: B sleeps 80ms, then ~50 wakes get pushed
    // and drained across 4 workers.
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 500 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    int woken = atomic_load(&waiters_woken);
    int blks  = atomic_load(&total_blocks);
    printf("waiters that observed B's value after wake: %d (expected %d)\n",
           woken, N_WAITERS);
    printf("total ACT_BLOCK returns across all waiters: %d (expected ~%d, exactly one per waiter)\n",
           blks, N_WAITERS);

    void *raw = NULL;
    if (pool_result_slot(pool, b_id, 0, &raw) == SLOT_FILLED) free(raw);
    pool_unref(pool, b_id);

    pool_destroy(pool);

    int ok = (woken == N_WAITERS) && (blks == N_WAITERS);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
