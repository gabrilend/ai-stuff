// 006-task-pool-result-slots.c
//
// Tests: libs/900-task-pool — write-once result_slots[] semantics.
//
// What this verifies:
//   - An action writes to ctx->result_slots[ctx->current_index].
//   - A LATER action in the same task can read EARLIER actions'
//     result slots and observe the value.
//   - An external caller (after the task completes) can read the
//     result slots via pool_result_slot, given a held refcount.
//
// What this does NOT verify (deliberately):
//   - Cross-task slot reading via GUID lookup. That pattern is
//     possible but isn't part of the documented mainline API; if
//     it becomes a real use case, add a separate test.

#include "../libs/900-task-pool.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static atomic_int observed_value = 0;

// action 0: write 42 into our own slot.
static action_result_t write_42(task_ctx_t *ctx) {
    int *v = malloc(sizeof *v);
    *v = 42;
    ctx->result_slots[ctx->current_index] = v;
    return ACT_ADVANCE;
}

// action 1: read action 0's slot and remember what we saw.
static action_result_t read_slot_0(task_ctx_t *ctx) {
    int *v = (int *)ctx->result_slots[0];
    if (v) atomic_store(&observed_value, *v);
    return ACT_ADVANCE;
}

int main(void) {
    task_pool_t *pool = pool_create(2);
    if (!pool) { fprintf(stderr, "pool_create failed\n"); return 1; }

    action_fn_t acts[2] = { write_42, read_slot_0 };
    task_id_t   id = pool_spawn(pool, acts, NULL, 2, 3);
    pool_ref(pool, id);  // keep the task alive so we can read the slot externally.

    struct timespec ts = { .tv_sec = 0, .tv_nsec = 100 * 1000 * 1000 };
    nanosleep(&ts, NULL);

    int internal_observed = atomic_load(&observed_value);
    void *raw = NULL;
    slot_status_t s = pool_result_slot(pool, id, 0, &raw);
    int *external = (s == SLOT_FILLED) ? (int *)raw : NULL;
    int external_value = external ? *external : -1;

    printf("internal-read of slot[0] (by next action): %d (expected 42)\n",
           internal_observed);
    printf("external-read of slot[0] (via pool_result_slot): %d (expected 42)\n",
           external_value);

    // Free the malloc'd int from the slot before unref so it doesn't
    // leak. (The library frees the slots ARRAY but not what each
    // slot points at — by design; the writer owns the lifetime of
    // their value.)
    free(external);
    pool_unref(pool, id);

    pool_destroy(pool);

    int ok = (internal_observed == 42) && (external_value == 42);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
