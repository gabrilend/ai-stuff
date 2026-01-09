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
#include <time.h>

/* Default configuration values */
#define DEFAULT_SCHEDULER_CAPACITY 1024

/* Internal buffer for returning ready tasks (reused across calls) */
static TpTask* g_ready_buffer = NULL;
static size_t g_ready_buffer_size = 0;

/* {{{ tp_scheduler_config_default
 * Returns default configuration for scheduler module. */
TpSchedulerConfig tp_scheduler_config_default(void) {
    TpSchedulerConfig config = {
        .capacity = DEFAULT_SCHEDULER_CAPACITY,
        .log_fn = NULL  /* No logging by default */
    };
    return config;
}
/* }}} */

/* {{{ tp_scheduler_create
 * Creates a scheduler with specified configuration.
 * Returns NULL on allocation failure. */
TpScheduler* tp_scheduler_create(TpSchedulerConfig* config) {
    if (!config) {
        fprintf(stderr, "[threadpool_scheduler] NULL config provided\n");
        return NULL;
    }

    TpScheduler* sched = calloc(1, sizeof(TpScheduler));
    if (!sched) {
        fprintf(stderr, "[threadpool_scheduler] Failed to allocate scheduler\n");
        return NULL;
    }

    /* Allocate task array */
    sched->tasks = calloc(config->capacity, sizeof(TpScheduledTask));
    if (!sched->tasks) {
        fprintf(stderr, "[threadpool_scheduler] Failed to allocate task array\n");
        free(sched);
        return NULL;
    }

    sched->capacity = config->capacity;
    sched->count = 0;
    atomic_store(&sched->running, true);

    /* Initialize synchronization primitives */
    pthread_mutex_init(&sched->lock, NULL);
    pthread_cond_init(&sched->wake_signal, NULL);

    if (config->log_fn) {
        config->log_fn("[threadpool_scheduler] Created (capacity: %zu)\n",
                       config->capacity);
    }

    return sched;
}
/* }}} */

/* {{{ tp_scheduler_destroy
 * Destroys a scheduler and frees resources. */
void tp_scheduler_destroy(TpScheduler* sched) {
    if (!sched) return;

    atomic_store(&sched->running, false);
    pthread_cond_broadcast(&sched->wake_signal);

    pthread_mutex_destroy(&sched->lock);
    pthread_cond_destroy(&sched->wake_signal);

    free(sched->tasks);
    free(sched);
}
/* }}} */

/* {{{ tp_scheduler_add
 * Adds a task to the scheduler with specified delay.
 * Returns false if scheduler is full. */
bool tp_scheduler_add(TpScheduler* sched, TpTask* task, uint32_t ticks_delay) {
    if (!sched || !task) return false;

    pthread_mutex_lock(&sched->lock);

    /* Check if scheduler is full */
    if (sched->count >= sched->capacity) {
        pthread_mutex_unlock(&sched->lock);
        fprintf(stderr, "[threadpool_scheduler] Scheduler full\n");
        return false;
    }

    /* Calculate absolute ready time */
    uint64_t current = atomic_load(&g_current_tick);
    uint64_t ready_at = current + ticks_delay;

    /* Add to array */
    sched->tasks[sched->count].task = *task;
    sched->tasks[sched->count].ready_at_tick = ready_at;
    sched->count++;

    /* Wake any sleeping updater */
    pthread_cond_signal(&sched->wake_signal);

    pthread_mutex_unlock(&sched->lock);
    return true;
}
/* }}} */

/* {{{ tp_scheduler_remove_if
 * Removes all tasks matching the predicate. */
void tp_scheduler_remove_if(TpScheduler* sched,
                             bool (*predicate)(TpTask* task, void* user_data),
                             void* user_data) {
    if (!sched || !predicate) return;

    pthread_mutex_lock(&sched->lock);

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

    pthread_mutex_unlock(&sched->lock);
}
/* }}} */

/* {{{ tp_scheduler_count
 * Returns the number of scheduled tasks. */
