/*
 * Threadpool Library - Core Implementation
 *
 * See threadpool.h for API documentation.
 * See threadpool_config.h for configuration options.
 *
 * This implementation provides:
 * - Ring buffer task lists for workers
 * - Load-balanced task distribution
 * - Automatic ring buffer compaction
 */

#include "threadpool.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <limits.h>

/* {{{ tp_get_timestamp_us
 * Returns current time in microseconds (monotonic clock). */
uint64_t tp_get_timestamp_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000ULL + (uint64_t)ts.tv_nsec / 1000ULL;
}
/* }}} */

/* {{{ tp_sleep_task
 * Default no-op task that yields briefly.
 * Used as a placeholder or for testing. */
void tp_sleep_task(void* context) {
    (void)context;  /* Unused */
    usleep(1000);   /* 1ms yield */
}
/* }}} */

/* {{{ tp_relocate_task
 * Compacts the ring buffer by copying active tasks to the start.
 * Called when end_ptr approaches the buffer end. */
void tp_relocate_task(void* context) {
    TpWorker* w = (TpWorker*)context;

    /* Count active tasks (from current position to end) */
    size_t active_count = 0;
    size_t read_ptr = w->start_ptr;

    while (read_ptr != w->end_ptr) {
        TpTask* task = &w->task_list[read_ptr];
        if (task->execute != tp_sleep_task) {
            active_count++;
        }
        read_ptr = (read_ptr + 1) % w->task_list_size;
    }

    /* If no active tasks, just reset to empty buffer */
    if (active_count == 0) {
        w->start_ptr = 0;
        w->end_ptr = 0;
        return;
    }

    /* Copy active tasks to temporary storage */
    TpTask* temp = malloc(active_count * sizeof(TpTask));
    if (!temp) {
        TP_LOG(&w->pool->config, "[worker %d] relocate_task: malloc failed\n", w->worker_id);
        return;
    }

    size_t write_idx = 0;
    read_ptr = w->start_ptr;
    while (read_ptr != w->end_ptr && write_idx < active_count) {
        TpTask* task = &w->task_list[read_ptr];
        if (task->execute != tp_sleep_task) {
            temp[write_idx++] = *task;
        }
        read_ptr = (read_ptr + 1) % w->task_list_size;
    }

    /* Copy back to start of buffer */
    for (size_t i = 0; i < active_count; i++) {
        w->task_list[i] = temp[i];
    }
    free(temp);

    /* Reset pointers */
    w->start_ptr = 0;
    w->end_ptr = active_count;

    TP_LOG(&w->pool->config, "[worker %d] Relocated %zu active tasks to buffer start\n",
           w->worker_id, active_count);
}
/* }}} */

/* {{{ tp_task_append
 * Appends a task to a worker's ring buffer.
 * Returns false if buffer is full. */
bool tp_task_append(TpWorker* w, TpTask* task) {
    /* Calculate next position */
    size_t next = (w->end_ptr + 1) % w->task_list_size;

    /* Check if buffer is full */
    if (next == w->start_ptr) {
        TP_LOG(&w->pool->config, "[worker %d] task_append: buffer full\n", w->worker_id);
        return false;
    }

    /* Copy task to buffer */
    w->task_list[w->end_ptr] = *task;
    w->end_ptr = next;

    /* Update load counter */
    atomic_fetch_add(&w->num_tasks, task->weight);

    /* Check if approaching end of buffer - schedule relocate
     * Trigger when less than 10% of buffer remains */
    size_t remaining;
    if (w->end_ptr >= w->start_ptr) {
        remaining = w->task_list_size - w->end_ptr + w->start_ptr;
    } else {
        remaining = w->start_ptr - w->end_ptr;
    }

    if (remaining < w->task_list_size / 10) {
        /* Append relocate task */
        size_t reloc_next = (w->end_ptr + 1) % w->task_list_size;
        if (reloc_next != w->start_ptr) {
            w->task_list[w->end_ptr].execute = tp_relocate_task;
            w->task_list[w->end_ptr].on_complete = NULL;
            w->task_list[w->end_ptr].context = w;
            w->task_list[w->end_ptr].weight = TP_WEIGHT_LIGHT;
            w->task_list[w->end_ptr].repeat_count = 1;
            w->end_ptr = reloc_next;
        }
    }

    return true;
}
/* }}} */

