// 004-task-pool-self-rescheduling.c
//
// Tests: libs/900-task-pool — the self-rescheduling pattern.
//
// What this verifies:
//   - A task whose final action calls pool_spawn to enqueue a fresh
//     copy of itself (with incremented state) can iterate N times
//     and then stop on a condition.
//   - Each iteration runs exactly once per spawn — no duplication
//     or skipping under the action-array / re-entry mechanics.
//
// Pattern under test (the "per-frame update loop without holding a
// worker hostage" idiom from the design discussion):
//   actions[0] = "do this iteration's work"
//   actions[1] = "if (current < target) spawn next iteration"
//
// What this does NOT verify (covered elsewhere):
//   - Self-rescheduling that BLOCKs partway — out of scope.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define TARGET 7

static atomic_int iterations_observed = 0;

static task_pool_t *g_pool = NULL;

typedef struct {
    int current;
    int target;
} iter_state_t;

static action_result_t do_work(task_ctx_t *ctx) {
    (void)ctx;
    atomic_fetch_add(&iterations_observed, 1);
    return ACT_ADVANCE;
}

static action_result_t maybe_reschedule(task_ctx_t *ctx) {
    iter_state_t *s = (iter_state_t *)ctx->args;
    if (s->current >= s->target) {
        free(s);
        return ACT_DONE;
    }
    iter_state_t *next = malloc(sizeof *next);
    next->current = s->current + 1;
    next->target  = s->target;
    free(s);

    action_fn_t  acts[2] = { do_work, maybe_reschedule };
    void        *args[2] = { next,    next };
    pool_spawn(g_pool, acts, args, 2, /*priority=*/5);
    return ACT_DONE;
}

int main(void) {
    g_pool = pool_create(2);
    if (!g_pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    iter_state_t *s = malloc(sizeof *s);
    s->current = 1;
    s->target  = TARGET;

    action_fn_t  acts[2] = { do_work, maybe_reschedule };
    void        *args[2] = { s,       s };
    pool_spawn(g_pool, acts, args, 2, /*priority=*/5);

    // Each iteration is essentially instantaneous; with 2 workers
    // and 7 iterations, 1s is generous.
    struct timespec ts = { .tv_sec = 1, .tv_nsec = 0 };
    nanosleep(&ts, NULL);

    int n = atomic_load(&iterations_observed);
    printf("iterations_observed=%d (expected %d)\n", n, TARGET);

    pool_destroy(g_pool);

    int ok = (n == TARGET);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
