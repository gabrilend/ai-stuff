/*
 * Test: Core Pool Functionality
 *
 * Verifies basic pool creation, task execution, and destruction.
 */

#include "../src/threadpool.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
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
static atomic_int g_task_counter = 0;
static atomic_int g_complete_counter = 0;
/* }}} */

/* {{{ test_task_execute */
static void test_task_execute(void* context) {
    (void)context;
    atomic_fetch_add(&g_task_counter, 1);
    /* Brief work simulation */
    for (volatile int i = 0; i < 1000; i++) {}
}
/* }}} */

/* {{{ test_task_on_complete */
static void test_task_on_complete(void* context) {
    (void)context;
    atomic_fetch_add(&g_complete_counter, 1);
}
/* }}} */

/* {{{ test_logger */
static void test_logger(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    printf("[LOG] ");
    vprintf(fmt, args);
    va_end(args);
}
/* }}} */

/* {{{ test_pool_create_defaults */
static int test_pool_create_defaults(void) {
    /* Test: pool creates with NULL config and 0 workers (auto-detect) */
    TpPool* pool = tp_pool_create(NULL, 0);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TEST_ASSERT(pool->count > 0, "pool should have workers");
    TEST_ASSERT(pool->workers != NULL, "workers array should exist");

    tp_pool_destroy(pool);
    TEST_PASS("test_pool_create_defaults");
    return 0;
}
/* }}} */

/* {{{ test_pool_create_specific_count */
static int test_pool_create_specific_count(void) {
    /* Test: pool creates with specific worker count */
    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TEST_ASSERT(pool->count == 2, "pool should have 2 workers");

    tp_pool_destroy(pool);
    TEST_PASS("test_pool_create_specific_count");
    return 0;
}
/* }}} */

/* {{{ test_pool_with_logging */
static int test_pool_with_logging(void) {
    /* Test: pool creates with custom logging */
    TpConfig cfg = tp_config_default();
    cfg.log_fn = test_logger;

    TpPool* pool = tp_pool_create(&cfg, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TEST_ASSERT(pool->config.log_fn == test_logger, "log_fn should be set");

    tp_pool_destroy(pool);
    TEST_PASS("test_pool_with_logging");
    return 0;
}
/* }}} */

/* {{{ test_task_execution */
static int test_task_execution(void) {
    /* Test: tasks execute correctly */
    atomic_store(&g_task_counter, 0);
    atomic_store(&g_complete_counter, 0);

    TpPool* pool = tp_pool_create(NULL, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    /* Append several tasks */
    for (int i = 0; i < 10; i++) {
        TpTask task = {
            .execute = test_task_execute,
            .on_complete = test_task_on_complete,
            .context = NULL,
            .weight = TP_WEIGHT_LIGHT,
            .repeat_count = 1
        };

        TpWorker* w = tp_find_least_busy(pool);
        TEST_ASSERT(w != NULL, "should find a worker");
        TEST_ASSERT(tp_task_append(w, &task), "task append should succeed");
    }

    /* Wait for tasks to complete */
    usleep(100000);  /* 100ms */

    int executed = atomic_load(&g_task_counter);
    int completed = atomic_load(&g_complete_counter);

    TEST_ASSERT(executed == 10, "all tasks should have executed");
    TEST_ASSERT(completed == 10, "all on_complete should have been called");

    tp_pool_destroy(pool);
    TEST_PASS("test_task_execution");
    return 0;
}
/* }}} */

/* {{{ test_load_balancing */
static int test_load_balancing(void) {
    /* Test: load balancing distributes tasks */
    TpPool* pool = tp_pool_create(NULL, 4);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    /* Initially all workers should have zero load */
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "initial load should be 0");

    /* Add tasks with different weights */
    TpTask heavy = {
        .execute = test_task_execute,
        .on_complete = NULL,
        .context = NULL,
        .weight = TP_WEIGHT_HEAVY,
        .repeat_count = 100  /* Keep running for a while */
    };

    /* Add heavy task to first worker */
    tp_task_append(&pool->workers[0], &heavy);

    /* Now find_least_busy should NOT return worker 0 */
    TpWorker* least = tp_find_least_busy(pool);
    TEST_ASSERT(least != NULL, "should find a worker");
    TEST_ASSERT(least->worker_id != 0, "least busy should not be worker 0");

    /* find_least_busy_excluding should work */
    TpWorker* excluded = tp_find_least_busy_excluding(pool, 1);
    TEST_ASSERT(excluded != NULL, "should find worker excluding 1");
    TEST_ASSERT(excluded->worker_id != 1, "should not return excluded worker");

    tp_pool_destroy(pool);
    TEST_PASS("test_load_balancing");
    return 0;
}
/* }}} */

/* {{{ test_repeat_count */
static int test_repeat_count(void) {
    /* Test: repeat_count causes multiple executions */
    atomic_store(&g_task_counter, 0);

    TpPool* pool = tp_pool_create(NULL, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpTask task = {
        .execute = test_task_execute,
        .on_complete = NULL,
        .context = NULL,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 5  /* Run 5 times */
    };

    tp_task_append(&pool->workers[0], &task);

    /* Wait for task to complete */
    usleep(50000);  /* 50ms */

    int executed = atomic_load(&g_task_counter);
    TEST_ASSERT(executed == 5, "task should have executed 5 times");

    tp_pool_destroy(pool);
    TEST_PASS("test_repeat_count");
    return 0;
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== Threadpool Core Tests ===\n\n");

    int failures = 0;

    failures += test_pool_create_defaults();
    failures += test_pool_create_specific_count();
    failures += test_pool_with_logging();
    failures += test_task_execution();
    failures += test_load_balancing();
    failures += test_repeat_count();

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
