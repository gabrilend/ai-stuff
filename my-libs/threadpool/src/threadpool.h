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

#include <pthread.h>
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
 * A worker thread with a ring buffer of tasks. */
typedef struct tp_worker {
    pthread_t thread;
    int worker_id;

    /* Task ring buffer */
    TpTask* task_list;
    size_t task_list_size;
    size_t start_ptr;           /* Current execution position */
    size_t end_ptr;             /* Next write position */

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

/* Append a task to a worker's ring buffer
 * Returns false if buffer is full */
bool tp_task_append(TpWorker* w, TpTask* task);

/* Find the worker with lowest num_tasks */
TpWorker* tp_find_least_busy(TpPool* pool);

/* Find least busy worker, excluding a specific worker ID
 * Used by updater to avoid queueing tasks behind itself */
TpWorker* tp_find_least_busy_excluding(TpPool* pool, int exclude_id);

/* }}} */

/* {{{ Function Declarations - Built-in Tasks */

/* Default task that sleeps for one tick */
void tp_sleep_task(void* context);

/* Task that compacts the ring buffer (internal use) */
void tp_relocate_task(void* context);

/* }}} */

/* {{{ Function Declarations - Utilities */

/* Get current timestamp in microseconds */
uint64_t tp_get_timestamp_us(void);

/* Worker thread entry point (internal, exposed for advanced use) */
void* tp_worker_loop(void* arg);

/* }}} */

#endif /* THREADPOOL_H */
