// 008-task-pool-result-filled-vs-null.c
//
// Tests: libs/900-task-pool — result_filled[] disambiguates "action
// k hasn't run" from "action k ran and chose to write NULL." Under
// iter3's pointer-only return, both cases collapsed to NULL; iter4
// adds a parallel bool array exposed via slot_status_t.
//
// What this verifies:
//   - Before action k runs, pool_result_slot returns SLOT_PENDING.
//   - If action k completes WITHOUT writing to its slot (slot stays
//     at the calloc'd NULL), pool_result_slot returns SLOT_FILLED
//     with *out == NULL — distinguishable from PENDING.
//   - If action k completes after writing a non-NULL value, the
//     status is SLOT_FILLED with *out == that value.
//   - SLOT_OUT_OF_RANGE for slot indices outside [0, n_actions).
//   - SLOT_UNKNOWN_ID for an id never spawned (hardened version
//     will eventually abort here; iter4 returns it as a value).
//
// Layout: a 3-action task. action 0 writes a non-NULL pointer.
// action 1 deliberately does NOT write to its slot. action 2 holds
// the task alive long enough for the externalreader to observe
// both states.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static atomic_int sentinel_for_slot0 = 7;

static action_result_t writes_non_null(task_ctx_t *ctx) {
    ctx->result_slots[ctx->current_index] = &sentinel_for_slot0;
    // Sleep so external reader can briefly observe slot 1 as PENDING
    // before action 1 runs (action 1 will leave its slot NULL).
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 30 * 1000 * 1000 };
    nanosleep(&ts, NULL);
    return ACT_ADVANCE;
}

static action_result_t writes_nothing(task_ctx_t *ctx) {
    (void)ctx;
    // Deliberately no write. Slot 1 remains NULL; result_filled[1]
    // becomes true after this returns.
    return ACT_ADVANCE;
}

static action_result_t holds_task_alive(task_ctx_t *ctx) {
    (void)ctx;
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 100 * 1000 * 1000 };
    nanosleep(&ts, NULL);
    return ACT_ADVANCE;
}

int main(void) {
    task_pool_t *pool = pool_create(2);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    action_fn_t acts[3] = { writes_non_null, writes_nothing, holds_task_alive };
    task_id_t   id = pool_spawn(pool, acts, NULL, 3, /*priority=*/3);
    pool_ref(pool, id);

    // Sample slot 1 early — should be PENDING (action 0 sleeping;
    // action 1 hasn't run yet).
    void *raw_early = (void *)0xdeadbeef;
    slot_status_t s_early = pool_result_slot(pool, id, 1, &raw_early);

    // Wait for the whole task to finish.
    struct timespec ts = { .tv_sec = 0, .tv_nsec = 250 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    // Slot 0: filled with non-NULL.
    void *raw0 = NULL;
    slot_status_t s0 = pool_result_slot(pool, id, 0, &raw0);

    // Slot 1: filled but value is NULL (the action chose not to write).
    void *raw1 = (void *)0xdeadbeef;
    slot_status_t s1 = pool_result_slot(pool, id, 1, &raw1);

    // Out-of-range slot.
    void *raw_oor = NULL;
    slot_status_t s_oor = pool_result_slot(pool, id, 99, &raw_oor);

    // Unknown id.
    void *raw_unk = NULL;
    slot_status_t s_unk = pool_result_slot(pool, (task_id_t)0xFFFFFFFF, 0, &raw_unk);

    printf("slot 1 sampled before action 1 ran:    status=%d (expect SLOT_PENDING=%d)\n",
           s_early, SLOT_PENDING);
    printf("slot 0 after completion:               status=%d val=%p (expect FILLED=%d, &sentinel=%p)\n",
           s0, raw0, SLOT_FILLED, (void *)&sentinel_for_slot0);
    printf("slot 1 after completion (no write):    status=%d val=%p (expect FILLED=%d, NULL)\n",
           s1, raw1, SLOT_FILLED);
    printf("slot 99 (out of range):                status=%d (expect OUT_OF_RANGE=%d)\n",
           s_oor, SLOT_OUT_OF_RANGE);
    printf("unknown id:                            status=%d (expect UNKNOWN_ID=%d)\n",
           s_unk, SLOT_UNKNOWN_ID);

    pool_unref(pool, id);
    pool_destroy(pool);

    int ok = (s_early == SLOT_PENDING)
          && (s0 == SLOT_FILLED) && (raw0 == &sentinel_for_slot0)
          && (s1 == SLOT_FILLED) && (raw1 == NULL)
          && (s_oor == SLOT_OUT_OF_RANGE)
          && (s_unk == SLOT_UNKNOWN_ID);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
