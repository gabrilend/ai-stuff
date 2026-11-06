/*
 * Threadpool Library - Core Module
 *
 * General-purpose thread pool with ring buffer task lists.
 * Extracted from world-edit-to-execute render system for reuse.
 *
 * Features:
 * - Worker count scales to CPU cores (or user-specified)
 * - Load balancing via weighted task counts
 * - Ring buffer task lists with automatic relocation
 * - Optional logging via callback (NULL = silent, minimal overhead)
 *
 * Usage:
 *   TpConfig cfg = tp_config_default();
 *   cfg.log_fn = my_logger;  // optional
 *   TpPool* pool = tp_pool_create(&cfg, 0);  // 0 = auto-detect cores
 *
 *   TpTask task = { .execute = my_func, .context = data, .weight = TP_WEIGHT_LIGHT };
 *   TpWorker* w = tp_find_least_busy(pool);
 *   tp_task_append(w, &task);
 *
 *   tp_pool_destroy(pool);
 */

#ifndef THREADPOOL_H
#define THREADPOOL_H

#include "threadpool_platform.h"
#include <stdbool.h>
#include <stdatomic.h>
#include <stdint.h>

#include "threadpool_config.h"

/* {{{ TpTask
 * A task is a function pointer with context and metadata.
 * Workers execute these from their ring buffer. */
typedef struct tp_task {
    /* Function to execute */
    void (*execute)(void* context);

    /* Optional callback when repeat_count reaches 0 */
    void (*on_complete)(void* context);

    /* Task-specific data passed to execute/on_complete */
    void* context;

    /* Cost estimate for load balancing (higher = heavier) */
    uint16_t weight;

    /* Repeat behavior:
     *  N > 0 = run N more times then call on_complete
     *  0 = already completed (skip this slot)
     *  N < 0 = treat as 0 (completed), -1 does NOT mean infinite
     * Use INT16_MAX (32767) for "essentially infinite" execution */
    int16_t repeat_count;
} TpTask;
/* }}} */

/* Forward declaration */
struct tp_pool;

/* {{{ TpWorker
 * A worker thread with a ring buffer of tasks.
 *
 * Any thread may append to any worker (the main thread, an updater running on
 * another worker, or an on_complete running on this same worker). The ring's
 * positions are guarded by `lock`; the worker copies the task at start_ptr out
 * under the lock and runs the copy without holding it, so a task may append to
 * its own worker without deadlocking. The slot at start_ptr stays reserved
 * until the task finishes, so a producer can never overwrite a running task.
 * An idle worker sleeps on `wake` instead of polling. */
typedef struct tp_worker {
    tp_thread_t thread;
    int worker_id;

    /* Task ring buffer (holds task_list_size - 1 tasks) */
    TpTask* task_list;
    size_t task_list_size;
    size_t start_ptr;           /* Current execution position (guarded by lock) */
    size_t end_ptr;             /* Next write position (guarded by lock) */

    tp_mutex_t lock;            /* Guards task_list, start_ptr, end_ptr */
    tp_cond_t wake;             /* Signalled on append and on shutdown */

    /* Load balancing: weighted sum of pending task weights */
    atomic_uint num_tasks;

    /* Shutdown flag */
    atomic_bool running;

    /* Back-reference to pool */
    struct tp_pool* pool;
} TpWorker;
/* }}} */

/* {{{ TpPool
 * Manages all worker threads. */
typedef struct tp_pool {
    TpWorker* workers;
    int count;

    /* Global shutdown flag */
    atomic_bool running;

    /* Configuration (stored as copy for persistence) */
    TpConfig config;
} TpPool;
/* }}} */

/* {{{ Function Declarations - Pool Lifecycle */

/* Create a worker pool with specified count (0 = auto-detect CPU cores)
 * Pass NULL for config to use defaults. */
TpPool* tp_pool_create(TpConfig* config, int worker_count);

/* Destroy pool, join all threads, free resources */
void tp_pool_destroy(TpPool* pool);

/* Get total weighted load across all workers */
unsigned int tp_pool_get_load(TpPool* pool);

/* }}} */

/* {{{ Function Declarations - Task Management */

/* Append a task to a worker's ring buffer (thread-safe, any thread)
 * The task is copied, so the caller's TpTask may live on the stack.
 * Returns false if the buffer is full or w/task is NULL. */
bool tp_task_append(TpWorker* w, TpTask* task);

/* Number of tasks in a worker's ring, counting the one running now */
size_t tp_worker_queued(TpWorker* w);

/* Find the worker with lowest num_tasks */
TpWorker* tp_find_least_busy(TpPool* pool);

/* Find least busy worker, excluding a specific worker ID
 * Used by updater to avoid queueing tasks behind itself */
TpWorker* tp_find_least_busy_excluding(TpPool* pool, int exclude_id);

/* }}} */

/* {{{ Function Declarations - Built-in Tasks */

/* Default task that sleeps for one tick */
void tp_sleep_task(void* context);

/* Compact a worker's ring buffer: drops queued tp_sleep_task placeholders that
 * have not started and closes the gaps they leave. context is the TpWorker*.
 * Safe to call directly from any thread or to queue as a task. The ring wraps
 * on its own, so nothing needs to call this for the buffer to keep working. */
void tp_relocate_task(void* context);

/* }}} */

/* {{{ Function Declarations - Utilities */

/* Get current timestamp in microseconds (monotonic; same as tp_time_us) */
uint64_t tp_get_timestamp_us(void);

/* Worker thread entry point (internal, exposed for advanced use) */
void* tp_worker_loop(void* arg);

/* }}} */

#endif /* THREADPOOL_H */
