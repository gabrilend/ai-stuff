/*
 * Test: Core Pool Functionality
 *
 * Verifies pool creation and destruction, task execution, load accounting,
 * ring buffer wrap-around and fullness, appends from many threads at once,
 * appends from a task to its own worker, and ring compaction.
 */

#include "../src/threadpool.h"
#include "test_common.h"
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <pthread.h>

/* {{{ Test State */
static atomic_int g_task_counter = 0;
static atomic_int g_complete_counter = 0;
static atomic_int g_log_calls = 0;
static atomic_bool g_gate_open = false;
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

/* {{{ gate_task
 * Holds its worker until g_gate_open is set, so a test can fill the ring. */
static void gate_task(void* context) {
    (void)context;
    while (!atomic_load(&g_gate_open)) {
        usleep(200);
    }
}
/* }}} */

/* {{{ test_logger */
static void test_logger(const char* fmt, ...) {
    (void)fmt;
    atomic_fetch_add(&g_log_calls, 1);
}
/* }}} */

/* {{{ append_retry
 * Appends, retrying while the ring is full. Returns false after ~10s. */
static bool append_retry(TpWorker* w, TpTask* task) {
    for (int tries = 0; tries < 100000; tries++) {
        if (tp_task_append(w, task)) return true;
        usleep(100);
    }
    return false;
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

/* {{{ test_pool_rejects_tiny_ring */
static int test_pool_rejects_tiny_ring(void) {
    /* Test: a ring too small to hold one task is refused, not built broken */
    TpConfig cfg = tp_config_default();
    cfg.task_list_size = 1;
    TEST_ASSERT(tp_pool_create(&cfg, 1) == NULL, "task_list_size 1 should be refused");

    TEST_PASS("test_pool_rejects_tiny_ring");
    return 0;
}
/* }}} */

/* {{{ test_pool_with_logging */
static int test_pool_with_logging(void) {
    /* Test: pool creates with custom logging, and the callback is used */
    atomic_store(&g_log_calls, 0);
    TpConfig cfg = tp_config_default();
    cfg.log_fn = test_logger;

    TpPool* pool = tp_pool_create(&cfg, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TEST_ASSERT(pool->config.log_fn == test_logger, "log_fn should be set");

    tp_pool_destroy(pool);
    TEST_ASSERT(atomic_load(&g_log_calls) > 0, "log callback should have been called");
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

    WAIT_UNTIL(atomic_load(&g_complete_counter) == 10, 5000);

    TEST_ASSERT(atomic_load(&g_task_counter) == 10, "all tasks should have executed");
    TEST_ASSERT(atomic_load(&g_complete_counter) == 10, "all on_complete should have been called");

    tp_pool_destroy(pool);
    TEST_PASS("test_task_execution");
    return 0;
}
/* }}} */

/* {{{ test_load_balancing */
static int test_load_balancing(void) {
    /* Test: load balancing distributes tasks */
    atomic_store(&g_gate_open, false);
    TpPool* pool = tp_pool_create(NULL, 4);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    /* Initially all workers should have zero load */
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "initial load should be 0");

    /* A heavy task that holds worker 0 until the test is done looking */
    TpTask heavy = {
        .execute = gate_task,
        .weight = TP_WEIGHT_HEAVY,
        .repeat_count = 1
    };
    tp_task_append(&pool->workers[0], &heavy);
    TEST_ASSERT(tp_pool_get_load(pool) == TP_WEIGHT_HEAVY, "load should count the heavy task");

    /* Now find_least_busy should NOT return worker 0 */
    TpWorker* least = tp_find_least_busy(pool);
    TEST_ASSERT(least != NULL, "should find a worker");
    TEST_ASSERT(least->worker_id != 0, "least busy should not be worker 0");

    /* find_least_busy_excluding should work */
    TpWorker* excluded = tp_find_least_busy_excluding(pool, 1);
    TEST_ASSERT(excluded != NULL, "should find worker excluding 1");
    TEST_ASSERT(excluded->worker_id != 1, "should not return excluded worker");

    atomic_store(&g_gate_open, true);
    WAIT_UNTIL(tp_pool_get_load(pool) == 0, 5000);
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "load should return to 0 once the task ends");

    tp_pool_destroy(pool);
    TEST_PASS("test_load_balancing");
    return 0;
}
/* }}} */

