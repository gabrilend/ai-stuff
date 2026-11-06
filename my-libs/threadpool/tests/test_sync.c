/*
 * Test: Sync Module (Watch List)
 *
 * Verifies sync context creation, watch list management, and pointer swapping.
 * Each test reads a swapped pointer only after it has seen the ready flag go
 * back to false, which is the handoff rule the module documents.
 */

#include "../src/threadpool_sync.h"
#include "test_common.h"
#include <stdlib.h>

/* {{{ Test State */
static atomic_int g_log_calls = 0;
/* }}} */

/* {{{ test_logger */
static void test_logger(const char* fmt, ...) {
    (void)fmt;
    atomic_fetch_add(&g_log_calls, 1);
}
/* }}} */

/* {{{ test_sync_create_destroy */
static int test_sync_create_destroy(void) {
    /* Test: sync creates and destroys cleanly */
    TpSyncConfig cfg = tp_sync_config_default();
    TpSyncContext* ctx = tp_sync_create(&cfg);

    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");

    tp_sync_destroy(ctx);
    TEST_PASS("test_sync_create_destroy");
    return 0;
}
/* }}} */

/* {{{ test_sync_add_watch */
static int test_sync_add_watch(void) {
    /* Test: add_watch succeeds */
    TpSyncConfig cfg = tp_sync_config_default();
    TpSyncContext* ctx = tp_sync_create(&cfg);
    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");

    atomic_bool ready = false;
    void* target = NULL;
    void* source = (void*)0x1234;

    bool result = tp_sync_add_watch(ctx, &ready, &target, source);
    TEST_ASSERT(result == true, "add_watch should succeed");

    tp_sync_destroy(ctx);
    TEST_PASS("test_sync_add_watch");
    return 0;
}
/* }}} */

/* {{{ test_sync_pointer_swap */
static int test_sync_pointer_swap(void) {
    /* Test: pointer swap occurs when ready flag set */
    TpSyncConfig cfg = tp_sync_config_default();
    TpSyncContext* ctx = tp_sync_create(&cfg);
    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");

    atomic_bool ready = false;
    void* target = NULL;
    void* source = (void*)0xDEADBEEF;

    /* Add watch entry */
    tp_sync_add_watch(ctx, &ready, &target, source);

    /* Spawn sync thread */
    pthread_t thread = tp_sync_spawn(ctx);

    /* Set ready flag */
    atomic_store(&ready, true);

    /* Wait for the sync thread to clear the flag; then target is ours */
    WAIT_UNTIL(atomic_load(&ready) == false, 5000);
    TEST_ASSERT(atomic_load(&ready) == false, "ready flag should be cleared");
    TEST_ASSERT(target == source, "target should point to source");

    /* Stop and join */
    tp_sync_stop(ctx);
    pthread_join(thread, NULL);

    tp_sync_destroy(ctx);
    TEST_PASS("test_sync_pointer_swap");
    return 0;
}
/* }}} */

/* {{{ test_sync_multiple_watches */
static int test_sync_multiple_watches(void) {
    /* Test: multiple watch entries work correctly */
    TpSyncConfig cfg = tp_sync_config_default();
    TpSyncContext* ctx = tp_sync_create(&cfg);
    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");

    #define NUM_WATCHES 10
    atomic_bool ready[NUM_WATCHES];
    void* targets[NUM_WATCHES];
    void* sources[NUM_WATCHES];

    /* Initialize and add watches */
    for (int i = 0; i < NUM_WATCHES; i++) {
        atomic_init(&ready[i], false);
        targets[i] = NULL;
        sources[i] = (void*)(uintptr_t)(0x1000 + i);
        tp_sync_add_watch(ctx, &ready[i], &targets[i], sources[i]);
    }

    /* Spawn sync thread */
    pthread_t thread = tp_sync_spawn(ctx);

    /* Set ready flags in sequence */
    for (int i = 0; i < NUM_WATCHES; i++) {
        atomic_store(&ready[i], true);
        usleep(1000);  /* 1ms */
    }

    /* Wait for all swaps, then verify each flag cleared and target swapped */
    WAIT_UNTIL(tp_sync_get_swaps(ctx) == NUM_WATCHES, 5000);
    for (int i = 0; i < NUM_WATCHES; i++) {
        TEST_ASSERT(atomic_load(&ready[i]) == false, "all ready flags should be cleared");
        TEST_ASSERT(targets[i] == sources[i], "all targets should be swapped");
    }

    /* Check statistics */
    uint64_t swaps = tp_sync_get_swaps(ctx);
    TEST_ASSERT(swaps == NUM_WATCHES, "should have performed NUM_WATCHES swaps");

    /* Stop and join */
    tp_sync_stop(ctx);
    pthread_join(thread, NULL);

    tp_sync_destroy(ctx);
    TEST_PASS("test_sync_multiple_watches");
    return 0;
}
/* }}} */

