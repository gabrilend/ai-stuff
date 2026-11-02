/*
 * Threadpool Updater Module Implementation
 *
 * Provides self-evaluating task distribution with adaptive helper spawning.
 * See threadpool_updater.h for API documentation.
 */

#include "threadpool_updater.h"
#include "threadpool_config.h"
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

/* Default configuration values */
#define DEFAULT_TARGET_TICK_US 10000            /* 10ms = 100Hz */
#define DEFAULT_CONTINUATION_THRESHOLD_US 5000  /* 50% of target */
#define DEFAULT_OVERLOAD_THRESHOLD_US 5000      /* Same as continuation */

/* Conditional logging through the context's config */
#define UPD_LOG(ctx, fmt, ...) TP_LOG(&(ctx)->config, fmt, ##__VA_ARGS__)

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

/* {{{ updater_init
 * Fills a freshly calloc'd context. */
static void updater_init(TpUpdaterContext* ctx, TpPool* pool, TpUpdaterConfig config,
                         bool (*get_pending_tasks)(void*, TpTask**, size_t*),
                         void* user_data) {
    ctx->pool = pool;
    ctx->get_pending_tasks = get_pending_tasks;
    ctx->user_data = user_data;
    ctx->partition_start = 0;
    ctx->partition_end = 0;
    ctx->config = config;
    ctx->parent = NULL;
    atomic_init(&ctx->last_tick_duration_us, 0);
    atomic_init(&ctx->stop_requested, false);
    atomic_init(&ctx->task_live, false);
    atomic_init(&ctx->live_helpers, 0);
}
/* }}} */

/* {{{ tp_updater_create
 * Creates a primary updater context, owned by the caller.
 * Returns NULL on bad arguments or allocation failure. */
TpUpdaterContext* tp_updater_create(TpPool* pool,
                                     TpUpdaterConfig* config,
                                     bool (*get_pending_tasks)(void*, TpTask**, size_t*),
                                     void* user_data) {
    TpUpdaterConfig cfg = config ? *config : tp_updater_config_default();

    if (!pool || !get_pending_tasks) {
        if (cfg.log_fn) cfg.log_fn("[threadpool_updater] Invalid arguments\n");
        return NULL;
    }

    TpUpdaterContext* ctx = calloc(1, sizeof(TpUpdaterContext));
    if (!ctx) {
        if (cfg.log_fn) cfg.log_fn("[threadpool_updater] Failed to allocate context\n");
        return NULL;
    }

    updater_init(ctx, pool, cfg, get_pending_tasks, user_data);
    ctx->is_primary = true;
    ctx->is_allocated = false;  /* The caller frees it with tp_updater_destroy() */

    UPD_LOG(ctx, "[threadpool_updater] Created context (target: %" PRIu64 " us)\n",
            ctx->config.target_tick_us);

    return ctx;
}
/* }}} */

/* {{{ tp_updater_destroy
 * Frees a primary updater context. See the header for when this is safe. */
void tp_updater_destroy(TpUpdaterContext* ctx) {
    if (!ctx || !ctx->is_primary) return;
    free(ctx);
}
/* }}} */

/* {{{ append_updater_task
 * Queues an updater task on the least busy worker. Returns false if no worker
 * would take it (no workers, or every candidate's ring is full). */
static bool append_updater_task(TpUpdaterContext* ctx, int16_t repeat_count,
                                TpWorker** out_worker) {
    TpTask task = {
        .execute = ctx->is_primary ? primary_updater_execute : helper_updater_execute,
        .on_complete = ctx->is_primary ? primary_updater_on_complete : helper_updater_on_complete,
        .context = ctx,
        .weight = TP_WEIGHT_UPDATER,
        .repeat_count = repeat_count
    };

    TpWorker* target = tp_find_least_busy(ctx->pool);
    if (!target || !tp_task_append(target, &task)) {
        UPD_LOG(ctx, "[threadpool_updater] Could not queue updater task\n");
        return false;
    }
    if (out_worker) *out_worker = target;
    return true;
}
/* }}} */

/* {{{ tp_updater_start
 * Starts the primary updater as a worker task.
 * Uses INT16_MAX for essentially infinite execution. */
