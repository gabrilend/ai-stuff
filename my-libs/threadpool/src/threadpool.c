/*
 * Threadpool Library - Core Implementation
 *
 * See threadpool.h for API documentation.
 * See threadpool_config.h for configuration options.
 *
 * This implementation provides:
 * - Ring buffer task lists for workers, safe for any number of producers
 * - Load-balanced task distribution
 * - Idle workers that sleep on a condition variable until work arrives
 */

#include "threadpool.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

/* {{{ tp_get_timestamp_us
 * Returns current time in microseconds (monotonic clock). */
uint64_t tp_get_timestamp_us(void) {
    return tp_time_us();
}
/* }}} */

/* {{{ tp_sleep_task
 * Default no-op task that yields briefly.
 * Used as a placeholder or for testing. */
void tp_sleep_task(void* context) {
    (void)context;  /* Unused */
    tp_sleep_us(1000);  /* 1ms yield */
}
/* }}} */

/* {{{ tp_relocate_task
 * Compacts the ring buffer: queued tp_sleep_task placeholders that have not
 * started are dropped, and the tasks after them move up to close the gaps.
 * The slot at start_ptr is never touched, because the worker may be running
 * it (it may even be this very call, queued as a task). */
void tp_relocate_task(void* context) {
    TpWorker* w = (TpWorker*)context;
    if (!w) return;

    tp_mutex_lock(&w->lock);

    size_t dropped = 0;
    if (w->start_ptr != w->end_ptr) {
        size_t read_ptr = (w->start_ptr + 1) % w->task_list_size;
        size_t write_ptr = read_ptr;

        while (read_ptr != w->end_ptr) {
            TpTask* task = &w->task_list[read_ptr];
            if (task->execute == tp_sleep_task) {
                atomic_fetch_sub(&w->num_tasks, task->weight);
                dropped++;
            } else {
                if (write_ptr != read_ptr) {
                    w->task_list[write_ptr] = *task;
                }
                write_ptr = (write_ptr + 1) % w->task_list_size;
            }
            read_ptr = (read_ptr + 1) % w->task_list_size;
        }

        /* Clear the slots freed at the tail */
        for (size_t p = write_ptr; p != w->end_ptr; p = (p + 1) % w->task_list_size) {
            memset(&w->task_list[p], 0, sizeof(TpTask));
        }
        w->end_ptr = write_ptr;
    }

    tp_mutex_unlock(&w->lock);

    if (dropped > 0) {
        TP_LOG(&w->pool->config, "[worker %d] Compacted ring, dropped %zu sleep placeholders\n",
               w->worker_id, dropped);
    }
}
/* }}} */

/* {{{ tp_task_append
 * Appends a copy of a task to a worker's ring buffer.
 * Thread-safe: any thread may append to any worker, including a task running
 * on that worker. Returns false if the buffer is full. */
bool tp_task_append(TpWorker* w, TpTask* task) {
    if (!w || !task) return false;

    tp_mutex_lock(&w->lock);

    /* Calculate next position; one slot stays empty to tell full from empty */
    size_t next = (w->end_ptr + 1) % w->task_list_size;
    if (next == w->start_ptr) {
        tp_mutex_unlock(&w->lock);
        TP_LOG(&w->pool->config, "[worker %d] task_append: buffer full\n", w->worker_id);
        return false;
    }

    /* Copy task to buffer; count its load before the worker can finish it */
    w->task_list[w->end_ptr] = *task;
    w->end_ptr = next;
    atomic_fetch_add(&w->num_tasks, task->weight);

    tp_cond_signal(&w->wake);
    tp_mutex_unlock(&w->lock);

    return true;
}
/* }}} */

/* {{{ tp_worker_queued
 * Returns the number of tasks in the ring, counting the one running now. */
size_t tp_worker_queued(TpWorker* w) {
    if (!w) return 0;

    tp_mutex_lock(&w->lock);
    size_t queued = (w->end_ptr + w->task_list_size - w->start_ptr) % w->task_list_size;
    tp_mutex_unlock(&w->lock);

    return queued;
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
        if (best == NULL || load < best_load) {
            best = &pool->workers[i];
            best_load = load;
        }
    }

    return best;
}
/* }}} */

/* {{{ tp_worker_loop
 * Main loop for worker threads.
 * Takes the task at start_ptr, runs it until its repeat_count is spent, then
 * calls on_complete and frees the slot.
 *
 * repeat_count behavior:
 *   N > 0: run N more times, then call on_complete and advance
 *   N <= 0: already done, skip this slot (-1 does NOT mean infinite)
 *   Use INT16_MAX for "essentially infinite" execution
 *
 * Shutdown is checked between runs, so a long-repeating task stops promptly;
 * a task cut short by shutdown does not get its on_complete call.
 */
