/*
 * Test: Updater Module (Self-Evaluating Task Distribution)
 *
 * Verifies updater creation, task distribution, user data, stopping and
 * restarting, helper spawning and exit, and that the caller's context is
 * never freed by the library.
 */

#include "../src/threadpool.h"
#include "../src/threadpool_updater.h"
#include "test_common.h"
#include <stdlib.h>

/* {{{ Test State */
static atomic_int g_tasks_executed = 0;
static atomic_int g_callback_count = 0;

/* Mock task list for testing. The count is atomic because the updater reads
 * it on a worker while the test changes it. */
#define MAX_MOCK_TASKS 20
static TpTask g_mock_tasks[MAX_MOCK_TASKS];
static atomic_size_t g_mock_task_count = 0;

static int g_test_value = 42;
static atomic_int g_received_value = 0;
/* }}} */

/* {{{ mock_task_execute */
static void mock_task_execute(void* context) {
    (void)context;
    atomic_fetch_add(&g_tasks_executed, 1);
    /* Brief work */
    for (volatile int i = 0; i < 1000; i++) {}
}
/* }}} */

/* {{{ set_mock_tasks
 * Fills the mock list with n light tasks that run once. */
static void set_mock_tasks(size_t n) {
    for (size_t i = 0; i < n; i++) {
        g_mock_tasks[i].execute = mock_task_execute;
        g_mock_tasks[i].on_complete = NULL;
        g_mock_tasks[i].context = NULL;
        g_mock_tasks[i].weight = TP_WEIGHT_LIGHT;
        g_mock_tasks[i].repeat_count = 1;
    }
    atomic_store(&g_mock_task_count, n);
}
/* }}} */

/* {{{ get_pending_tasks_simple
 * Simple callback that returns a fixed set of tasks */
static bool get_pending_tasks_simple(void* user_data, TpTask** out, size_t* count) {
    (void)user_data;
    atomic_fetch_add(&g_callback_count, 1);

    size_t n = atomic_load(&g_mock_task_count);
    if (n == 0) {
        *out = NULL;
        *count = 0;
        return false;
    }

    *out = g_mock_tasks;
    *count = n;
    return true;
}
/* }}} */

/* {{{ get_pending_tasks_once
 * Hands out the mock list once, then nothing. */
static bool get_pending_tasks_once(void* user_data, TpTask** out, size_t* count) {
    (void)user_data;
    atomic_fetch_add(&g_callback_count, 1);

    size_t n = atomic_exchange(&g_mock_task_count, 0);
    *out = n ? g_mock_tasks : NULL;
    *count = n;
    return n > 0;
}
/* }}} */

/* {{{ callback_with_data
 * Records the user_data it is handed. */