size_t tp_scheduler_count(TpScheduler* sched) {
    if (!sched) return 0;

    pthread_mutex_lock(&sched->lock);
    size_t count = sched->count;
    pthread_mutex_unlock(&sched->lock);

    return count;
}
/* }}} */

/* {{{ tp_scheduler_get_ready
 * Returns tasks where g_current_tick >= ready_at_tick.
 * This is the callback for updater's get_pending_tasks. */
bool tp_scheduler_get_ready(void* context, TpTask** out, size_t* count) {
    TpScheduler* sched = (TpScheduler*)context;
    if (!sched || !out || !count) return false;

    pthread_mutex_lock(&sched->lock);

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
        pthread_mutex_unlock(&sched->lock);
        *out = NULL;
        *count = 0;
        return false;
    }

    /* Allocate or resize ready buffer if needed */
    if (g_ready_buffer_size < ready_count) {
        g_ready_buffer = realloc(g_ready_buffer, ready_count * sizeof(TpTask));
        if (!g_ready_buffer) {
            pthread_mutex_unlock(&sched->lock);
            fprintf(stderr, "[threadpool_scheduler] Failed to allocate ready buffer\n");
            return false;
        }
        g_ready_buffer_size = ready_count;
    }

    /* Copy ready tasks to buffer and remove from scheduler */
    size_t ready_idx = 0;
    size_t write_idx = 0;

    for (size_t read_idx = 0; read_idx < sched->count; read_idx++) {
        if (current >= sched->tasks[read_idx].ready_at_tick) {
            /* Task is ready - copy to buffer */
            g_ready_buffer[ready_idx++] = sched->tasks[read_idx].task;
        } else {
            /* Task not ready - keep in scheduler */
            if (write_idx != read_idx) {
                sched->tasks[write_idx] = sched->tasks[read_idx];
            }
            write_idx++;
        }
    }

    sched->count = write_idx;

    pthread_mutex_unlock(&sched->lock);

    *out = g_ready_buffer;
    *count = ready_count;
    return true;
}
/* }}} */

/* {{{ tp_scheduler_earliest_ready_tick
 * Returns the earliest ready tick, or UINT64_MAX if no tasks scheduled. */
uint64_t tp_scheduler_earliest_ready_tick(TpScheduler* sched) {
    if (!sched) return UINT64_MAX;

    pthread_mutex_lock(&sched->lock);

    if (sched->count == 0) {
        pthread_mutex_unlock(&sched->lock);
        return UINT64_MAX;
    }

    /* Find minimum ready_at_tick */
    uint64_t earliest = sched->tasks[0].ready_at_tick;
    for (size_t i = 1; i < sched->count; i++) {
        if (sched->tasks[i].ready_at_tick < earliest) {
            earliest = sched->tasks[i].ready_at_tick;
        }
    }

    pthread_mutex_unlock(&sched->lock);
    return earliest;
}
/* }}} */

/* {{{ tp_scheduler_sleep_ticks
 * Sleeps until earliest task or new task arrival.
 * Uses pthread_cond_timedwait for interruptible sleep. */
void tp_scheduler_sleep_ticks(TpScheduler* sched, uint64_t ticks_to_sleep) {
    if (!sched || ticks_to_sleep == 0) return;

    /* Convert ticks to nanoseconds (assuming 16ms per tick = 62.5 Hz) */
    const uint64_t TICK_NS = 16000000;  /* 16ms in nanoseconds */
    uint64_t sleep_ns = ticks_to_sleep * TICK_NS;

    /* Calculate absolute timeout */
    struct timespec timeout;
    clock_gettime(CLOCK_MONOTONIC, &timeout);

    uint64_t total_ns = timeout.tv_nsec + sleep_ns;
    timeout.tv_sec += total_ns / 1000000000ULL;
    timeout.tv_nsec = total_ns % 1000000000ULL;

    /* Wait with timeout (interruptible by pthread_cond_signal) */
    pthread_mutex_lock(&sched->lock);
    pthread_cond_timedwait(&sched->wake_signal, &sched->lock, &timeout);
    pthread_mutex_unlock(&sched->lock);
}
/* }}} */