void* tp_worker_loop(void* arg) {
    TpWorker* w = (TpWorker*)arg;

    TP_LOG(&w->pool->config, "[worker %d] Starting\n", w->worker_id);

    tp_mutex_lock(&w->lock);
    while (atomic_load(&w->running)) {
        /* Sleep until a task arrives or shutdown is signalled */
        if (w->start_ptr == w->end_ptr) {
            tp_cond_wait(&w->wake, &w->lock);
            continue;
        }

        /* Copy the task out; its slot stays reserved until we advance */
        TpTask task = w->task_list[w->start_ptr];
        tp_mutex_unlock(&w->lock);

        bool finished = false;
        if (task.execute == NULL || task.repeat_count <= 0) {
            /* Empty slot or already-done task: release its load and move on */
            atomic_fetch_sub(&w->num_tasks, task.weight);
            finished = true;
        } else {
            while (task.repeat_count > 0 && atomic_load(&w->running)) {
                task.execute(task.context);
                task.repeat_count--;
            }

            if (task.repeat_count <= 0) {
                if (task.on_complete) {
                    task.on_complete(task.context);
                }
                atomic_fetch_sub(&w->num_tasks, task.weight);
                finished = true;
            }
        }

        tp_mutex_lock(&w->lock);
        if (finished) {
            memset(&w->task_list[w->start_ptr], 0, sizeof(TpTask));
            w->start_ptr = (w->start_ptr + 1) % w->task_list_size;
        }
    }
    tp_mutex_unlock(&w->lock);

    TP_LOG(&w->pool->config, "[worker %d] Exiting\n", w->worker_id);
    return NULL;
}
/* }}} */

/* {{{ pool_free
 * Frees a pool whose worker threads are not running (never started or joined).
 * initialized: how many workers had their lock, cond and ring set up. */
static void pool_free(TpPool* pool, int initialized) {
    for (int i = 0; i < initialized; i++) {
        tp_mutex_destroy(&pool->workers[i].lock);
        tp_cond_destroy(&pool->workers[i].wake);
        free(pool->workers[i].task_list);
    }
    free(pool->workers);
    free(pool);
}
/* }}} */

/* {{{ pool_stop_and_join
 * Signals the first `started` workers to stop, wakes them, and joins them. */
static void pool_stop_and_join(TpPool* pool, int started) {
    atomic_store(&pool->running, false);
    for (int i = 0; i < started; i++) {
        TpWorker* w = &pool->workers[i];
        tp_mutex_lock(&w->lock);
        atomic_store(&w->running, false);
        tp_cond_broadcast(&w->wake);
        tp_mutex_unlock(&w->lock);
    }

    for (int i = 0; i < started; i++) {
        tp_thread_join(pool->workers[i].thread);
        TP_LOG(&pool->config, "[threadpool] Worker %d joined\n", i);
    }
}
/* }}} */

/* {{{ tp_pool_create
 * Creates a worker pool with the specified number of workers.
 * If worker_count is 0, auto-detects CPU cores.
 * If config is NULL, uses defaults.
 * Returns NULL if memory runs out or a worker thread cannot be started; in
 * that case any workers already started are stopped and joined first. */
TpPool* tp_pool_create(TpConfig* config, int worker_count) {
    /* Use defaults if no config provided */
    TpConfig cfg = config ? *config : tp_config_default();

    /* A ring needs one empty slot, so it must have room for at least two */
    if (cfg.task_list_size < 2) {
        TP_LOG(&cfg, "[threadpool] task_list_size %zu too small, need at least 2\n",
               cfg.task_list_size);
        return NULL;
    }

    /* Auto-detect CPU cores if not specified */
    if (worker_count <= 0) {
        worker_count = tp_cpu_count();
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
        w->start_ptr = 0;
        w->end_ptr = 0;
        atomic_store(&w->num_tasks, 0);
        atomic_store(&w->running, true);

        /* Allocate task ring buffer */
        w->task_list = calloc(cfg.task_list_size, sizeof(TpTask));
        if (!w->task_list) {
            TP_LOG(&pool->config, "[threadpool] Failed to allocate task list for worker %d\n", i);
            pool_free(pool, i);
            return NULL;
        }

        tp_mutex_init(&w->lock);
        tp_cond_init(&w->wake);
    }

    /* Spawn worker threads */
    for (int i = 0; i < worker_count; i++) {
        int result = tp_thread_create(&pool->workers[i].thread,
                                      tp_worker_loop, &pool->workers[i]);
        if (result != 0) {
            TP_LOG(&pool->config, "[threadpool] Failed to create worker %d\n", i);
            pool_stop_and_join(pool, i);
            pool_free(pool, worker_count);
            return NULL;
        }
        TP_LOG(&pool->config, "[threadpool] Worker %d spawned\n", i);
    }

    return pool;
}
/* }}} */

/* {{{ tp_pool_destroy
 * Signals workers to stop, joins all threads, frees resources.
 * Tasks still queued are dropped without running; a task running now gets to
 * finish its current run. */
void tp_pool_destroy(TpPool* pool) {
    if (!pool) return;

    TP_LOG(&pool->config, "[threadpool] Destroying pool...\n");

    pool_stop_and_join(pool, pool->count);
    pool_free(pool, pool->count);

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
