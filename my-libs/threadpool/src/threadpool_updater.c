/*
 * Threadpool Updater Module Implementation
 *
 * Provides self-evaluating task distribution with adaptive helper spawning.
 * See threadpool_updater.h for API documentation.
 */

#include "threadpool_updater.h"
#include "threadpool_config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>

/* Default configuration values */
#define DEFAULT_TARGET_TICK_US 10000            /* 10ms = 100Hz */
#define DEFAULT_CONTINUATION_THRESHOLD_US 5000  /* 50% of target */
#define DEFAULT_OVERLOAD_THRESHOLD_US 5000      /* Same as continuation */

/* Global active updater count - for dynamic scaling decisions */
static atomic_uint g_active_updater_count = 0;

/* Forward declarations for internal functions */
static void primary_updater_execute(void* arg);
static void helper_updater_execute(void* arg);
static void primary_updater_on_complete(void* arg);
static void helper_updater_on_complete(void* arg);

/* {{{ tp_updater_config_default
 * Returns default configuration for updater module. */
TpUpdaterConfig tp_updater_config_default(void) {
    TpUpdaterConfig config = {
        .target_tick_us = DEFAULT_TARGET_TICK_US,
        .continuation_threshold_us = DEFAULT_CONTINUATION_THRESHOLD_US,
        .overload_threshold_us = DEFAULT_OVERLOAD_THRESHOLD_US,
        .log_fn = NULL  /* No logging by default */
    };
    return config;
}
/* }}} */

/* {{{ tp_updater_create
 * Creates a primary updater context.
 * Returns NULL on allocation failure. */
TpUpdaterContext* tp_updater_create(TpPool* pool,
                                     TpUpdaterConfig* config,
                                     bool (*get_pending_tasks)(void*, TpTask**, size_t*),
                                     void* user_data) {
    if (!pool || !get_pending_tasks) {
        fprintf(stderr, "[threadpool_updater] Invalid arguments\n");
        return NULL;
    }

    TpUpdaterContext* ctx = calloc(1, sizeof(TpUpdaterContext));
    if (!ctx) {
        fprintf(stderr, "[threadpool_updater] Failed to allocate context\n");
        return NULL;
    }

    ctx->pool = pool;
    ctx->get_pending_tasks = get_pending_tasks;
    ctx->user_data = user_data;
    ctx->partition_start = 0;
    ctx->partition_end = 0;  /* Set by callback if needed */
    ctx->last_tick_duration_us = 0;
    ctx->is_primary = true;
    ctx->is_allocated = true;

    /* Store configuration */
    if (config) {
        ctx->config = *config;
    } else {
        ctx->config = tp_updater_config_default();
    }

    if (ctx->config.log_fn) {
        ctx->config.log_fn("[threadpool_updater] Created context (target: %lu us)\n",
                           ctx->config.target_tick_us);
    }

    return ctx;
}
/* }}} */

/* {{{ tp_updater_destroy
 * Destroys an updater context. */
void tp_updater_destroy(TpUpdaterContext* ctx) {
    if (ctx && ctx->is_allocated) {
        free(ctx);
    }
}
/* }}} */

/* {{{ tp_updater_start
 * Starts the primary updater as a worker task.
 * Uses INT16_MAX for essentially infinite execution. */
void tp_updater_start(TpUpdaterContext* ctx) {
    if (!ctx || !ctx->pool) return;

    TpWorker* target = tp_find_least_busy(ctx->pool);
    if (!target) return;

    /* Increment active updater count */
    atomic_fetch_add(&g_active_updater_count, 1);

    TpTask task = {
        .execute = primary_updater_execute,
        .on_complete = primary_updater_on_complete,
        .context = ctx,
        .weight = TP_WEIGHT_UPDATER,
        .repeat_count = INT16_MAX  /* Run ~32K times then re-evaluate */
    };

    tp_task_append(target, &task);

    if (ctx->config.log_fn) {
        ctx->config.log_fn("[threadpool_updater] Primary started on worker %d (active: %u)\n",
                           target->worker_id, atomic_load(&g_active_updater_count));
    }
}
/* }}} */

