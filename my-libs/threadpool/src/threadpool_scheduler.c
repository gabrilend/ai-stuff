/*
 * Threadpool Scheduler Module Implementation
 *
 * Provides deferred task assignment based on absolute tick times.
 * See threadpool_scheduler.h for API documentation.
 */

#include "threadpool_scheduler.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Default configuration values */
#define DEFAULT_SCHEDULER_CAPACITY 1024
#define DEFAULT_TICK_US 16000          /* 16ms = 62.5 Hz */
#define MAX_SLEEP_US 3600000000ULL     /* One sleep never exceeds an hour */

/* Conditional logging through the scheduler's callback */
#define SCHED_LOG(sched, fmt, ...) \
    do { \
        if ((sched)->log_fn) { \
            (sched)->log_fn(fmt, ##__VA_ARGS__); \
        } \
    } while(0)

/* {{{ tp_scheduler_config_default
 * Returns default configuration for scheduler module. */
TpSchedulerConfig tp_scheduler_config_default(void) {
    TpSchedulerConfig config = {
        .capacity = DEFAULT_SCHEDULER_CAPACITY,
        .tick_us = DEFAULT_TICK_US,
        .log_fn = NULL  /* No logging by default */
    };
    return config;
}
/* }}} */

/* {{{ tp_scheduler_create
 * Creates a scheduler with specified configuration (NULL = defaults).
 * Returns NULL on allocation failure. */
TpScheduler* tp_scheduler_create(TpSchedulerConfig* config) {
    TpSchedulerConfig cfg = config ? *config : tp_scheduler_config_default();
    if (cfg.tick_us == 0) cfg.tick_us = DEFAULT_TICK_US;

    TpScheduler* sched = calloc(1, sizeof(TpScheduler));
    if (!sched) {
        if (cfg.log_fn) cfg.log_fn("[threadpool_scheduler] Failed to allocate scheduler\n");
        return NULL;
    }
    sched->log_fn = cfg.log_fn;
    sched->tick_us = cfg.tick_us;

    /* Allocate task array and the ready buffer that mirrors it, so get_ready
     * never has to allocate (calloc(0) may return NULL, so ask for at least 1) */
    size_t slots = cfg.capacity ? cfg.capacity : 1;
    sched->tasks = calloc(slots, sizeof(TpScheduledTask));
    sched->ready_buffer = calloc(slots, sizeof(TpTask));
    if (!sched->tasks || !sched->ready_buffer) {
        SCHED_LOG(sched, "[threadpool_scheduler] Failed to allocate task arrays\n");
        free(sched->tasks);
        free(sched->ready_buffer);
        free(sched);
        return NULL;
    }

    sched->capacity = cfg.capacity;
    sched->ready_buffer_size = slots;
    sched->count = 0;
    sched->add_generation = 0;
    atomic_store(&sched->running, true);

    /* Initialize synchronization primitives. The condition variable measures
     * its timeouts on the monotonic clock, the same clock sleep_ticks reads. */
    tp_mutex_init(&sched->lock);
    tp_cond_init(&sched->wake_signal);

    SCHED_LOG(sched, "[threadpool_scheduler] Created (capacity: %zu)\n", cfg.capacity);

    return sched;
}
/* }}} */

/* {{{ tp_scheduler_destroy
 * Destroys a scheduler and frees resources. */
void tp_scheduler_destroy(TpScheduler* sched) {
    if (!sched) return;

    atomic_store(&sched->running, false);

    tp_mutex_destroy(&sched->lock);
    tp_cond_destroy(&sched->wake_signal);

    free(sched->ready_buffer);
    free(sched->tasks);
    free(sched);
}
/* }}} */

/* {{{ tp_scheduler_add
 * Adds a task to the scheduler with specified delay.
 * Returns false if scheduler is full. */
bool tp_scheduler_add(TpScheduler* sched, TpTask* task, uint32_t ticks_delay) {
    if (!sched || !task) return false;

    tp_mutex_lock(&sched->lock);

    /* Check if scheduler is full */
    if (sched->count >= sched->capacity) {
        tp_mutex_unlock(&sched->lock);
        SCHED_LOG(sched, "[threadpool_scheduler] Scheduler full\n");
        return false;
    }

    /* Calculate absolute ready time */
    uint64_t current = atomic_load(&g_current_tick);
    uint64_t ready_at = current + ticks_delay;

    /* Add to array */
    sched->tasks[sched->count].task = *task;
    sched->tasks[sched->count].ready_at_tick = ready_at;
    sched->count++;
    sched->add_generation++;

    /* Wake any sleeping updater */
    tp_cond_broadcast(&sched->wake_signal);

    tp_mutex_unlock(&sched->lock);
    return true;
}
/* }}} */

/* {{{ tp_scheduler_remove_if
 * Removes all tasks matching the predicate. */
void tp_scheduler_remove_if(TpScheduler* sched,
                             bool (*predicate)(TpTask* task, void* user_data),
                             void* user_data) {
    if (!sched || !predicate) return;

    tp_mutex_lock(&sched->lock);

    size_t write_idx = 0;
    for (size_t read_idx = 0; read_idx < sched->count; read_idx++) {
        TpTask* task = &sched->tasks[read_idx].task;

        if (!predicate(task, user_data)) {
            /* Keep this task */
            if (write_idx != read_idx) {
                sched->tasks[write_idx] = sched->tasks[read_idx];
            }
            write_idx++;
        }
        /* Otherwise skip (remove) this task */
    }

    sched->count = write_idx;

    tp_mutex_unlock(&sched->lock);
}
/* }}} */

/* {{{ tp_scheduler_count
 * Returns the number of scheduled tasks. */
size_t tp_scheduler_count(TpScheduler* sched) {
    if (!sched) return 0;

    tp_mutex_lock(&sched->lock);
    size_t count = sched->count;
    tp_mutex_unlock(&sched->lock);

    return count;
}
/* }}} */

/* {{{ tp_scheduler_get_ready
 * Returns tasks where g_current_tick >= ready_at_tick.
 * This is the callback for updater's get_pending_tasks. */
bool tp_scheduler_get_ready(void* context, TpTask** out, size_t* count) {
    TpScheduler* sched = (TpScheduler*)context;
    if (!sched || !out || !count) return false;

    tp_mutex_lock(&sched->lock);

    uint64_t current = atomic_load(&g_current_tick);

    /* Count ready tasks */
    size_t ready_count = 0;
    for (size_t i = 0; i < sched->count; i++) {
        if (current >= sched->tasks[i].ready_at_tick) {
            ready_count++;
        }
    }

    /* If no tasks ready, return false */
    if (ready_count == 0) {
        tp_mutex_unlock(&sched->lock);
        *out = NULL;
        *count = 0;
        return false;
    }

    /* The ready buffer was sized to the capacity at creation, so it always
     * has room for every scheduled task */
    TpTask* ready_buffer = sched->ready_buffer;

    /* Copy ready tasks to buffer and remove from scheduler */
    size_t ready_idx = 0;
    size_t write_idx = 0;

    for (size_t read_idx = 0; read_idx < sched->count; read_idx++) {
        if (current >= sched->tasks[read_idx].ready_at_tick) {
            /* Task is ready - copy to buffer */
            ready_buffer[ready_idx++] = sched->tasks[read_idx].task;
        } else {
            /* Task not ready - keep in scheduler */
            if (write_idx != read_idx) {
                sched->tasks[write_idx] = sched->tasks[read_idx];
            }
            write_idx++;
        }
    }

    sched->count = write_idx;

    tp_mutex_unlock(&sched->lock);

    *out = ready_buffer;
    *count = ready_count;
    return true;
}
/* }}} */

/* {{{ tp_scheduler_earliest_ready_tick
 * Returns the earliest ready tick, or UINT64_MAX if no tasks scheduled. */
uint64_t tp_scheduler_earliest_ready_tick(TpScheduler* sched) {
    if (!sched) return UINT64_MAX;

    tp_mutex_lock(&sched->lock);

    if (sched->count == 0) {
        tp_mutex_unlock(&sched->lock);
        return UINT64_MAX;
    }

    /* Find minimum ready_at_tick */
    uint64_t earliest = sched->tasks[0].ready_at_tick;
    for (size_t i = 1; i < sched->count; i++) {
        if (sched->tasks[i].ready_at_tick < earliest) {
            earliest = sched->tasks[i].ready_at_tick;
        }
    }

    tp_mutex_unlock(&sched->lock);
    return earliest;
}
/* }}} */

/* {{{ tp_scheduler_sleep_ticks
 * Sleeps until earliest task or new task arrival.
 * Uses a timed condition-variable wait for interruptible sleep.
 * Loops over spurious wakeups; any add since the call began ends the sleep. */
void tp_scheduler_sleep_ticks(TpScheduler* sched, uint64_t ticks_to_sleep) {
    if (!sched || ticks_to_sleep == 0) return;

    tp_mutex_lock(&sched->lock);

    /* Never sleep past the earliest scheduled task, even one added after the
     * caller computed ticks_to_sleep; return at once if one is ready now */
    uint64_t current = atomic_load(&g_current_tick);
    for (size_t i = 0; i < sched->count; i++) {
        uint64_t ready_at = sched->tasks[i].ready_at_tick;
        if (ready_at <= current) {
            tp_mutex_unlock(&sched->lock);
            return;
        }
        if (ready_at - current < ticks_to_sleep) {
            ticks_to_sleep = ready_at - current;
        }
    }

    /* Ticks to microseconds, saturating at an hour */
    uint64_t sleep_us = MAX_SLEEP_US;
    if (ticks_to_sleep <= MAX_SLEEP_US / sched->tick_us) {
        sleep_us = ticks_to_sleep * sched->tick_us;
    }

    /* Wait until an add, the deadline, or shutdown */
    uint64_t deadline = tp_time_us() + sleep_us;
    uint64_t generation = sched->add_generation;
    while (sched->add_generation == generation && atomic_load(&sched->running)) {
        uint64_t now = tp_time_us();
        if (now >= deadline) break;
        if (!tp_cond_timedwait_us(&sched->wake_signal, &sched->lock, deadline - now)) {
            break;  /* Timed out */
        }
    }

    tp_mutex_unlock(&sched->lock);
}
/* }}} */
