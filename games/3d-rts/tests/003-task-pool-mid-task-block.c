// 003-task-pool-mid-task-block.c
//
// Tests: libs/900-task-pool — mid-task ACT_BLOCK and resume,
// PLUS the iter4 demote-on-block behavior.
//
// What this verifies:
//   - An action returning ACT_BLOCK (with ctx->block_on set)
//     parks the task — the same action runs again later, with
//     current_index unchanged.
//   - The action AFTER the blocking one runs only once, after the
//     block resolves.
//   - Iter4.5 parking semantics: the block-action runs exactly TWO
//     times (once → BLOCK / park, once → ADVANCE), and both
//     invocations run at the SAME priority. (Iter4 demote-on-block
//     was deleted; with parking, no CPU is burned while waiting,
//     so demotion has no purpose.)
//
// Pattern under test (canonical "wait for another task"):
//   actions[0] = "I'm A, starting"
//   actions[1] = "is B done? if no, ACT_BLOCK on B; if yes, ADVANCE"
//   actions[2] = "I'm A, resumed and continuing"
//
// What this does NOT verify (covered elsewhere):
//   - That the BLOCK promoted B's priority — see 007.
//   - Self-rescheduling — see 004.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <time.h>

static atomic_int a_start_count   = 0;
static atomic_int a_block_count   = 0;
static atomic_int a_resumed_count = 0;
static atomic_int b_ran           = 0;

// Priority observed during each invocation of a_block_or_advance.
// Capacity 8 is more than enough — under iter4 the task can demote
// at most 9 levels (from 1 to 10), and the test only spins until
// B finishes (one BLOCK attempt expected, possibly two on slow
// systems).
#define MAX_PRIO_RECORDS 16
static atomic_int n_prio_records = 0;
static atomic_int prio_records[MAX_PRIO_RECORDS];

static action_result_t a_start(task_ctx_t *ctx) {
    (void)ctx;
    atomic_fetch_add(&a_start_count, 1);
    return ACT_ADVANCE;
}

static action_result_t a_block_or_advance(task_ctx_t *ctx) {
    task_id_t b = *(task_id_t *)ctx->args;
    int n = atomic_fetch_add(&a_block_count, 1);
    if (n < MAX_PRIO_RECORDS) {
        atomic_store(&prio_records[n], ctx->priority);
    }
    int s = pool_is_done(ctx->pool, b);
    if (s == 1) return ACT_ADVANCE;
    ctx->block_on = b;
    return ACT_BLOCK;
}

static action_result_t a_resumed(task_ctx_t *ctx) {
    (void)ctx;
    atomic_fetch_add(&a_resumed_count, 1);
    return ACT_ADVANCE;
}

static action_result_t b_step(task_ctx_t *ctx) {
    (void)ctx;
    // Sleep so A definitely sees B as not-done on its first
    // pass through the block action.
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 50 * 1000 * 1000 };
    nanosleep(&ts, NULL);
    atomic_fetch_add(&b_ran, 1);
    return ACT_ADVANCE;
}

int main(void) {
    task_pool_t *pool = pool_create(2);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    action_fn_t b_acts[1] = { b_step };
    task_id_t   b_id = pool_spawn(pool, b_acts, NULL, 1, /*priority=*/3);
    // Hold a ref on B so its registry entry survives long enough
    // for A's block-action to look up its status by GUID.
    pool_ref(pool, b_id);

    static task_id_t b_holder;
    b_holder = b_id;
    action_fn_t a_acts[3] = { a_start, a_block_or_advance, a_resumed };
    void       *a_argv[3] = { NULL,    &b_holder,          NULL };
    pool_spawn(pool, a_acts, a_argv, 3, /*priority=*/3);

    struct timespec ts = { .tv_sec = 0, .tv_nsec = 300 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    pool_unref(pool, b_id);

    int starts   = atomic_load(&a_start_count);
    int blocks   = atomic_load(&a_block_count);
    int resumes  = atomic_load(&a_resumed_count);
    int b_runs   = atomic_load(&b_ran);
    int recs     = blocks < MAX_PRIO_RECORDS ? blocks : MAX_PRIO_RECORDS;
    printf("a_start=%d (expected 1)\n", starts);
    printf("a_block_action ran %d times (expected exactly 2: block-then-park, then advance)\n", blocks);
    printf("a_resumed=%d (expected 1)\n", resumes);
    printf("b_ran=%d (expected 1)\n", b_runs);
    printf("priorities observed at each invocation:");
    for (int i = 0; i < recs; i++) printf(" %d", atomic_load(&prio_records[i]));
    printf("\n");

    pool_destroy(pool);

    // Iter4.5 parking check: priority must be unchanged across the
    // two invocations. Demote-on-block was deleted because parked
    // tasks consume zero CPU and don't need demotion to throttle them.
    int priority_unchanged = 0;
    if (blocks == 2) {
        int first  = atomic_load(&prio_records[0]);
        int second = atomic_load(&prio_records[1]);
        priority_unchanged = (second == first);
        printf("first invocation at p=%d, second at p=%d (parking requires second == first)\n",
               first, second);
    }

    int ok = (starts == 1) && (blocks == 2) && (resumes == 1)
          && (b_runs == 1) && priority_unchanged;
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