/* {{{ primary_updater_execute
 * Main execution function for the primary updater.
 * Distributes tasks to workers and spawns helpers if overloaded. */
static void primary_updater_execute(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx || !ctx->get_pending_tasks) return;

    uint64_t start = tp_get_timestamp_us();

    /* Get pending tasks from callback */
    TpTask* pending = NULL;
    size_t count = 0;
    if (!ctx->get_pending_tasks(ctx->user_data, &pending, &count) || count == 0) {
        /* No tasks available - very brief yield to avoid busy-wait */
        usleep(100);  /* 0.1ms */
        ctx->last_tick_duration_us = 0;
        return;
    }

    /* Distribute all tasks to workers */
    for (size_t i = 0; i < count; i++) {
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (target) {
            tp_task_append(target, &pending[i]);
        }
    }

    uint64_t elapsed = tp_get_timestamp_us() - start;
    ctx->last_tick_duration_us = elapsed;

    /* Check for overload - if we took longer than target tick time */
    if (elapsed > ctx->config.target_tick_us && count > 1) {
        if (ctx->config.log_fn) {
            ctx->config.log_fn("[threadpool_updater] Overload detected: %lu us (target: %lu us)\n",
                               elapsed, ctx->config.target_tick_us);
        }
    }
}
/* }}} */

/* {{{ helper_updater_execute
 * Execution function for helper updaters.
 * Distributes a partition of tasks and records timing. */
static void helper_updater_execute(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx || !ctx->get_pending_tasks) return;

    uint64_t start = tp_get_timestamp_us();

    /* Get pending tasks */
    TpTask* pending = NULL;
    size_t count = 0;
    if (!ctx->get_pending_tasks(ctx->user_data, &pending, &count)) {
        ctx->last_tick_duration_us = 0;
        return;
    }

    /* Only process our partition */
    size_t start_idx = ctx->partition_start;
    size_t end_idx = ctx->partition_end;
    if (end_idx > count) end_idx = count;
    if (start_idx >= end_idx) {
        ctx->last_tick_duration_us = 0;
        return;
    }

    /* Distribute partition to workers */
    for (size_t i = start_idx; i < end_idx; i++) {
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (target) {
            tp_task_append(target, &pending[i]);
        }
    }

    ctx->last_tick_duration_us = tp_get_timestamp_us() - start;
}
/* }}} */

/* {{{ helper_updater_on_complete
 * Self-evaluation callback for helper updaters.
 * If last tick took > continuation threshold, recreate. Otherwise, exit. */
static void helper_updater_on_complete(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx) return;

    if (ctx->last_tick_duration_us > ctx->config.continuation_threshold_us) {
        /* Still under load - recreate task on least-busy worker */
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (target) {
            TpTask task = {
                .execute = helper_updater_execute,
                .on_complete = helper_updater_on_complete,
                .context = ctx,
                .weight = TP_WEIGHT_UPDATER,
                .repeat_count = 1
            };
            tp_task_append(target, &task);

            if (ctx->config.log_fn) {
                ctx->config.log_fn("[threadpool_updater] Helper continuing (last: %lu us)\n",
                                   ctx->last_tick_duration_us);
            }
        }
    } else {
        /* Load decreased - exit and free context */
        if (ctx->config.log_fn) {
            ctx->config.log_fn("[threadpool_updater] Helper exiting (last: %lu us <= %lu us threshold)\n",
                               ctx->last_tick_duration_us, ctx->config.continuation_threshold_us);
        }

        /* Decrement active count */
        atomic_fetch_sub(&g_active_updater_count, 1);

        if (ctx->is_allocated) {
            free(ctx);
        }
    }
}
/* }}} */

/* {{{ primary_updater_on_complete
 * Self-evaluation callback for primary updaters.
 * Called when repeat_count reaches 0. Implements dynamic scaling. */
