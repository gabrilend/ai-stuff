// 005-task-pool-priority-cycler.c
//
// Tests: libs/900-task-pool — the priority cycler
// (1; 1,2; 1,2,3; ...; 1..10; 1,2; ...).
//
// What this verifies:
//   - With many tasks pending at multiple priorities, every priority
//     eventually completes (no starvation of the lowest level).
//   - High-priority tasks (1) complete sooner on average than
//     low-priority ones (10), demonstrated by the order in which
//     completion timestamps land.
//
// What this does NOT verify rigorously:
//   - The exact 1; 1,2; 1,2,3; ... shape of the cycler. With short
//     trivial tasks and 2+ workers running concurrently, the
//     observed order is interleaved enough that statistical bias
//     toward priority 1 is the only thing reliably testable here.
//     A finer-grained verification would need single-threaded mode
//     and instrumentation hooks the library does not currently
//     expose. Noted as a coverage gap in tests/000-index.md.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <time.h>

// 50 per priority (× 2 priorities = 100 tasks total) chosen because
// the task spawn path has nontrivial per-task allocation overhead
// (calloc, memcpy of actions/args, registry insertion under lock).
// Larger counts inflate the test runtime past the 10s timeout
// without adding any signal — 100 tasks already pin the
// "avg1 < avg10" expectation reliably.
#define N_PER_PRIORITY 50

// Per-priority completion-order sums. Each task records its
// completion order (a global counter); summing per-priority and
// dividing gives the average completion order. Lower = sooner.
static atomic_int global_order = 0;
static atomic_long sum_p1  = 0;
static atomic_long sum_p10 = 0;
static atomic_int  count_p1  = 0;
static atomic_int  count_p10 = 0;

static action_result_t tick_p1(task_ctx_t *ctx) {
    (void)ctx;
    int order = atomic_fetch_add(&global_order, 1);
    atomic_fetch_add(&sum_p1, order);
    atomic_fetch_add(&count_p1, 1);
    return ACT_ADVANCE;
}

static action_result_t tick_p10(task_ctx_t *ctx) {
    (void)ctx;
    int order = atomic_fetch_add(&global_order, 1);
    atomic_fetch_add(&sum_p10, order);
    atomic_fetch_add(&count_p10, 1);
    return ACT_ADVANCE;
}

int main(void) {
    task_pool_t *pool = pool_create(2);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    // Spawn N at priority 1 AND N at priority 10, interleaved so
    // queue-arrival order doesn't dominate completion order.
    for (int i = 0; i < N_PER_PRIORITY; i++) {
        action_fn_t acts1[1] = { tick_p1 };
        action_fn_t acts10[1] = { tick_p10 };
        pool_spawn(pool, acts1,  NULL, 1, 1);
        pool_spawn(pool, acts10, NULL, 1, 10);
    }

    struct timespec ts = { .tv_sec = 0, .tv_nsec = 500 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    int c1  = atomic_load(&count_p1);
    int c10 = atomic_load(&count_p10);
    long s1  = atomic_load(&sum_p1);
    long s10 = atomic_load(&sum_p10);
    double avg1  = c1  ? (double)s1  / c1  : -1.0;
    double avg10 = c10 ? (double)s10 / c10 : -1.0;

    printf("priority 1:  %d completed, average completion order %.1f\n",  c1,  avg1);
    printf("priority 10: %d completed, average completion order %.1f\n",  c10, avg10);
    printf("(lower order = completed sooner; we expect avg1 < avg10)\n");

    pool_destroy(pool);

    int ok = 1;
    if (c1  != N_PER_PRIORITY) ok = 0;
    if (c10 != N_PER_PRIORITY) ok = 0;
    // Bias must be in the right direction. We don't pin the exact
    // ratio because the cycler's strict 1; 1,2; 1,2,3; ... pattern
    // is only observable in single-threaded execution; with
    // multiple workers running concurrently the observed order
    // interleaves significantly. Requiring avg1 strictly less than
    // avg10 is the best we can verify here.
    if (avg1 >= avg10) ok = 0;

    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