bool tp_updater_start(TpUpdaterContext* ctx) {
    if (!ctx || !ctx->pool || !ctx->is_primary) return false;
    if (atomic_load(&ctx->task_live)) return false;  /* Already running */

    atomic_store(&ctx->stop_requested, false);
    atomic_store(&ctx->task_live, true);
    atomic_fetch_add(&g_active_updater_count, 1);

    TpWorker* target = NULL;
    if (!append_updater_task(ctx, INT16_MAX, &target)) {
        atomic_fetch_sub(&g_active_updater_count, 1);
        atomic_store(&ctx->task_live, false);
        return false;
    }

    UPD_LOG(ctx, "[threadpool_updater] Primary started on worker %d (active: %u)\n",
            target->worker_id, atomic_load(&g_active_updater_count));
    return true;
}
/* }}} */

/* {{{ tp_updater_stop
 * Asks the primary and its helpers to stop, and waits until they are gone.
 * A stopped primary's remaining runs are no-ops, so this returns quickly
 * unless the updater task is queued behind slow work. */
void tp_updater_stop(TpUpdaterContext* ctx) {
    if (!ctx || !ctx->is_primary) return;

    atomic_store(&ctx->stop_requested, true);
    while (atomic_load(&ctx->task_live) || atomic_load(&ctx->live_helpers) > 0) {
        tp_sleep_us(1000);  /* 1ms */
    }

    UPD_LOG(ctx, "[threadpool_updater] Stopped (active: %u)\n",
            atomic_load(&g_active_updater_count));
}
/* }}} */

/* {{{ primary_updater_execute
 * Main execution function for the primary updater.
 * Distributes tasks to workers and logs when overloaded. */
static void primary_updater_execute(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx || !ctx->get_pending_tasks) return;
    if (atomic_load(&ctx->stop_requested)) return;  /* Drain quickly */

    uint64_t start = tp_get_timestamp_us();

    /* Get pending tasks from callback */
    TpTask* pending = NULL;
    size_t count = 0;
    if (!ctx->get_pending_tasks(ctx->user_data, &pending, &count) || count == 0) {
        /* No tasks available - very brief yield to avoid busy-wait */
        tp_sleep_us(100);  /* 0.1ms */
        atomic_store(&ctx->last_tick_duration_us, 0);
        return;
    }

    /* Distribute all tasks to workers */
    for (size_t i = 0; i < count; i++) {
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (!target || !tp_task_append(target, &pending[i])) {
            UPD_LOG(ctx, "[threadpool_updater] Dropped task %zu of %zu: no room\n", i, count);
        }
    }

    uint64_t elapsed = tp_get_timestamp_us() - start;
    atomic_store(&ctx->last_tick_duration_us, elapsed);

    /* Check for overload - if we took longer than target tick time */
    if (elapsed > ctx->config.target_tick_us && count > 1) {
        UPD_LOG(ctx, "[threadpool_updater] Overload detected: %" PRIu64 " us (target: %" PRIu64 " us)\n",
                elapsed, ctx->config.target_tick_us);
    }
}
/* }}} */

/* {{{ helper_updater_execute
 * Execution function for helper updaters.
 * Distributes a partition of tasks and records timing. */
static void helper_updater_execute(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx || !ctx->get_pending_tasks) return;

    if (ctx->parent && atomic_load(&ctx->parent->stop_requested)) {
        atomic_store(&ctx->last_tick_duration_us, 0);
        return;
    }

    uint64_t start = tp_get_timestamp_us();

    /* Get pending tasks */
    TpTask* pending = NULL;
    size_t count = 0;
    if (!ctx->get_pending_tasks(ctx->user_data, &pending, &count)) {
        atomic_store(&ctx->last_tick_duration_us, 0);
        return;
    }

    /* Only process our partition */
    size_t start_idx = ctx->partition_start;
    size_t end_idx = ctx->partition_end;
    if (end_idx > count) end_idx = count;
    if (start_idx >= end_idx) {
        atomic_store(&ctx->last_tick_duration_us, 0);
        return;
    }

    /* Distribute partition to workers */
    for (size_t i = start_idx; i < end_idx; i++) {
        TpWorker* target = tp_find_least_busy(ctx->pool);
        if (!target || !tp_task_append(target, &pending[i])) {
            UPD_LOG(ctx, "[threadpool_updater] Helper dropped task %zu: no room\n", i);
        }
    }

    atomic_store(&ctx->last_tick_duration_us, tp_get_timestamp_us() - start);
}
/* }}} */

/* {{{ helper_exit
 * A helper leaves: counts drop, the parent learns it is gone, the context is
 * freed. The parent is not touched after its live_helpers count drops, since
 * tp_updater_stop() may return and the parent be freed right then. */
static void helper_exit(TpUpdaterContext* ctx) {
    atomic_fetch_sub(&g_active_updater_count, 1);
    if (ctx->parent) {
        atomic_fetch_sub(&ctx->parent->live_helpers, 1);
    }
    free(ctx);
}
/* }}} */

