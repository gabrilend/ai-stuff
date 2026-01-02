/*
 * Threading Infrastructure v2 Tests
 *
 * Tests ring buffer task lists, load balancing, and sync.
 * Run with: gcc -o test_threading test_threading.c threading.c -lpthread && ./test_threading
 */

#include "threading.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

/* {{{ Test state */
static int task_counter = 0;
static pthread_mutex_t counter_lock = PTHREAD_MUTEX_INITIALIZER;
/* }}} */

/* {{{ increment_task
 * Simple task that increments a counter. */
void increment_task(void* context) {
    (void)context;
    pthread_mutex_lock(&counter_lock);
    task_counter++;
    pthread_mutex_unlock(&counter_lock);
}
/* }}} */

/* {{{ test_pool_create_destroy
 * Tests basic pool lifecycle. */
int test_pool_create_destroy(void) {
    printf("=== test_pool_create_destroy ===\n");
    fflush(stdout);

    /* Create pool with 2 workers */
    printf("  Creating pool...\n");
    fflush(stdout);
    WorkerPool* pool = pool_create(2);
    if (pool == NULL) {
        printf("FAIL: pool_create returned NULL\n");
        return 1;
    }
    if (pool->count != 2) {
        printf("FAIL: pool->count = %d, expected 2\n", pool->count);
        return 1;
    }

    /* Let workers run briefly */
    printf("  Sleeping 100ms...\n");
    fflush(stdout);
    usleep(100000);  /* 100ms */

    /* Destroy pool */
    printf("  Destroying pool...\n");
    fflush(stdout);
    pool_destroy(pool);

    printf("PASS\n\n");
    fflush(stdout);
    return 0;
}
/* }}} */

/* {{{ test_auto_detect_cores
 * Tests auto-detection of CPU cores. */
