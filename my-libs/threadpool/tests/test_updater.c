/*
 * Test: Updater Module (Self-Evaluating Task Distribution)
 *
 * Verifies updater creation, task distribution, and self-evaluation behavior.
 */

#include "../src/threadpool.h"
#include "../src/threadpool_updater.h"
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

/* {{{ Test State */
static atomic_int g_tasks_executed = 0;
static atomic_int g_callback_count = 0;

/* Mock task list for testing */
#define MAX_MOCK_TASKS 20
static TpTask g_mock_tasks[MAX_MOCK_TASKS];
static size_t g_mock_task_count = 0;
/* }}} */

/* {{{ mock_task_execute */
static void mock_task_execute(void* context) {
    (void)context;
    atomic_fetch_add(&g_tasks_executed, 1);
    /* Brief work */
    for (volatile int i = 0; i < 1000; i++) {}
}
/* }}} */

/* {{{ get_pending_tasks_simple
 * Simple callback that returns a fixed set of tasks */
static bool get_pending_tasks_simple(void* user_data, TpTask** out, size_t* count) {
    (void)user_data;
    atomic_fetch_add(&g_callback_count, 1);

    if (g_mock_task_count == 0) {
        *out = NULL;
        *count = 0;
        return false;
    }

    *out = g_mock_tasks;
    *count = g_mock_task_count;
    return true;
}
/* }}} */

/* {{{ test_updater_create_destroy */
static int test_updater_create_destroy(void) {
    /* Test: updater creates and destroys cleanly */
    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterConfig cfg = tp_updater_config_default();
    TpUpdaterContext* ctx = tp_updater_create(pool, &cfg, get_pending_tasks_simple, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");

    tp_updater_destroy(ctx);
    tp_pool_destroy(pool);

    TEST_PASS("test_updater_create_destroy");
    return 0;
}
/* }}} */

/* {{{ test_updater_starts */
static int test_updater_starts(void) {
    /* Test: updater starts and runs */
    atomic_store(&g_callback_count, 0);

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterConfig cfg = tp_updater_config_default();
    TpUpdaterContext* ctx = tp_updater_create(pool, &cfg, get_pending_tasks_simple, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");

    /* Start updater */
    tp_updater_start(ctx);

    /* Wait for it to run a few times */
    usleep(50000);  /* 50ms */

    /* Verify callback was invoked */
    int callbacks = atomic_load(&g_callback_count);
    TEST_ASSERT(callbacks > 0, "callback should have been invoked");

    /* Verify active count */
    unsigned int active = tp_updater_get_active_count();
    TEST_ASSERT(active >= 1, "at least one updater should be active");

    /* Cleanup - stop pool which will terminate updater */
    tp_pool_destroy(pool);

    /* Note: We don't destroy ctx here because the updater task owns it
     * and will free it when the task completes */

    TEST_PASS("test_updater_starts");
    return 0;
}
/* }}} */

/* {{{ test_updater_distributes_tasks */
static int test_updater_distributes_tasks(void) {
    /* Test: updater distributes tasks to workers */
    atomic_store(&g_tasks_executed, 0);
    atomic_store(&g_callback_count, 0);

    /* Setup mock tasks */
    g_mock_task_count = 5;
    for (size_t i = 0; i < g_mock_task_count; i++) {
        g_mock_tasks[i].execute = mock_task_execute;
        g_mock_tasks[i].on_complete = NULL;
        g_mock_tasks[i].context = NULL;
        g_mock_tasks[i].weight = TP_WEIGHT_LIGHT;
        g_mock_tasks[i].repeat_count = 1;
    }

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterConfig cfg = tp_updater_config_default();
    TpUpdaterContext* ctx = tp_updater_create(pool, &cfg, get_pending_tasks_simple, NULL);

    /* Start updater */
    tp_updater_start(ctx);

    /* Wait a bit for first callback */
    usleep(10000);  /* 10ms */

    /* Clear mock tasks so updater stops distributing them */
    g_mock_task_count = 0;

    /* Wait for tasks to execute */
    usleep(50000);  /* 50ms */

    /* Verify tasks were executed (at least once) */
    int executed = atomic_load(&g_tasks_executed);
    TEST_ASSERT(executed >= 5, "all 5 tasks should have executed at least once");

    tp_pool_destroy(pool);

    TEST_PASS("test_updater_distributes_tasks");
    return 0;
}
/* }}} */

/* {{{ test_updater_configuration */
static int test_updater_configuration(void) {
    /* Test: updater respects custom configuration */
    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterConfig cfg = tp_updater_config_default();
    cfg.target_tick_us = 20000;  /* 20ms */
    cfg.continuation_threshold_us = 10000;  /* 10ms */
    cfg.overload_threshold_us = 15000;  /* 15ms */

    TpUpdaterContext* ctx = tp_updater_create(pool, &cfg, get_pending_tasks_simple, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");
    TEST_ASSERT(ctx->config.target_tick_us == 20000, "target_tick_us should be set");
    TEST_ASSERT(ctx->config.continuation_threshold_us == 10000, "continuation_threshold_us should be set");
    TEST_ASSERT(ctx->config.overload_threshold_us == 15000, "overload_threshold_us should be set");

    tp_updater_destroy(ctx);
    tp_pool_destroy(pool);

    TEST_PASS("test_updater_configuration");
    return 0;
}
/* }}} */

/* {{{ test_updater_with_user_data */
static int test_updater_with_user_data(void) {
    /* Test: user_data is passed to callback */
    static int test_value = 42;
    static int received_value = 0;

    /* Callback that checks user_data */
    bool callback_with_data(void* user_data, TpTask** out, size_t* count) {
        if (user_data) {
            received_value = *(int*)user_data;
        }
        *out = NULL;
        *count = 0;
        return false;
    }

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterConfig cfg = tp_updater_config_default();
    TpUpdaterContext* ctx = tp_updater_create(pool, &cfg, callback_with_data, &test_value);

    /* Start updater */
    tp_updater_start(ctx);

    /* Wait for callback */
    usleep(50000);  /* 50ms */

    /* Verify user_data was received */
    TEST_ASSERT(received_value == 42, "user_data should be passed to callback");

    tp_pool_destroy(pool);

    TEST_PASS("test_updater_with_user_data");
    return 0;
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== Threadpool Updater Tests ===\n\n");

    int failures = 0;

    failures += test_updater_create_destroy();
    failures += test_updater_starts();
    failures += test_updater_distributes_tasks();
    failures += test_updater_configuration();
    failures += test_updater_with_user_data();

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