static void primary_updater_on_complete(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx || !ctx->pool) return;

    unsigned int active = atomic_load(&g_active_updater_count);

    if (active <= 1) {
        /* Last updater - must keep running, re-spawn with INT16_MAX */
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (target) {
            TpTask task = {
                .execute = primary_updater_execute,
                .on_complete = primary_updater_on_complete,
                .context = ctx,
                .weight = TP_WEIGHT_UPDATER,
                .repeat_count = INT16_MAX
            };
            tp_task_append(target, &task);

            if (ctx->config.log_fn) {
                ctx->config.log_fn("[threadpool_updater] Re-spawned (only %u active, last: %lu us)\n",
                                   active, ctx->last_tick_duration_us);
            }
        }
    } else if (ctx->last_tick_duration_us > ctx->config.overload_threshold_us) {
        /* Multiple updaters and heavy load - spawn replacement, terminate this one */
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (target) {
            TpTask task = {
                .execute = primary_updater_execute,
                .on_complete = primary_updater_on_complete,
                .context = ctx,
                .weight = TP_WEIGHT_UPDATER,
                .repeat_count = INT16_MAX
            };
            tp_task_append(target, &task);

            if (ctx->config.log_fn) {
                ctx->config.log_fn("[threadpool_updater] Spawned replacement on worker %d (last: %lu us > %lu us)\n",
                                   target->worker_id, ctx->last_tick_duration_us,
                                   ctx->config.overload_threshold_us);
            }
        }

        /* Decrement count - this updater is terminating */
        atomic_fetch_sub(&g_active_updater_count, 1);
    } else {
        /* Multiple updaters and light load - terminate to shrink pool */
        atomic_fetch_sub(&g_active_updater_count, 1);

        if (ctx->config.log_fn) {
            ctx->config.log_fn("[threadpool_updater] Terminating (active: %u, last: %lu us <= %lu us)\n",
                               active - 1, ctx->last_tick_duration_us,
                               ctx->config.overload_threshold_us);
        }

        /* Free context if dynamically allocated */
        if (ctx->is_allocated) {
            free(ctx);
        }
    }
}
/* }}} */

/* {{{ tp_updater_spawn_helper
 * Spawns a helper updater to handle a partition of the workload. */
void tp_updater_spawn_helper(TpUpdaterContext* primary,
                              size_t partition_start,
                              size_t partition_end) {
    if (!primary || !primary->pool) return;

    /* Allocate helper context */
    TpUpdaterContext* helper = calloc(1, sizeof(TpUpdaterContext));
    if (!helper) {
        fprintf(stderr, "[threadpool_updater] Failed to allocate helper context\n");
        return;
    }

    /* Copy settings from primary */
    helper->pool = primary->pool;
    helper->get_pending_tasks = primary->get_pending_tasks;
    helper->user_data = primary->user_data;
    helper->partition_start = partition_start;
    helper->partition_end = partition_end;
    helper->last_tick_duration_us = 0;
    helper->is_primary = false;
    helper->is_allocated = true;
    helper->config = primary->config;

    /* Increment active count */
    atomic_fetch_add(&g_active_updater_count, 1);

    /* Submit as worker task */
    TpWorker* target = tp_find_least_busy(primary->pool);
    if (!target) {
        atomic_fetch_sub(&g_active_updater_count, 1);
        free(helper);
        return;
    }

    TpTask task = {
        .execute = helper_updater_execute,
        .on_complete = helper_updater_on_complete,
        .context = helper,
        .weight = TP_WEIGHT_UPDATER,
        .repeat_count = 1
    };

    tp_task_append(target, &task);

    if (primary->config.log_fn) {
        primary->config.log_fn("[threadpool_updater] Helper spawned for partition [%zu, %zu) on worker %d\n",
                               partition_start, partition_end, target->worker_id);
    }
}
/* }}} */

/* {{{ tp_updater_get_active_count
 * Returns the global count of active updaters. */
unsigned int tp_updater_get_active_count(void) {
    return atomic_load(&g_active_updater_count);
}
/* }}} */

/* {{{ tp_updater_get_last_tick_us
 * Returns the last tick duration for an updater. */
uint64_t tp_updater_get_last_tick_us(TpUpdaterContext* ctx) {
    return ctx ? ctx->last_tick_duration_us : 0;
}
/* }}} */