int test_auto_detect_cores(void) {
    printf("=== test_auto_detect_cores ===\n");

    /* Create pool with auto-detect (0) */
    WorkerPool* pool = pool_create(0);
    assert(pool != NULL);
    assert(pool->count > 0);
    printf("Auto-detected %d CPU cores\n", pool->count);

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_task_append_execute
 * Tests appending and executing tasks. */
int test_task_append_execute(void) {
    printf("=== test_task_append_execute ===\n");

    task_counter = 0;
    WorkerPool* pool = pool_create(2);
    assert(pool != NULL);

    /* Append tasks to worker 0 */
    Worker* w = &pool->workers[0];
    for (int i = 0; i < 10; i++) {
        WorkerTask task = {
            .execute = increment_task,
            .on_complete = NULL,
            .context = NULL,
            .weight = WEIGHT_LIGHT,
            .repeat_count = 1
        };
        bool success = task_append(w, &task);
        assert(success);
    }

    /* Wait for tasks to complete */
    usleep(200000);  /* 200ms */

    printf("Tasks executed: %d (expected 10)\n", task_counter);
    assert(task_counter == 10);

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_load_balancing
 * Tests that tasks are distributed to least-busy worker. */
int test_load_balancing(void) {
    printf("=== test_load_balancing ===\n");

    WorkerPool* pool = pool_create(4);
    assert(pool != NULL);

    /* Add different weights to workers */
    for (int i = 0; i < pool->count; i++) {
        atomic_store(&pool->workers[i].num_tasks, i * 10);
    }

    /* Find least busy - should be worker 0 */
    Worker* least = find_least_busy_worker(pool);
    assert(least == &pool->workers[0]);
    printf("Least busy worker: %d (expected 0)\n", least->worker_id);

    /* Reset and try again */
    atomic_store(&pool->workers[0].num_tasks, 100);
    least = find_least_busy_worker(pool);
    assert(least == &pool->workers[1]);
    printf("After update, least busy: %d (expected 1)\n", least->worker_id);

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_total_load
 * Tests pool_get_total_load function. */
int test_total_load(void) {
    printf("=== test_total_load ===\n");

    WorkerPool* pool = pool_create(4);
    assert(pool != NULL);

    /* Set known loads */
    for (int i = 0; i < pool->count; i++) {
        atomic_store(&pool->workers[i].num_tasks, 10);
    }

    unsigned int total = pool_get_total_load(pool);
    printf("Total load: %u (expected %d)\n", total, pool->count * 10);
    assert(total == (unsigned int)(pool->count * 10));

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_repeat_count
 * Tests that repeat_count controls task execution. */
int test_repeat_count(void) {
    printf("=== test_repeat_count ===\n");

    task_counter = 0;
    WorkerPool* pool = pool_create(1);
    assert(pool != NULL);

    /* Add task that runs 5 times */
    Worker* w = &pool->workers[0];
    WorkerTask task = {
        .execute = increment_task,
        .on_complete = NULL,
        .context = NULL,
        .weight = WEIGHT_LIGHT,
        .repeat_count = 5
    };
    bool success = task_append(w, &task);
    assert(success);

    /* Wait for completion */
    usleep(300000);  /* 300ms - enough for 5 executions plus some sleep cycles */

    printf("Tasks executed: %d (expected 5)\n", task_counter);
    assert(task_counter == 5);

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ completion_callback
 * Callback for testing on_complete. */
static int completion_called = 0;
void completion_callback(void* context) {
    (void)context;
    pthread_mutex_lock(&counter_lock);
    completion_called++;
    pthread_mutex_unlock(&counter_lock);
}
/* }}} */

/* {{{ test_on_complete
 * Tests that on_complete callback is called. */
int test_on_complete(void) {
    printf("=== test_on_complete ===\n");

    task_counter = 0;
    completion_called = 0;
    WorkerPool* pool = pool_create(1);
    assert(pool != NULL);

    /* Add task with completion callback */
    Worker* w = &pool->workers[0];
    WorkerTask task = {
        .execute = increment_task,
        .on_complete = completion_callback,
        .context = NULL,
        .weight = WEIGHT_LIGHT,
        .repeat_count = 3
    };
    bool success = task_append(w, &task);
    assert(success);

    /* Wait for completion */
    usleep(200000);

    printf("Tasks executed: %d, completions: %d\n", task_counter, completion_called);
    assert(task_counter == 3);
    assert(completion_called == 1);

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_sync_watch_list
 * Tests sync thread watch list operations. */
int test_sync_watch_list(void) {
    printf("=== test_sync_watch_list ===\n");

    SyncContext* sync = sync_create(100);
    assert(sync != NULL);

    /* Create test data */
    atomic_bool ready = false;
    void* target = NULL;
    void* source = (void*)0x12345678;

    /* Add watch entry */
    bool success = sync_add_watch(sync, &ready, &target, source);
    assert(success);
    assert(atomic_load(&sync->watch_count) == 1);

    /* Start sync thread */
    pthread_t sync_thread = spawn_sync_thread(sync);

    /* Set ready flag */
    atomic_store(&ready, true);

    /* Wait for swap */
    usleep(10000);  /* 10ms */

    printf("Target after swap: %p (expected %p)\n", target, source);
    assert(target == source);
    assert(sync->swaps_performed == 1);

    /* Shutdown */
    atomic_store(&sync->running, false);
    pthread_join(sync_thread, NULL);
    sync_destroy(sync);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_sync_multiple_entries
 * Tests sync with multiple watch entries. */
int test_sync_multiple_entries(void) {
    printf("=== test_sync_multiple_entries ===\n");

    SyncContext* sync = sync_create(100);
    assert(sync != NULL);

    /* Create multiple test entries */
    #define NUM_ENTRIES 10
    atomic_bool ready[NUM_ENTRIES];
    void* targets[NUM_ENTRIES];
    void* sources[NUM_ENTRIES];

    for (int i = 0; i < NUM_ENTRIES; i++) {
        atomic_store(&ready[i], false);
        targets[i] = NULL;
        sources[i] = (void*)(intptr_t)(i + 1);
        bool success = sync_add_watch(sync, &ready[i], &targets[i], sources[i]);
        assert(success);
    }

    /* Start sync thread */
    pthread_t sync_thread = spawn_sync_thread(sync);

    /* Set ready flags in random order */
    for (int i = NUM_ENTRIES - 1; i >= 0; i--) {
        atomic_store(&ready[i], true);
        usleep(1000);  /* 1ms between */
    }

    /* Wait for all swaps */
    usleep(50000);

    /* Verify all targets updated */
    int matched = 0;
    for (int i = 0; i < NUM_ENTRIES; i++) {
        if (targets[i] == sources[i]) matched++;
    }
    printf("Matched: %d/%d\n", matched, NUM_ENTRIES);
    assert(matched == NUM_ENTRIES);

    /* Shutdown */
    atomic_store(&sync->running, false);
    pthread_join(sync_thread, NULL);
    sync_destroy(sync);

    printf("PASS\n\n");
    return 0;
    #undef NUM_ENTRIES
}
/* }}} */

/* {{{ test_distribute_to_least_busy
 * Tests distributing many tasks with load balancing. */
int test_distribute_to_least_busy(void) {
    printf("=== test_distribute_to_least_busy ===\n");

    task_counter = 0;
    WorkerPool* pool = pool_create(4);
    assert(pool != NULL);

    /* Distribute 100 tasks to least-busy workers */
    for (int i = 0; i < 100; i++) {
        Worker* target = find_least_busy_worker(pool);
        WorkerTask task = {
            .execute = increment_task,
            .on_complete = NULL,
            .context = NULL,
            .weight = WEIGHT_LIGHT,
            .repeat_count = 1
        };
        bool success = task_append(target, &task);
        assert(success);
    }

    /* Wait for completion */
    usleep(500000);  /* 500ms */

    printf("Tasks executed: %d (expected 100)\n", task_counter);
    assert(task_counter == 100);

    /* Check load distribution (should be relatively even) */
    printf("Final loads: ");
    for (int i = 0; i < pool->count; i++) {
        printf("w%d=%u ", i, atomic_load(&pool->workers[i].num_tasks));
    }
    printf("\n");

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_timestamp
 * Tests get_timestamp_us function. */
int test_timestamp(void) {
    printf("=== test_timestamp ===\n");

    uint64_t t1 = get_timestamp_us();
    usleep(10000);  /* 10ms */
    uint64_t t2 = get_timestamp_us();

    uint64_t elapsed = t2 - t1;
    printf("Elapsed: %lu us (expected ~10000)\n", elapsed);

    /* Allow 20% tolerance */
    assert(elapsed > 8000 && elapsed < 20000);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ Test updater state */
static WorkerTask test_pending_tasks[100];
static size_t test_pending_count = 0;
/* }}} */

/* {{{ test_get_pending_tasks
 * Callback for updater tests. */
bool test_get_pending_tasks(UpdaterContext* ctx, WorkerTask** out, size_t* count) {
    (void)ctx;
    if (test_pending_count == 0) {
        *out = NULL;
        *count = 0;
        return false;
    }
    *out = test_pending_tasks;
    *count = test_pending_count;
    return true;
}
/* }}} */

/* {{{ test_updater_create_start
 * Tests creating and starting an updater. */
int test_updater_create_start(void) {
    printf("=== test_updater_create_start ===\n");

    WorkerPool* pool = pool_create(2);
    assert(pool != NULL);

    /* Create updater */
    UpdaterContext* updater = updater_create(pool, test_get_pending_tasks, NULL);
    assert(updater != NULL);
    assert(updater->is_primary == true);
    assert(updater->is_allocated == true);

    /* Start updater (adds to worker) */
    updater_start(updater);

    /* Wait briefly for it to run */
    usleep(50000);

    /* Destroy (note: updater is still in worker's task list) */
    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_helper_spawn_complete
 * Tests helper spawning and completion. */
int test_helper_spawn_complete(void) {
    printf("=== test_helper_spawn_complete ===\n");

    task_counter = 0;
    WorkerPool* pool = pool_create(2);
    assert(pool != NULL);

    /* Create updater context */
    UpdaterContext* primary = updater_create(pool, test_get_pending_tasks, NULL);
    assert(primary != NULL);

    /* Set up some pending tasks */
    test_pending_count = 10;
    for (size_t i = 0; i < test_pending_count; i++) {
        test_pending_tasks[i].execute = increment_task;
        test_pending_tasks[i].on_complete = NULL;
        test_pending_tasks[i].context = NULL;
        test_pending_tasks[i].weight = WEIGHT_LIGHT;
        test_pending_tasks[i].repeat_count = 1;
    }

    /* Spawn a helper for half the tasks */
    spawn_helper_updater(primary, 0, 5);

    /* Wait for helper to run */
    usleep(200000);

    printf("Tasks executed by helper: %d (expected 5)\n", task_counter);
    assert(task_counter == 5);

    /* Clean up */
    test_pending_count = 0;
    updater_destroy(primary);
    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ test_helper_self_evaluate
 * Tests helper self-evaluation (continuation/exit logic). */
int test_helper_self_evaluate(void) {
    printf("=== test_helper_self_evaluate ===\n");

    WorkerPool* pool = pool_create(2);
    assert(pool != NULL);

    /* Create a helper context that should exit (low timing) */
    UpdaterContext* helper = calloc(1, sizeof(UpdaterContext));
    helper->pool = pool;
    helper->get_pending_tasks = test_get_pending_tasks;
    helper->user_data = NULL;
    helper->partition_start = 0;
    helper->partition_end = 0;
    helper->last_tick_duration_us = 1000;  /* 1ms - below 5ms threshold */
    helper->is_primary = false;
    helper->is_allocated = true;

    /* Call on_complete - should free the helper (below threshold) */
    helper_updater_on_complete(helper);
    /* If it didn't crash, it worked (helper was freed) */

    pool_destroy(pool);

    printf("PASS\n\n");
    return 0;
}
/* }}} */

/* {{{ main
 * Runs all tests. */
int main(void) {
    printf("\n========================================\n");
    printf("Threading Infrastructure v2 Tests\n");
    printf("========================================\n\n");

    int failures = 0;

    failures += test_timestamp();
    failures += test_pool_create_destroy();
    failures += test_auto_detect_cores();
    failures += test_task_append_execute();
    failures += test_load_balancing();
    failures += test_total_load();
    failures += test_repeat_count();
    failures += test_on_complete();
    failures += test_sync_watch_list();
    failures += test_sync_multiple_entries();
    failures += test_distribute_to_least_busy();
    failures += test_updater_create_start();
    failures += test_helper_spawn_complete();
    failures += test_helper_self_evaluate();

    printf("========================================\n");
    if (failures == 0) {
        printf("All tests passed!\n");
    } else {
        printf("FAILURES: %d\n", failures);
    }
    printf("========================================\n\n");

    return failures;
}
/* }}} */
