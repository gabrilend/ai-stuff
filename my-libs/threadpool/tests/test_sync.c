/*
 * Test: Sync Module (Watch List)
 *
 * Verifies sync context creation, watch list management, and pointer swapping.
 */

#include "../src/threadpool_sync.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* {{{ Test Macros */
#define TEST_ASSERT(cond, msg) do { \
    if (!(cond)) { \
        fprintf(stderr, "FAIL: %s:%d: %s\n", __FILE__, __LINE__, msg); \
        return 1; \
    } \
} while(0)

#define TEST_PASS(name) printf("PASS: %s\n", name)
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

    /* Wait for swap to occur */
    usleep(10000);  /* 10ms */

    /* Verify swap occurred */
    TEST_ASSERT(target == source, "target should point to source");
    TEST_ASSERT(atomic_load(&ready) == false, "ready flag should be cleared");

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

    /* Wait for all swaps */
    usleep(50000);  /* 50ms */

    /* Verify all swaps occurred */
    for (int i = 0; i < NUM_WATCHES; i++) {
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
    usleep(10000);  /* 10ms */

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
