/*
 * Threadpool Updater Module
 *
 * Optional module for adaptive task distribution with self-regulating helpers.
 * Implements the self-evaluating task pattern:
 *
 * 1. Updater is a worker task, not a special thread type
 * 2. When repeat_count reaches 0, updater evaluates its own timing
 * 3. If last tick > 50% of target: recreate (might land on different worker)
 * 4. If last tick <= 50% of target: don't recreate (exit gracefully)
 *
 * This creates natural load-responsive scaling without explicit thread management.
 */

#ifndef THREADPOOL_UPDATER_H
#define THREADPOOL_UPDATER_H

#include "threadpool.h"
#include <stdbool.h>
#include <stdint.h>

/* {{{ TpUpdaterConfig
 * Configuration for updater module. */
typedef struct tp_updater_config {
    uint64_t target_tick_us;            /* Default: 10000 (10ms = 100Hz) */
    uint64_t continuation_threshold_us; /* Default: 5000 (50% of target) */
    uint64_t overload_threshold_us;     /* Default: 5000 */
    void (*log_fn)(const char* fmt, ...);  /* Optional logging callback */
} TpUpdaterConfig;
/* }}} */

/* {{{ TpUpdaterContext
 * Context for self-evaluating updater tasks.
 *
 * Dynamic scaling: When repeat_count reaches 0, updater evaluates:
 * - If only 1 updater active: re-spawn with INT16_MAX repeat_count
 * - If multiple updaters and last update > threshold: spawn replacement, terminate
 * - Otherwise: terminate (allow pool to shrink)
 */
typedef struct tp_updater_context {
    TpPool* pool;

    /* Task source callback
     * Returns true if new tasks are available, populates out and count
     * user_data is the void* passed to tp_updater_create() */
    bool (*get_pending_tasks)(void* user_data, TpTask** out, size_t* count);

    /* User-defined data for the callback */
    void* user_data;

    /* Partition this updater handles (for helper splitting) */
    size_t partition_start;
    size_t partition_end;

    /* Timing measurement */
    uint64_t last_tick_duration_us;

    /* Is this the primary updater (runs forever) or a helper (runs once)? */
    bool is_primary;

    /* For helper cleanup: was this context dynamically allocated? */
    bool is_allocated;

    /* Configuration thresholds */
    TpUpdaterConfig config;
} TpUpdaterContext;
/* }}} */

/* {{{ Configuration */

/* Get default updater configuration */
TpUpdaterConfig tp_updater_config_default(void);

/* }}} */

/* {{{ Lifecycle */

/* Create an updater context (primary updater)
 * pool: Worker pool to distribute tasks to
 * config: Configuration (NULL = use defaults)
 * get_pending_tasks: Callback to get tasks to distribute
 * user_data: Passed to get_pending_tasks callback
 *
 * Returns NULL on allocation failure */
TpUpdaterContext* tp_updater_create(TpPool* pool,
                                     TpUpdaterConfig* config,
                                     bool (*get_pending_tasks)(void*, TpTask**, size_t*),
                                     void* user_data);

/* Destroy an updater context */
void tp_updater_destroy(TpUpdaterContext* ctx);

/* }}} */

/* {{{ Control */

/* Start the primary updater as a worker task
 * Uses INT16_MAX for essentially infinite execution */
void tp_updater_start(TpUpdaterContext* ctx);

/* }}} */

/* {{{ Statistics */

/* Get number of active updaters (global across all pools) */
unsigned int tp_updater_get_active_count(void);

/* Get last tick duration for specific updater */
uint64_t tp_updater_get_last_tick_us(TpUpdaterContext* ctx);

/* }}} */

/* {{{ Advanced - Helper Spawning */

/* Spawn a helper updater to handle part of the workload
 * Typically called by primary when overloaded
 *
 * partition_start, partition_end: Range of tasks for this helper */
void tp_updater_spawn_helper(TpUpdaterContext* primary,
                              size_t partition_start,
                              size_t partition_end);

/* }}} */

#endif /* THREADPOOL_UPDATER_H */