/* {{{ helper_updater_on_complete
 * Self-evaluation callback for helper updaters.
 * If last tick took > continuation threshold, recreate. Otherwise, exit. */
static void helper_updater_on_complete(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx) return;

    uint64_t last = atomic_load(&ctx->last_tick_duration_us);
    bool stopping = ctx->parent && atomic_load(&ctx->parent->stop_requested);

    if (!stopping && last > ctx->config.continuation_threshold_us) {
        /* Still under load - recreate task on least-busy worker */
        if (append_updater_task(ctx, 1, NULL)) {
            UPD_LOG(ctx, "[threadpool_updater] Helper continuing (last: %" PRIu64 " us)\n", last);
            return;
        }
    }

    /* Load decreased, stop requested, or no room to continue - exit */
    UPD_LOG(ctx, "[threadpool_updater] Helper exiting (last: %" PRIu64 " us, threshold: %" PRIu64 " us)\n",
            last, ctx->config.continuation_threshold_us);
    helper_exit(ctx);
}
/* }}} */

/* {{{ primary_end
 * The primary's task is over: drop it from the active count and mark it gone.
 * The context itself belongs to the caller and is not freed here. */
static void primary_end(TpUpdaterContext* ctx) {
    atomic_fetch_sub(&g_active_updater_count, 1);
    atomic_store(&ctx->task_live, false);
}
/* }}} */

/* {{{ primary_updater_on_complete
 * Self-evaluation callback for primary updaters.
 * Called when repeat_count reaches 0. Implements dynamic scaling. */
static void primary_updater_on_complete(void* arg) {
    TpUpdaterContext* ctx = (TpUpdaterContext*)arg;
    if (!ctx || !ctx->pool) return;

    if (atomic_load(&ctx->stop_requested)) {
        primary_end(ctx);
        return;
    }

    unsigned int active = atomic_load(&g_active_updater_count);
    uint64_t last = atomic_load(&ctx->last_tick_duration_us);

    if (active <= 1 || last > ctx->config.overload_threshold_us) {
        /* Last updater (must keep running), or still loaded: recreate on the
         * least busy worker. The count is unchanged - this updater lives on. */
        TpWorker* target = NULL;
        if (append_updater_task(ctx, INT16_MAX, &target)) {
            UPD_LOG(ctx, "[threadpool_updater] Re-spawned on worker %d (active: %u, last: %" PRIu64 " us)\n",
                    target->worker_id, active, last);
            return;
        }
        UPD_LOG(ctx, "[threadpool_updater] No room to re-spawn; primary ends\n");
        primary_end(ctx);
        return;
    }

    /* Multiple updaters and light load - terminate to shrink pool */
    UPD_LOG(ctx, "[threadpool_updater] Terminating (active: %u, last: %" PRIu64 " us <= %" PRIu64 " us)\n",
            active - 1, last, ctx->config.overload_threshold_us);
    primary_end(ctx);
}
/* }}} */

/* {{{ tp_updater_spawn_helper
 * Spawns a helper updater to handle a partition of the workload. */
void tp_updater_spawn_helper(TpUpdaterContext* primary,
                              size_t partition_start,
                              size_t partition_end) {
    if (!primary || !primary->pool || !primary->is_primary) return;
    if (atomic_load(&primary->stop_requested)) return;

    /* Allocate helper context */
    TpUpdaterContext* helper = calloc(1, sizeof(TpUpdaterContext));
    if (!helper) {
        UPD_LOG(primary, "[threadpool_updater] Failed to allocate helper context\n");
        return;
    }

    /* Copy settings from primary */
    updater_init(helper, primary->pool, primary->config,
                 primary->get_pending_tasks, primary->user_data);
    helper->partition_start = partition_start;
    helper->partition_end = partition_end;
    helper->is_primary = false;
    helper->is_allocated = true;
    helper->parent = primary;

    /* Count it before it can run, so a quick exit never drops below zero */
    atomic_fetch_add(&g_active_updater_count, 1);
    atomic_fetch_add(&primary->live_helpers, 1);

    TpWorker* target = NULL;
    if (!append_updater_task(helper, 1, &target)) {
        helper_exit(helper);
        return;
    }

    UPD_LOG(primary, "[threadpool_updater] Helper spawned for partition [%zu, %zu) on worker %d\n",
            partition_start, partition_end, target->worker_id);
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
    return ctx ? atomic_load(&ctx->last_tick_duration_us) : 0;
}
/* }}} */