/* {{{ tp_find_least_busy
 * Returns the worker with the lowest weighted task count.
 * O(N) scan where N = worker count. */
TpWorker* tp_find_least_busy(TpPool* pool) {
    if (!pool || pool->count == 0) return NULL;

    TpWorker* best = &pool->workers[0];
    unsigned int best_load = atomic_load(&best->num_tasks);

    for (int i = 1; i < pool->count; i++) {
        unsigned int load = atomic_load(&pool->workers[i].num_tasks);
        if (load < best_load) {
            best = &pool->workers[i];
            best_load = load;
        }
    }

    return best;
}
/* }}} */

/* {{{ tp_find_least_busy_excluding
 * Returns the least busy worker, excluding a specific worker ID.
 * Used by updater to avoid queueing tasks behind itself.
 * If all workers are excluded or pool is empty, returns NULL. */
TpWorker* tp_find_least_busy_excluding(TpPool* pool, int exclude_id) {
    if (!pool || pool->count == 0) return NULL;
    if (pool->count == 1) return NULL;  /* Can't exclude the only worker */

    TpWorker* best = NULL;
    unsigned int best_load = UINT_MAX;

    for (int i = 0; i < pool->count; i++) {
        if (pool->workers[i].worker_id == exclude_id) continue;

        unsigned int load = atomic_load(&pool->workers[i].num_tasks);
        if (load < best_load) {
            best = &pool->workers[i];
            best_load = load;
        }
    }

    return best;
}
/* }}} */

/* {{{ tp_worker_loop
 * Main loop for worker threads.
 * Executes tasks from the ring buffer.
 *
 * repeat_count behavior:
 *   N > 0: run N more times, then call on_complete and advance
 *   N <= 0: already done, skip this slot (-1 does NOT mean infinite)
 *   Use INT16_MAX for "essentially infinite" execution
 */
void* tp_worker_loop(void* arg) {
    TpWorker* w = (TpWorker*)arg;

    TP_LOG(&w->pool->config, "[worker %d] Starting\n", w->worker_id);

    while (atomic_load(&w->running)) {
        /* Check if buffer is empty */
        if (w->start_ptr == w->end_ptr) {
            /* Buffer empty - brief yield and retry
             * Use short sleep (100us) to reduce latency while avoiding busy-wait */
            usleep(100);
            continue;
        }

        /* Get current task */
        TpTask* task = &w->task_list[w->start_ptr];

        /* Handle based on repeat_count - treat <= 0 as completed */
        if (task->execute == NULL || task->repeat_count <= 0) {
            /* Task is empty or already done - advance to next */
            w->start_ptr = (w->start_ptr + 1) % w->task_list_size;
            continue;
        }

        /* Execute the task */
        task->execute(task->context);

        /* Decrement repeat_count */
        task->repeat_count--;

        if (task->repeat_count <= 0) {
            /* Task is now complete */
            if (task->on_complete) {
                task->on_complete(task->context);
            }

            /* Decrement load counter */
            atomic_fetch_sub(&w->num_tasks, task->weight);

            /* Clear the slot */
            task->execute = NULL;
            task->on_complete = NULL;
            task->context = NULL;
            task->weight = 0;

            /* Advance to next slot */
            w->start_ptr = (w->start_ptr + 1) % w->task_list_size;
        }
        /* If repeat_count > 0, don't advance - run again next iteration */
    }

    TP_LOG(&w->pool->config, "[worker %d] Exiting\n", w->worker_id);
    return NULL;
}
/* }}} */

