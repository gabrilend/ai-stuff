// 007-task-pool-block-promotes-blocker.c
//
// Tests: libs/900-task-pool — iter4 promote-on-blocked-requester.
//
// What this verifies:
//   - Spawning B at low priority (high number) and then having A
//     block on B causes B's priority to be raised by one level
//     (toward 1).
//   - With iter4.5 parking, A's priority is UNCHANGED by the block
//     (no demote: parked tasks consume zero CPU so demotion would
//     accomplish nothing).
//
// Pattern under test:
//   - B spawns at priority 8 with a slow first action so it sits
//     in the priority-8 ready queue for a noticeable interval.
//   - A spawns at priority 3 and immediately blocks on B's slot.
//     The block triggers B's promotion (8 → 7) and A's demotion
//     (3 → 4).
//   - A and B both record the priority they ran at, observed via
//     ctx->priority.
//
// What this does NOT verify:
//   - Multiple-blocker promotion chains (each block only promotes
//     the immediate target, by design — see issue 114's locked
//     scope).

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static atomic_int b_first_priority = -1;
static atomic_int a_block_priority = -1;
static atomic_int a_advance_priority = -1;

// B's first action: deliberately slow so A has time to spawn,
// observe SLOT_PENDING, and BLOCK before B starts.
static action_result_t b_slow_start(task_ctx_t *ctx) {
    if (atomic_load(&b_first_priority) < 0) {
        atomic_store(&b_first_priority, ctx->priority);
    }
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 60 * 1000 * 1000 };
    nanosleep(&ts, NULL);
    return ACT_ADVANCE;
}

static action_result_t b_produce(task_ctx_t *ctx) {
    int *v = malloc(sizeof *v);
    *v = 7;
    ctx->result_slots[ctx->current_index] = v;
    return ACT_ADVANCE;
}

static action_result_t a_wait(task_ctx_t *ctx) {
    task_id_t b_id = *(task_id_t *)ctx->args;
    void *raw = NULL;
    slot_status_t s = pool_result_slot(ctx->pool, b_id, 1, &raw);
    if (s == SLOT_PENDING) {
        if (atomic_load(&a_block_priority) < 0) {
            atomic_store(&a_block_priority, ctx->priority);
        }
        ctx->block_on = b_id;
        return ACT_BLOCK;
    }
    atomic_store(&a_advance_priority, ctx->priority);
    return ACT_ADVANCE;
}

int main(void) {
    // 1 worker so that B and A don't truly run in parallel — A's
    // BLOCK happens deterministically while B is still sitting in
    // the priority-8 queue waiting for the cycler to consult it.
    task_pool_t *pool = pool_create(1);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    action_fn_t b_acts[2] = { b_slow_start, b_produce };
    task_id_t   b_id = pool_spawn(pool, b_acts, NULL, 2, /*priority=*/8);
    pool_ref(pool, b_id);

    static task_id_t b_holder;
    b_holder = b_id;
    action_fn_t a_acts[1] = { a_wait };
    void       *a_argv[1] = { &b_holder };
    pool_spawn(pool, a_acts, a_argv, 1, /*priority=*/3);

    struct timespec ts = { .tv_sec = 0, .tv_nsec = 400 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    int b_p   = atomic_load(&b_first_priority);
    int a_blk = atomic_load(&a_block_priority);
    int a_adv = atomic_load(&a_advance_priority);
    printf("B's first action ran at priority %d (spawn was 8; <8 means B got promoted)\n", b_p);
    printf("A's block invocation ran at priority %d (spawn was 3)\n",  a_blk);
    printf("A's advance invocation ran at priority %d (iter4.5: A's priority should be unchanged from spawn-time 3)\n", a_adv);

    void *raw = NULL;
    if (pool_result_slot(pool, b_id, 1, &raw) == SLOT_FILLED) free(raw);
    pool_unref(pool, b_id);

    pool_destroy(pool);

    int promoted          = (b_p > 0) && (b_p < 8);
    int a_priority_stable = (a_adv == 3);

    int ok = promoted && a_priority_stable;
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
