/*
 * Test: Scheduler Module (Deferred Task Assignment)
 *
 * Verifies scheduler creation, task scheduling with absolute tick times,
 * interruptible sleeping, per-scheduler ready buffers, and integration with
 * the updater pattern.
 */

#include "../src/threadpool.h"
#include "../src/threadpool_scheduler.h"
#include "../src/threadpool_updater.h"
#include "test_common.h"
#include <stdlib.h>

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

/* {{{ context_matches
 * remove_if predicate: true for tasks whose context is user_data. */
static bool context_matches(TpTask* task, void* user_data) {
    return task->context == user_data;
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
    tp_scheduler_remove_if(sched, context_matches, (void*)2);

    TEST_ASSERT(tp_scheduler_count(sched) == 2, "should have 2 tasks after removal");
    TEST_ASSERT(tp_scheduler_earliest_ready_tick(sched) == 10, "task 1 should remain");
    atomic_store(&g_current_tick, 30);
    TpTask* ready = NULL;
    size_t n = 0;
    tp_scheduler_get_ready(sched, &ready, &n);
    TEST_ASSERT(n == 2, "two tasks should come out");
    TEST_ASSERT(ready[0].context == (void*)1 && ready[1].context == (void*)3,
                "the kept tasks should be 1 and 3, in order");

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

/* {{{ test_scheduler_null_config */
static int test_scheduler_null_config(void) {
    /* Test: NULL config means defaults */
    TpScheduler* sched = tp_scheduler_create(NULL);
    TEST_ASSERT(sched != NULL, "NULL config should give a default scheduler");
    TEST_ASSERT(sched->capacity == 1024, "default capacity should be 1024");
    TEST_ASSERT(sched->tick_us == 16000, "default tick should be 16ms");
    tp_scheduler_destroy(sched);

    TEST_PASS("test_scheduler_null_config");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_sleep_ticks_sleeps */
static int test_scheduler_sleep_ticks_sleeps(void) {
    /* Test: sleep_ticks really sleeps about ticks * tick_us when nothing
     * wakes it (it used to return at once: the timeout was measured on the
     * monotonic clock but waited for on the wall clock) */
    atomic_store(&g_current_tick, 0);
    TpSchedulerConfig cfg = tp_scheduler_config_default();
    cfg.tick_us = 2000;  /* 2ms ticks */
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    uint64_t start = test_now_ms();
    tp_scheduler_sleep_ticks(sched, 25);  /* 50ms */
    uint64_t took = test_now_ms() - start;
    TEST_ASSERT(took >= 45, "sleep should last about 50ms");
    TEST_ASSERT(took < 2000, "sleep should not last far longer than asked");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_sleep_ticks_sleeps");
    return 0;
}
/* }}} */

/* {{{ Sleeper thread
 * Sleeps a long time on a scheduler and records how long it took. */
typedef struct sleeper {
    TpScheduler* sched;
    uint64_t ticks;
    _Atomic uint64_t took_ms;
    atomic_bool done;
} Sleeper;

static void* sleeper_thread(void* arg) {
    Sleeper* s = (Sleeper*)arg;
    uint64_t start = test_now_ms();
    tp_scheduler_sleep_ticks(s->sched, s->ticks);
    atomic_store(&s->took_ms, test_now_ms() - start);
    atomic_store(&s->done, true);
    return NULL;
}
/* }}} */

/* {{{ test_scheduler_sleep_wakes_on_add */
static int test_scheduler_sleep_wakes_on_add(void) {
    /* Test: adding a task ends a long sleep early */
    atomic_store(&g_current_tick, 0);
    TpSchedulerConfig cfg = tp_scheduler_config_default();
    cfg.tick_us = 1000;  /* 1ms ticks */
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    Sleeper s = { .sched = sched, .ticks = 10000 };  /* 10 seconds */
    atomic_init(&s.took_ms, 0);
    atomic_init(&s.done, false);
    tp_thread_t thread;
    tp_thread_create(&thread, sleeper_thread, &s);

    tp_sleep_us(30000);
    TEST_ASSERT(!atomic_load(&s.done), "sleeper should still be asleep");
    TpTask task = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    tp_scheduler_add(sched, &task, 500);

    tp_thread_join(thread);
    TEST_ASSERT(atomic_load(&s.took_ms) < 5000, "an add should wake the sleeper early");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_sleep_wakes_on_add");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_sleep_respects_earliest */
static int test_scheduler_sleep_respects_earliest(void) {
    /* Test: sleep returns at once when a task is ready, and never sleeps past
     * the earliest scheduled task even when asked to */
    atomic_store(&g_current_tick, 100);
    TpSchedulerConfig cfg = tp_scheduler_config_default();
    cfg.tick_us = 2000;  /* 2ms ticks */
    TpScheduler* sched = tp_scheduler_create(&cfg);
    TEST_ASSERT(sched != NULL, "scheduler should not be NULL");

    TpTask task = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    tp_scheduler_add(sched, &task, 5);  /* ready at 105, 10ms away */
    uint64_t start = test_now_ms();
    tp_scheduler_sleep_ticks(sched, 5000);  /* asked for 10 seconds */
    TEST_ASSERT(test_now_ms() - start < 2000, "sleep should stop at the earliest task");

    atomic_store(&g_current_tick, 105);
    start = test_now_ms();
    tp_scheduler_sleep_ticks(sched, 5000);
    TEST_ASSERT(test_now_ms() - start < 1000, "a ready task should end sleep at once");

    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_sleep_respects_earliest");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_buffers_independent */
static int test_scheduler_buffers_independent(void) {
    /* Test: two schedulers each keep their own ready buffer (they used to
     * share one, so the second call overwrote the first one's tasks) */
    atomic_store(&g_current_tick, 0);
    TpScheduler* a = tp_scheduler_create(NULL);
    TpScheduler* b = tp_scheduler_create(NULL);
    TEST_ASSERT(a != NULL && b != NULL, "schedulers should not be NULL");

    TpTask ta = { .execute = mock_task_execute, .context = (void*)0xA, .repeat_count = 1 };
    TpTask tb = { .execute = mock_task_execute, .context = (void*)0xB, .repeat_count = 1 };
    tp_scheduler_add(a, &ta, 0);
    tp_scheduler_add(b, &tb, 0);

    TpTask* out_a = NULL;
    TpTask* out_b = NULL;
    size_t na = 0, nb = 0;
    tp_scheduler_get_ready(a, &out_a, &na);
    tp_scheduler_get_ready(b, &out_b, &nb);
    TEST_ASSERT(na == 1 && nb == 1, "each scheduler should hand out its task");
    TEST_ASSERT(out_a != out_b, "buffers should differ");
    TEST_ASSERT(out_a[0].context == (void*)0xA, "a's task should still be a's");
    TEST_ASSERT(out_b[0].context == (void*)0xB, "b's task should be b's");

    tp_scheduler_destroy(a);
    tp_scheduler_destroy(b);
    TEST_PASS("test_scheduler_buffers_independent");
    return 0;
}
/* }}} */

/* {{{ test_scheduler_with_updater */
static int test_scheduler_with_updater(void) {
    /* Test: an updater fed by a scheduler runs each task once, when its tick
     * comes and not before */
    atomic_store(&g_current_tick, 0);
    atomic_store(&g_tasks_executed, 0);

    TpPool* pool = tp_pool_create(NULL, 2);
    TpScheduler* sched = tp_scheduler_create(NULL);
    TEST_ASSERT(pool != NULL && sched != NULL, "pool and scheduler should exist");
    TpUpdaterContext* upd = tp_updater_create(pool, NULL, tp_scheduler_get_ready, sched);
    TEST_ASSERT(upd != NULL, "updater should not be NULL");
    TEST_ASSERT(tp_updater_start(upd), "updater should start");

    TpTask task = { .execute = mock_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    for (int i = 0; i < 3; i++) tp_scheduler_add(sched, &task, 0);
    for (int i = 0; i < 4; i++) tp_scheduler_add(sched, &task, 10);

    WAIT_UNTIL(atomic_load(&g_tasks_executed) == 3, 5000);
    TEST_ASSERT(atomic_load(&g_tasks_executed) == 3, "the three ready tasks should run");
    tp_sleep_us(20000);
    TEST_ASSERT(atomic_load(&g_tasks_executed) == 3, "delayed tasks must wait for their tick");

    atomic_store(&g_current_tick, 10);
    WAIT_UNTIL(atomic_load(&g_tasks_executed) == 7, 5000);
    TEST_ASSERT(atomic_load(&g_tasks_executed) == 7, "all seven should run once");
    TEST_ASSERT(tp_scheduler_count(sched) == 0, "scheduler should be empty");

    tp_updater_stop(upd);
    tp_updater_destroy(upd);
    tp_pool_destroy(pool);
    tp_scheduler_destroy(sched);
    TEST_PASS("test_scheduler_with_updater");
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
    failures += test_scheduler_null_config();
    failures += test_scheduler_sleep_ticks_sleeps();
    failures += test_scheduler_sleep_wakes_on_add();
    failures += test_scheduler_sleep_respects_earliest();
    failures += test_scheduler_buffers_independent();
    failures += test_scheduler_with_updater();

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
