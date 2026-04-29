// 001-task-pool-sequential-actions.c
//
// Tests: libs/900-task-pool — basic action-array execution.
//
// What this verifies:
//   - A task with N actions runs all N actions exactly once.
//   - Actions run in order (current_index 0, 1, 2, ..., N-1).
//   - Each action receives its own args from action_args[k].
//
// What this does NOT verify (covered elsewhere):
//   - Dependencies, BLOCK, JUMP, DONE, self-rescheduling, priorities,
//     result slots — see other 00*.c files in this directory.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <time.h>

static atomic_int actions_run    = 0;
static atomic_int order_violation = 0;
static atomic_int last_index     = -1;
static atomic_int args_violation = 0;

static action_result_t step(task_ctx_t *ctx) {
    int *expected = (int *)ctx->args;
    if (*expected != ctx->current_index) {
        atomic_fetch_add(&args_violation, 1);
    }
    int prev = atomic_exchange(&last_index, ctx->current_index);
    if (prev >= ctx->current_index) {
        atomic_fetch_add(&order_violation, 1);
    }
    atomic_fetch_add(&actions_run, 1);
    return ACT_ADVANCE;
}

int main(void) {
    task_pool_t *pool = pool_create(2);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    int          arg0 = 0, arg1 = 1, arg2 = 2, arg3 = 3, arg4 = 4;
    void        *argv[5] = { &arg0, &arg1, &arg2, &arg3, &arg4 };
    action_fn_t  acts[5] = { step, step, step, step, step };

    pool_spawn(pool, acts, argv, 5, /*priority=*/3);

    // 100ms is generous for 5 trivial actions on a 2-worker pool.
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 100 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    pool_destroy(pool);

    int run     = atomic_load(&actions_run);
    int order   = atomic_load(&order_violation);
    int args_v  = atomic_load(&args_violation);
    printf("actions_run=%d order_violations=%d args_violations=%d\n",
           run, order, args_v);

    int ok = (run == 5) && (order == 0) && (args_v == 0);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