/* {{{ test_repeat_count */
static int test_repeat_count(void) {
    /* Test: repeat_count causes multiple executions */
    atomic_store(&g_task_counter, 0);
    atomic_store(&g_complete_counter, 0);

    TpPool* pool = tp_pool_create(NULL, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpTask task = {
        .execute = test_task_execute,
        .on_complete = test_task_on_complete,
        .context = NULL,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 5  /* Run 5 times */
    };

    tp_task_append(&pool->workers[0], &task);

    WAIT_UNTIL(atomic_load(&g_complete_counter) == 1, 5000);
    TEST_ASSERT(atomic_load(&g_task_counter) == 5, "task should have executed 5 times");
    TEST_ASSERT(atomic_load(&g_complete_counter) == 1, "on_complete should run once");

    tp_pool_destroy(pool);
    TEST_PASS("test_repeat_count");
    return 0;
}
/* }}} */

/* {{{ test_repeat_zero_releases_load */
static int test_repeat_zero_releases_load(void) {
    /* Test: a task appended already done is skipped and its weight released */
    atomic_store(&g_task_counter, 0);

    TpPool* pool = tp_pool_create(NULL, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    TpTask done = { .execute = test_task_execute, .weight = TP_WEIGHT_MEDIUM, .repeat_count = 0 };
    TEST_ASSERT(tp_task_append(&pool->workers[0], &done), "append should succeed");

    WAIT_UNTIL(tp_worker_queued(&pool->workers[0]) == 0, 5000);
    TEST_ASSERT(tp_worker_queued(&pool->workers[0]) == 0, "slot should be released");
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "load should return to 0");
    TEST_ASSERT(atomic_load(&g_task_counter) == 0, "a done task must not run");

    tp_pool_destroy(pool);
    TEST_PASS("test_repeat_zero_releases_load");
    return 0;
}
/* }}} */

/* {{{ test_ring_wraps */
static int test_ring_wraps(void) {
    /* Test: a small ring wraps around many times without losing or repeating
     * a task, and the load count ends at exactly zero */
    atomic_store(&g_task_counter, 0);
    atomic_store(&g_complete_counter, 0);

    TpConfig cfg = tp_config_default();
    cfg.task_list_size = 8;
    TpPool* pool = tp_pool_create(&cfg, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    const int total = 2000;
    for (int i = 0; i < total; i++) {
        TpTask task = {
            .execute = test_task_execute,
            .on_complete = test_task_on_complete,
            .weight = TP_WEIGHT_LIGHT,
            .repeat_count = 1
        };
        TEST_ASSERT(append_retry(&pool->workers[0], &task), "append should eventually succeed");
    }

    WAIT_UNTIL(atomic_load(&g_complete_counter) == total, 10000);
    TEST_ASSERT(atomic_load(&g_task_counter) == total, "every task should run exactly once");
    TEST_ASSERT(atomic_load(&g_complete_counter) == total, "every on_complete should run once");
    WAIT_UNTIL(tp_pool_get_load(pool) == 0, 5000);
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "load should return to exactly 0");

    tp_pool_destroy(pool);
    TEST_PASS("test_ring_wraps");
    return 0;
}
/* }}} */

/* {{{ test_buffer_full */
static int test_buffer_full(void) {
    /* Test: a ring of size N holds N-1 tasks; the next append is refused and
     * nothing already queued is harmed */
    atomic_store(&g_task_counter, 0);
    atomic_store(&g_gate_open, false);

    TpConfig cfg = tp_config_default();
    cfg.task_list_size = 4;
    TpPool* pool = tp_pool_create(&cfg, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TpWorker* w = &pool->workers[0];

    TpTask gate = { .execute = gate_task, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask work = { .execute = test_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    TEST_ASSERT(tp_task_append(w, &gate), "gate append should succeed");
    TEST_ASSERT(tp_task_append(w, &work), "second append should succeed");
    TEST_ASSERT(tp_task_append(w, &work), "third append should succeed");
    TEST_ASSERT(!tp_task_append(w, &work), "fourth append should be refused (full)");
    TEST_ASSERT(tp_worker_queued(w) == 3, "three tasks should be queued");
    TEST_ASSERT(tp_pool_get_load(pool) == 3, "a refused task adds no load");

    atomic_store(&g_gate_open, true);
    WAIT_UNTIL(atomic_load(&g_task_counter) == 2 && tp_worker_queued(w) == 0, 5000);
    TEST_ASSERT(atomic_load(&g_task_counter) == 2, "both queued tasks should run");
    TEST_ASSERT(tp_worker_queued(w) == 0, "ring should be empty");

    tp_pool_destroy(pool);
    TEST_PASS("test_buffer_full");
    return 0;
}
/* }}} */

/* {{{ Many-producer state */
#define PRODUCERS 4
#define PER_PRODUCER 5000
typedef struct producer_arg {
    TpPool* pool;
    atomic_int* failures;
} ProducerArg;
/* }}} */

/* {{{ producer_thread
 * Appends PER_PRODUCER tasks to whichever worker is least busy. */
static void* producer_thread(void* arg) {
    ProducerArg* pa = (ProducerArg*)arg;
    for (int i = 0; i < PER_PRODUCER; i++) {
        TpTask task = {
            .execute = test_task_execute,
            .on_complete = test_task_on_complete,
            .weight = TP_WEIGHT_LIGHT,
            .repeat_count = 1
        };
        if (!append_retry(tp_find_least_busy(pa->pool), &task)) {
            atomic_fetch_add(pa->failures, 1);
        }
    }
    return NULL;
}
/* }}} */

/* {{{ test_many_producers */
static int test_many_producers(void) {
    /* Test: several threads appending at once lose and repeat nothing */
    atomic_store(&g_task_counter, 0);
    atomic_store(&g_complete_counter, 0);
    atomic_int failures = 0;

    TpConfig cfg = tp_config_default();
    cfg.task_list_size = 64;  /* Small, so producers meet full rings too */
    TpPool* pool = tp_pool_create(&cfg, 2);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    pthread_t threads[PRODUCERS];
    ProducerArg arg = { .pool = pool, .failures = &failures };
    for (int i = 0; i < PRODUCERS; i++) {
        pthread_create(&threads[i], NULL, producer_thread, &arg);
    }
    for (int i = 0; i < PRODUCERS; i++) {
        pthread_join(threads[i], NULL);
    }
    TEST_ASSERT(atomic_load(&failures) == 0, "no append should time out");

    const int total = PRODUCERS * PER_PRODUCER;
    WAIT_UNTIL(atomic_load(&g_complete_counter) == total, 20000);
    TEST_ASSERT(atomic_load(&g_task_counter) == total, "every task should run exactly once");
    TEST_ASSERT(atomic_load(&g_complete_counter) == total, "every on_complete should run once");
    WAIT_UNTIL(tp_pool_get_load(pool) == 0, 5000);
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "load should return to exactly 0");

    tp_pool_destroy(pool);
    TEST_PASS("test_many_producers");
    return 0;
}
/* }}} */

/* {{{ Chain state
 * A task whose on_complete appends the next link to its own worker. */
typedef struct chain {
    TpWorker* worker;
    atomic_int remaining;
} Chain;

static void chain_on_complete(void* context);

static void chain_append(Chain* chain) {
    TpTask next = {
        .execute = test_task_execute,
        .on_complete = chain_on_complete,
        .context = chain,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };
    tp_task_append(chain->worker, &next);
}

static void chain_on_complete(void* context) {
    Chain* chain = (Chain*)context;
    if (atomic_fetch_sub(&chain->remaining, 1) > 1) {
        chain_append(chain);
    }
}
/* }}} */

/* {{{ test_append_from_own_worker */
static int test_append_from_own_worker(void) {
    /* Test: a task's on_complete may append to the worker running it */
    atomic_store(&g_task_counter, 0);

    TpPool* pool = tp_pool_create(NULL, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");

    Chain chain = { .worker = &pool->workers[0] };
    atomic_init(&chain.remaining, 100);
    chain_append(&chain);

    WAIT_UNTIL(atomic_load(&chain.remaining) == 0, 5000);
    TEST_ASSERT(atomic_load(&chain.remaining) == 0, "the whole chain should run");
    TEST_ASSERT(atomic_load(&g_task_counter) == 100, "100 links should execute");

    tp_pool_destroy(pool);
    TEST_PASS("test_append_from_own_worker");
    return 0;
}
/* }}} */

/* {{{ test_relocate_drops_sleep_placeholders */
static int test_relocate_drops_sleep_placeholders(void) {
    /* Test: compaction removes queued sleep placeholders, keeps the rest in
     * order, and leaves the running task alone */
    atomic_store(&g_task_counter, 0);
    atomic_store(&g_gate_open, false);

    TpConfig cfg = tp_config_default();
    cfg.task_list_size = 16;
    TpPool* pool = tp_pool_create(&cfg, 1);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    TpWorker* w = &pool->workers[0];

    TpTask gate = { .execute = gate_task, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };
    TpTask placeholder = { .execute = tp_sleep_task, .weight = TP_WEIGHT_SLEEP, .repeat_count = 1 };
    TpTask work = { .execute = test_task_execute, .weight = TP_WEIGHT_LIGHT, .repeat_count = 1 };

    tp_task_append(w, &gate);
    WAIT_UNTIL(tp_pool_get_load(pool) == 1, 1000);  /* gate is running */
    for (int i = 0; i < 4; i++) {
        tp_task_append(w, &placeholder);
        tp_task_append(w, &work);
    }
    TEST_ASSERT(tp_worker_queued(w) == 9, "gate plus eight tasks should be queued");

    tp_relocate_task(w);
    TEST_ASSERT(tp_worker_queued(w) == 5, "four placeholders should be dropped");

    atomic_store(&g_gate_open, true);
    WAIT_UNTIL(atomic_load(&g_task_counter) == 4 && tp_worker_queued(w) == 0, 5000);
    TEST_ASSERT(atomic_load(&g_task_counter) == 4, "all real tasks should run");
    TEST_ASSERT(tp_pool_get_load(pool) == 0, "load should return to 0");

    tp_pool_destroy(pool);
    TEST_PASS("test_relocate_drops_sleep_placeholders");
    return 0;
}
/* }}} */

/* {{{ test_destroy_is_prompt */
static int test_destroy_is_prompt(void) {
    /* Test: idle workers sleep, and wake at once when the pool is destroyed */
    TpPool* pool = tp_pool_create(NULL, 4);
    TEST_ASSERT(pool != NULL, "pool should not be NULL");
    usleep(20000);  /* Let every worker go idle */

    uint64_t start = test_now_ms();
    tp_pool_destroy(pool);
    TEST_ASSERT(test_now_ms() - start < 1000, "destroying an idle pool should be prompt");

    TEST_PASS("test_destroy_is_prompt");
    return 0;
}
/* }}} */

/* {{{ main */
int main(void) {
    printf("=== Threadpool Core Tests ===\n\n");

    int failures = 0;

    failures += test_pool_create_defaults();
    failures += test_pool_create_specific_count();
    failures += test_pool_rejects_tiny_ring();
    failures += test_pool_with_logging();
    failures += test_task_execution();
    failures += test_load_balancing();
    failures += test_repeat_count();
    failures += test_repeat_zero_releases_load();
    failures += test_ring_wraps();
    failures += test_buffer_full();
    failures += test_many_producers();
    failures += test_append_from_own_worker();
    failures += test_relocate_drops_sleep_placeholders();
    failures += test_destroy_is_prompt();

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