/* {{{ tp_pool_create
 * Creates a worker pool with the specified number of workers.
 * If worker_count is 0, auto-detects CPU cores.
 * If config is NULL, uses defaults. */
TpPool* tp_pool_create(TpConfig* config, int worker_count) {
    /* Use defaults if no config provided */
    TpConfig cfg = config ? *config : tp_config_default();

    /* Auto-detect CPU cores if not specified */
    if (worker_count <= 0) {
        worker_count = (int)sysconf(_SC_NPROCESSORS_ONLN);
        if (worker_count <= 0) worker_count = 4;  /* Fallback */
    }

    TP_LOG(&cfg, "[threadpool] Creating pool with %d workers\n", worker_count);

    /* Allocate pool */
    TpPool* pool = calloc(1, sizeof(TpPool));
    if (!pool) {
        TP_LOG(&cfg, "[threadpool] Failed to allocate pool\n");
        return NULL;
    }

    pool->count = worker_count;
    pool->config = cfg;  /* Store copy of config */
    atomic_store(&pool->running, true);

    /* Allocate worker array */
    pool->workers = calloc(worker_count, sizeof(TpWorker));
    if (!pool->workers) {
        TP_LOG(&pool->config, "[threadpool] Failed to allocate workers\n");
        free(pool);
        return NULL;
    }

    /* Initialize each worker */
    for (int i = 0; i < worker_count; i++) {
        TpWorker* w = &pool->workers[i];
        w->worker_id = i;
        w->pool = pool;
        w->task_list_size = cfg.task_list_size;
        atomic_store(&w->num_tasks, 0);
        atomic_store(&w->running, true);

        /* Allocate task ring buffer */
        w->task_list = calloc(cfg.task_list_size, sizeof(TpTask));
        if (!w->task_list) {
            TP_LOG(&pool->config, "[threadpool] Failed to allocate task list for worker %d\n", i);
            /* Clean up already allocated workers */
            for (int j = 0; j < i; j++) {
                free(pool->workers[j].task_list);
            }
            free(pool->workers);
            free(pool);
            return NULL;
        }

        /* Start with empty buffer - workers will sleep when no tasks */
        w->start_ptr = 0;
        w->end_ptr = 0;
    }

    /* Spawn worker threads */
    for (int i = 0; i < worker_count; i++) {
        int result = pthread_create(&pool->workers[i].thread, NULL,
                                    tp_worker_loop, &pool->workers[i]);
        if (result != 0) {
            TP_LOG(&pool->config, "[threadpool] Failed to create worker %d\n", i);
        } else {
            TP_LOG(&pool->config, "[threadpool] Worker %d spawned\n", i);
        }
    }

    return pool;
}
/* }}} */

/* {{{ tp_pool_destroy
 * Signals workers to stop, joins all threads, frees resources. */
void tp_pool_destroy(TpPool* pool) {
    if (!pool) return;

    TP_LOG(&pool->config, "[threadpool] Destroying pool...\n");

    /* Signal shutdown */
    atomic_store(&pool->running, false);
    for (int i = 0; i < pool->count; i++) {
        atomic_store(&pool->workers[i].running, false);
    }

    /* Join all worker threads */
    for (int i = 0; i < pool->count; i++) {
        pthread_join(pool->workers[i].thread, NULL);
        TP_LOG(&pool->config, "[threadpool] Worker %d joined\n", i);
    }

    /* Free task lists */
    for (int i = 0; i < pool->count; i++) {
        free(pool->workers[i].task_list);
    }

    /* Free workers array and pool */
    free(pool->workers);
    free(pool);

    /* Note: can't log after free since config is inside pool */
}
/* }}} */

/* {{{ tp_pool_get_load
 * Returns the sum of weighted task counts across all workers. */
unsigned int tp_pool_get_load(TpPool* pool) {
    if (!pool) return 0;

    unsigned int total = 0;
    for (int i = 0; i < pool->count; i++) {
        total += atomic_load(&pool->workers[i].num_tasks);
    }
    return total;
}
/* }}} */
