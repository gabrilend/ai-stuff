// 002-task-pool-cross-task-result-wait.c
//
// Tests: libs/900-task-pool — the iter4 pattern for waiting on
// another task's output. Replaces the iter3 spawn-time-deps test:
// iter4 has no `deps` parameter on pool_spawn; cross-task waits
// happen at runtime via pool_result_slot reads inside actions
// paired with ACT_BLOCK.
//
// What this verifies:
//   - Task A reads task B's result slot via pool_result_slot. While
//     B's slot is SLOT_PENDING, A returns ACT_BLOCK with
//     block_on = B's id.
//   - The same action runs again later (after demote-and-requeue)
//     and eventually sees SLOT_FILLED, then advances.
//   - A's downstream action observes B's value (i.e. the BLOCK
//     actually waited; A did not advance past the slot read while
//     B was still pending).
//
// What this does NOT verify (covered elsewhere):
//   - That ACT_BLOCK demoted A's priority — see 003.
//   - That ACT_BLOCK promoted B's priority — see 007.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// What A's wait action observed: -2 = never ran, -1 = unexpected
// status, otherwise the value A read from B's slot (expect 42).
static atomic_int a_observed_b_value = -2;
static atomic_int a_block_attempts   = 0;

// B writes 42 to its slot 0 after a deliberate sleep so A
// definitely sees SLOT_PENDING on its first attempt.
static action_result_t b_step(task_ctx_t *ctx) {
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 50 * 1000 * 1000 };
    nanosleep(&ts, NULL);
    int *v = malloc(sizeof *v);
    *v = 42;
    ctx->result_slots[ctx->current_index] = v;
    return ACT_ADVANCE;
}

// A's "wait for B's slot 0" action. Polls via pool_result_slot;
// blocks while pending, advances once filled.
static action_result_t a_wait_on_b(task_ctx_t *ctx) {
    task_id_t b_id = *(task_id_t *)ctx->args;
    void *raw = NULL;
    slot_status_t s = pool_result_slot(ctx->pool, b_id, 0, &raw);

    if (s == SLOT_PENDING) {
        atomic_fetch_add(&a_block_attempts, 1);
        ctx->block_on = b_id;
        return ACT_BLOCK;
    }
    if (s == SLOT_FILLED) {
        atomic_store(&a_observed_b_value, raw ? *(int *)raw : -1);
        return ACT_ADVANCE;
    }
    atomic_store(&a_observed_b_value, -99);
    return ACT_ADVANCE;
}

static action_result_t a_done(task_ctx_t *ctx) {
    (void)ctx;
    return ACT_DONE;
}

int main(void) {
    task_pool_t *pool = pool_create(2);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    action_fn_t b_acts[1] = { b_step };
    task_id_t   b_id = pool_spawn(pool, b_acts, NULL, 1, /*priority=*/3);
    pool_ref(pool, b_id);

    static task_id_t b_holder;
    b_holder = b_id;
    action_fn_t a_acts[2] = { a_wait_on_b, a_done };
    void       *a_argv[2] = { &b_holder,    NULL };
    pool_spawn(pool, a_acts, a_argv, 2, /*priority=*/3);

    struct timespec ts = { .tv_sec = 0, .tv_nsec = 300 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    int observed = atomic_load(&a_observed_b_value);
    int blocks   = atomic_load(&a_block_attempts);
    printf("A observed B's slot value = %d (expected 42)\n", observed);
    // With iter4.5 parking, A's block-action should run exactly twice
    // total (the count tracked here is the number of BLOCK returns,
    // not invocations): once to park, once to advance after wake.
    // Since we count only the BLOCK returns, expect exactly 1.
    printf("A returned ACT_BLOCK %d time(s) (expected 1 with parking; iter4 spinning saw ~100k)\n", blocks);

    void *raw = NULL;
    if (pool_result_slot(pool, b_id, 0, &raw) == SLOT_FILLED) free(raw);
    pool_unref(pool, b_id);

    pool_destroy(pool);

    int ok = (observed == 42) && (blocks == 1);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
