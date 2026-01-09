/*
 * Test: Scheduler Module (Deferred Task Assignment)
 *
 * Verifies scheduler creation, task scheduling with absolute tick times,
 * and integration with updater pattern.
 */

#include "../src/threadpool.h"
#include "../src/threadpool_scheduler.h"
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

/* {{{ Global tick counter
 * Required by scheduler module - must be defined by user application */
_Atomic uint64_t g_current_tick = 0;
/* }}} */

/* {{{ Test State */
static atomic_int g_tasks_executed = 0;
/* }}} */

/* {{{ mock_task_execute */
static void mock_task_execute(void* context) {
    (void)context;
    atomic_fetch_add(&g_tasks_executed, 1);
}
/* }}} */

/* {{{ test_scheduler_create_destroy */
static int test_scheduler_create_destroy(void) {
    /* Test: scheduler creates and destroys cleanly */
    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);

    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");
    TEST_ASSERT(tp_scheduler_count(sched) == 0, "initial count should be 0");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_create_destroy");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_add_immediate */
static int test_scheduler_add_immediate(void) {
    /* Test: scheduler_add with delay 0 sets ready_at_tick = g_current_tick */
    atomic_store(&g_current_tick, 100);

    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    TpTask task = {
        .execute = mock_task_execute,
        .on_complete = NULL,
        .context = NULL,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };

    bool result = tp_scheduler_add(sched, &task, 0);
    TEST_ASSERT(result == true, "add should succeed");
    TEST_ASSERT(tp_scheduler_count(sched) == 1, "count should be 1");

    /* Task should be ready immediately since current tick >= ready_at_tick */
    TpTask* ready_tasks = NULL;
    size_t ready_count = 0;
    bool has_ready = tp_scheduler_get_ready(sched, &ready_tasks, &ready_count);
    TEST_ASSERT(has_ready == true, "should have ready tasks");
    TEST_ASSERT(ready_count == 1, "should have 1 ready task");
    TEST_ASSERT(tp_scheduler_count(sched) == 0, "tasks should be removed after get_ready");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_add_immediate");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_add_delayed */
static int test_scheduler_add_delayed(void) {
    /* Test: scheduler_add with delay N sets ready_at_tick = g_current_tick + N */
    atomic_store(&g_current_tick, 100);

    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    TpTask task = {
        .execute = mock_task_execute,
        .on_complete = NULL,
        .context = NULL,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };

    /* Add task with 50 tick delay */
    bool result = tp_scheduler_add(sched, &task, 50);
    TEST_ASSERT(result == true, "add should succeed");

    /* Should not be ready yet */
    TpTask* ready_tasks = NULL;
    size_t ready_count = 0;
    bool has_ready = tp_scheduler_get_ready(sched, &ready_tasks, &ready_count);
    TEST_ASSERT(has_ready == false, "should not have ready tasks yet");
    TEST_ASSERT(tp_scheduler_count(sched) == 1, "task should still be in scheduler");

    /* Advance tick to ready time */
    atomic_store(&g_current_tick, 150);

    /* Now should be ready */
    has_ready = tp_scheduler_get_ready(sched, &ready_tasks, &ready_count);
    TEST_ASSERT(has_ready == true, "should have ready tasks now");
    TEST_ASSERT(ready_count == 1, "should have 1 ready task");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_add_delayed");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_multiple_tasks */
static int test_scheduler_multiple_tasks(void) {
    /* Test: multiple tasks with different ready times */
    atomic_store(&g_current_tick, 0);

    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    TpTask task1 = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask task2 = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask task3 = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    /* Add tasks with different delays */
    tp_scheduler_add(sched, &task1, 0);   /* Ready at tick 0 */
    tp_scheduler_add(sched, &task2, 10);  /* Ready at tick 10 */
    tp_scheduler_add(sched, &task3, 20);  /* Ready at tick 20 */

    TEST_ASSERT(tp_scheduler_count(sched) == 3, "should have 3 tasks");

    /* At tick 0, only task1 should be ready */
    TpTask* ready_tasks = NULL;
    size_t ready_count = 0;
    tp_scheduler_get_ready(sched, &ready_tasks, &ready_count);
    TEST_ASSERT(ready_count == 1, "should have 1 ready task at tick 0");
    TEST_ASSERT(tp_scheduler_count(sched) == 2, "should have 2 remaining tasks");

    /* At tick 10, task2 should be ready */
    atomic_store(&g_current_tick, 10);
    tp_scheduler_get_ready(sched, &ready_tasks, &ready_count);
    TEST_ASSERT(ready_count == 1, "should have 1 ready task at tick 10");
    TEST_ASSERT(tp_scheduler_count(sched) == 1, "should have 1 remaining task");

    /* At tick 20, task3 should be ready */
    atomic_store(&g_current_tick, 20);
    tp_scheduler_get_ready(sched, &ready_tasks, &ready_count);
    TEST_ASSERT(ready_count == 1, "should have 1 ready task at tick 20");
    TEST_ASSERT(tp_scheduler_count(sched) == 0, "should have 0 remaining tasks");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_multiple_tasks");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_earliest_ready_tick */
static int test_scheduler_earliest_ready_tick(void) {
    /* Test: earliest_ready_tick returns correct value */
    atomic_store(&g_current_tick, 0);

    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    /* Empty scheduler should return UINT64_MAX */
    uint64_t earliest = tp_scheduler_earliest_ready_tick(sched);
    TEST_ASSERT(earliest == UINT64_MAX, "empty scheduler should return UINT64_MAX");

    TpTask task1 = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask task2 = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    /* Add tasks */
    tp_scheduler_add(sched, &task1, 50);   /* Ready at tick 50 */
    tp_scheduler_add(sched, &task2, 100);  /* Ready at tick 100 */

    /* Earliest should be 50 */
    earliest = tp_scheduler_earliest_ready_tick(sched);
    TEST_ASSERT(earliest == 50, "earliest should be 50");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_earliest_ready_tick");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_remove_if */
static int test_scheduler_remove_if(void) {
    /* Test: remove_if removes matching tasks */
    atomic_store(&g_current_tick, 0);

    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    /* Create tasks with different contexts to identify them */
    TpTask task1 = { .execute = mock_task_execute, .context = (void*)1, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask task2 = { .execute = mock_task_execute, .context = (void*)2, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask task3 = { .execute = mock_task_execute, .context = (void*)3, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    tp_scheduler_add(sched, &task1, 10);
    tp_scheduler_add(sched, &task2, 20);
    tp_scheduler_add(sched, &task3, 30);

    TEST_ASSERT(tp_scheduler_count(sched) == 3, "should have 3 tasks");

    /* Remove tasks with context == (void*)2 */
    bool predicate(TpTask* task, void* user_data) {
        return task->context == user_data;
    }

    tp_scheduler_remove_if(sched, predicate, (void*)2);

    TEST_ASSERT(tp_scheduler_count(sched) == 2, "should have 2 tasks after removal");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_remove_if");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_full */
static int test_scheduler_full(void) {
    /* Test: scheduler_add fails when full */
    atomic_store(&g_current_tick, 0);

    TpSchedulerConfig cfg = tp_scheduler_config_default();
    cfg.capacity = 2;  /* Small capacity */

    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    TpTask task = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    /* First two should succeed */
    TEST_ASSERT(tp_scheduler_add(sched, &task, 10), "first add should succeed");
    TEST_ASSERT(tp_scheduler_add(sched, &task, 20), "second add should succeed");

    /* Third should fail */
    TEST_ASSERT(!tp_scheduler_add(sched, &task, 30), "third add should fail (full)");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_full");
    return 0;
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== Threadpool Scheduler Tests ===\n\n");

    int failures = 0;

    failures += test_scheduler_create_destroy();
    failures += test_scheduler_add_immediate();
    failures += test_scheduler_add_delayed();
    failures += test_scheduler_multiple_tasks();
    failures += test_scheduler_earliest_ready_tick();
    failures += test_scheduler_remove_if();
    failures += test_scheduler_full();

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