/* {{{ test_sync_watch_list_full */
static int test_sync_watch_list_full(void) {
    /* Test: add_watch fails when list is full */
    TpSyncConfig cfg = tp_sync_config_default();
    cfg.watch_list_size = 2;  /* Small list */

    TpSyncContext* ctx = tp_sync_create(&cfg);
    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");

    atomic_bool ready1 = false, ready2 = false, ready3 = false;
    void* target1 = NULL, *target2 = NULL, *target3 = NULL;
    void* source = (void*)0x1234;

    /* First two should succeed */
    TEST_ASSERT(tp_sync_add_watch(ctx, &ready1, &target1, source), "first add should succeed");
    TEST_ASSERT(tp_sync_add_watch(ctx, &ready2, &target2, source), "second add should succeed");

    /* Third should fail */
    TEST_ASSERT(!tp_sync_add_watch(ctx, &ready3, &target3, source), "third add should fail (full)");

    tp_sync_destroy(ctx);
    TEST_PASS("test_sync_watch_list_full");
    return 0;
}
/* }}} */

/* {{{ test_sync_statistics */
static int test_sync_statistics(void) {
    /* Test: statistics are tracked correctly */
    TpSyncConfig cfg = tp_sync_config_default();
    TpSyncContext* ctx = tp_sync_create(&cfg);
    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");

    /* Initial stats should be zero */
    TEST_ASSERT(tp_sync_get_swaps(ctx) == 0, "initial swaps should be 0");
    TEST_ASSERT(tp_sync_get_idle_cycles(ctx) == 0, "initial idle_cycles should be 0");

    pthread_t thread = tp_sync_spawn(ctx);

    /* Let it idle for a bit */
    WAIT_UNTIL(tp_sync_get_idle_cycles(ctx) > 0, 5000);

    /* Idle cycles should have increased */
    uint64_t idle = tp_sync_get_idle_cycles(ctx);
    TEST_ASSERT(idle > 0, "idle_cycles should be non-zero");

    tp_sync_stop(ctx);
    pthread_join(thread, NULL);
    tp_sync_destroy(ctx);

    TEST_PASS("test_sync_statistics");
    return 0;
}
/* }}} */

/* {{{ test_sync_null_config_and_logging */
static int test_sync_null_config_and_logging(void) {
    /* Test: NULL config means defaults; a log callback receives the module's
     * messages (the module itself prints nothing) */
    TpSyncContext* ctx = tp_sync_create(NULL);
    TEST_ASSERT(ctx != NULL, "NULL config should give a default context");
    TEST_ASSERT(ctx->watch_capacity == 2048, "default capacity should be 2048");
    tp_sync_destroy(ctx);

    atomic_store(&g_log_calls, 0);
    TpSyncConfig cfg = tp_sync_config_default();
    cfg.log_fn = test_logger;
    ctx = tp_sync_create(&cfg);
    TEST_ASSERT(ctx != NULL, "sync context should not be NULL");
    pthread_t thread = tp_sync_spawn(ctx);
    tp_sync_stop(ctx);
    pthread_join(thread, NULL);
    tp_sync_destroy(ctx);
    TEST_ASSERT(atomic_load(&g_log_calls) >= 3, "create, spawn and exit should log");

    TEST_PASS("test_sync_null_config_and_logging");
    return 0;
}
/* }}} */

/* {{{ Handoff state
 * A producer thread publishes a new frame through the watch list over and
 * over; the consumer reads each one after seeing the flag clear. */
#define HANDOFF_ROUNDS 200
typedef struct handoff {
    TpSyncContext* ctx;
    atomic_bool ready;
    void* front;
    int frames[HANDOFF_ROUNDS];
} Handoff;
/* }}} */

/* {{{ test_sync_repeated_handoff */
static int test_sync_repeated_handoff(void) {
    /* Test: many handoffs in a row each deliver exactly the new pointer */
    Handoff h;
    h.ctx = tp_sync_create(NULL);
    TEST_ASSERT(h.ctx != NULL, "sync context should not be NULL");
    atomic_init(&h.ready, false);
    h.front = NULL;

    pthread_t thread = tp_sync_spawn(h.ctx);
    for (int i = 0; i < HANDOFF_ROUNDS; i++) {
        h.frames[i] = i;
        TEST_ASSERT(tp_sync_add_watch(h.ctx, &h.ready, &h.front, &h.frames[i]),
                    "add_watch should succeed");
        atomic_store(&h.ready, true);
        WAIT_UNTIL(atomic_load(&h.ready) == false, 5000);
        TEST_ASSERT(atomic_load(&h.ready) == false, "flag should clear");
        TEST_ASSERT(h.front == &h.frames[i], "front should be the newest frame");
    }
    TEST_ASSERT(tp_sync_get_swaps(h.ctx) == HANDOFF_ROUNDS, "every round should swap once");

    tp_sync_stop(h.ctx);
    pthread_join(thread, NULL);
    tp_sync_destroy(h.ctx);
    TEST_PASS("test_sync_repeated_handoff");
    return 0;
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== Threadpool Sync Tests ===\n\n");

    int failures = 0;

    failures += test_sync_create_destroy();
    failures += test_sync_add_watch();
    failures += test_sync_pointer_swap();
    failures += test_sync_multiple_watches();
    failures += test_sync_watch_list_full();
    failures += test_sync_statistics();
    failures += test_sync_null_config_and_logging();
    failures += test_sync_repeated_handoff();

    printf("\n");
    if (failures == 0) {
        printf("All tests passed!\n");
        return 0;
    } else {
        printf("%d test(s) failed.\n", failures);
        return 1;
    }
}
/* }}} */