static bool callback_with_data(void* user_data, TpTask** out, size_t* count) {
    if (user_data) {
        atomic_store(&g_received_value, *(int*)user_data);
    }
    *out = NULL;
    *count = 0;
    return false;
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
    TEST_ASSERT(tp_updater_create(NULL, &cfg, get_pending_tasks_simple, NULL) == NULL,
                "NULL pool should be refused");
    TEST_ASSERT(tp_updater_create(pool, &cfg, NULL, NULL) == NULL,
                "NULL task source should be refused");

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
    atomic_store(&g_mock_task_count, 0);
    unsigned int before = tp_updater_get_active_count();

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterContext* ctx = tp_updater_create(pool, NULL, get_pending_tasks_simple, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");

    TEST_ASSERT(tp_updater_start(ctx), "start should succeed");
    TEST_ASSERT(!tp_updater_start(ctx), "a second start while running should be refused");

    WAIT_UNTIL(atomic_load(&g_callback_count) > 0, 5000);
    TEST_ASSERT(atomic_load(&g_callback_count) > 0, "callback should have been invoked");
    TEST_ASSERT(tp_updater_get_active_count() == before + 1, "one more updater should be active");

    /* Destroying the pool first stops the updater; then the context, which
     * belongs to the caller, can be freed */
    tp_pool_destroy(pool);
    tp_updater_destroy(ctx);

    TEST_PASS("test_updater_starts");
    return 0;
}
/* }}} */

/* {{{ test_updater_distributes_tasks */
static int test_updater_distributes_tasks(void) {
    /* Test: updater distributes tasks to workers */
    atomic_store(&g_tasks_executed, 0);
    atomic_store(&g_callback_count, 0);
    set_mock_tasks(5);

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterContext* ctx = tp_updater_create(pool, NULL, get_pending_tasks_once, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");
    tp_updater_start(ctx);

    WAIT_UNTIL(atomic_load(&g_tasks_executed) == 5, 5000);
    TEST_ASSERT(atomic_load(&g_tasks_executed) == 5, "all 5 tasks should have executed once");
    TEST_ASSERT(tp_updater_get_last_tick_us(ctx) < 1000000, "last tick should be readable");

    tp_updater_stop(ctx);
    tp_updater_destroy(ctx);
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
    atomic_store(&g_received_value, 0);

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpUpdaterContext* ctx = tp_updater_create(pool, NULL, callback_with_data, &g_test_value);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");
    tp_updater_start(ctx);

    WAIT_UNTIL(atomic_load(&g_received_value) == 42, 5000);
    TEST_ASSERT(atomic_load(&g_received_value) == 42, "user_data should be passed to callback");

    tp_updater_stop(ctx);
    tp_updater_destroy(ctx);
    tp_pool_destroy(pool);

    TEST_PASS("test_updater_with_user_data");
    return 0;
}
/* }}} */

/* {{{ test_updater_stop_and_restart */
static int test_updater_stop_and_restart(void) {
    /* Test: stop ends the updater while the pool runs on, the count goes back
     * down, no callback happens after stop returns, and it can start again */
    atomic_store(&g_callback_count, 0);
    atomic_store(&g_mock_task_count, 0);
    unsigned int before = tp_updater_get_active_count();

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TpUpdaterContext* ctx = tp_updater_create(pool, NULL, get_pending_tasks_simple, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");

    TEST_ASSERT(tp_updater_start(ctx), "start should succeed");
    WAIT_UNTIL(atomic_load(&g_callback_count) > 0, 5000);

    tp_updater_stop(ctx);
    TEST_ASSERT(tp_updater_get_active_count() == before, "active count should return");
    int after_stop = atomic_load(&g_callback_count);
    tp_sleep_us(20000);
    TEST_ASSERT(atomic_load(&g_callback_count) == after_stop, "no callbacks after stop");
    WAIT_UNTIL(tp_pool_get_load(pool) == 0, 5000);
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "the updater's load should be released");

    TEST_ASSERT(tp_updater_start(ctx), "a stopped updater should start again");
    WAIT_UNTIL(atomic_load(&g_callback_count) > after_stop, 5000);
    TEST_ASSERT(atomic_load(&g_callback_count) > after_stop, "restarted updater should run");
    tp_updater_stop(ctx);

    tp_updater_destroy(ctx);
    tp_pool_destroy(pool);

    TEST_PASS("test_updater_stop_and_restart");
    return 0;
}
/* }}} */

/* {{{ test_updater_helper_exits */
static int test_updater_helper_exits(void) {
    /* Test: a helper distributes its partition, then, finding the load light,
     * exits and frees itself; the active count comes back down */
    atomic_store(&g_tasks_executed, 0);
    set_mock_tasks(10);
    unsigned int before = tp_updater_get_active_count();

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TpUpdaterContext* ctx = tp_updater_create(pool, NULL, get_pending_tasks_simple, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");

    /* The primary is not started: only the helper hands out tasks 4..9 */
    tp_updater_spawn_helper(ctx, 4, 10);
    WAIT_UNTIL(atomic_load(&ctx->live_helpers) == 0, 5000);
    TEST_ASSERT(atomic_load(&ctx->live_helpers) == 0, "helper should exit on light load");
    TEST_ASSERT(tp_updater_get_active_count() == before, "active count should return");

    WAIT_UNTIL(atomic_load(&g_tasks_executed) == 6, 5000);
    TEST_ASSERT(atomic_load(&g_tasks_executed) == 6, "helper should run its partition once");

    atomic_store(&g_mock_task_count, 0);
    tp_updater_destroy(ctx);
    tp_pool_destroy(pool);

    TEST_PASS("test_updater_helper_exits");
    return 0;
}
/* }}} */

/* {{{ slow_source
 * A task source slow enough that helpers always want to continue. */
static bool slow_source(void* user_data, TpTask** out, size_t* count) {
    (void)user_data;
    tp_sleep_us(2000);  /* 2ms, over the 1ms continuation threshold below */
    *out = g_mock_tasks;
    *count = 1;
    return true;
}
/* }}} */

/* {{{ test_updater_stop_waits_for_helpers */
static int test_updater_stop_waits_for_helpers(void) {
    /* Test: helpers that would run forever under load still end on stop, and
     * stop returns only once they are gone */
    set_mock_tasks(1);
    unsigned int before = tp_updater_get_active_count();

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TpUpdaterConfig cfg = tp_updater_config_default();
    cfg.continuation_threshold_us = 1000;
    TpUpdaterContext* ctx = tp_updater_create(pool, &cfg, slow_source, NULL);
    TEST_ASSERT(ctx != NULL, "updater context should not be NULL");

    tp_updater_spawn_helper(ctx, 0, 1);
    tp_updater_spawn_helper(ctx, 0, 1);
    tp_sleep_us(20000);
    TEST_ASSERT(atomic_load(&ctx->live_helpers) == 2, "both helpers should keep going");

    tp_updater_stop(ctx);
    TEST_ASSERT(atomic_load(&ctx->live_helpers) == 0, "stop should wait for helpers");
    TEST_ASSERT(tp_updater_get_active_count() == before, "active count should return");

    tp_updater_destroy(ctx);
    tp_pool_destroy(pool);

    TEST_PASS("test_updater_stop_waits_for_helpers");
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
    failures += test_updater_stop_and_restart();
    failures += test_updater_helper_exits();
    failures += test_updater_stop_waits_for_helpers();

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
