/*
 * Threadpool Scheduler Module
 *
 * Optional module for managing tasks with deferred assignment times.
 * Uses absolute tick-based scheduling to avoid deadlock when updater sleeps.
 *
 * Key features:
 * - Flat array storage (updater scans all tasks each tick)
 * - Absolute time-based readiness (ready_at_tick vs global tick counter)
 * - Sleep optimization (if no tasks ready, sleep until earliest task)
 * - Wake on new task (adding task wakes sleeping updater)
 * - Independent tick counter (game loop/timer thread increments g_current_tick)
 *
 * Usage:
 *   // Initialize global tick counter (incremented by game loop/timer)
 *   extern atomic_uint64_t g_current_tick;
 *
 *   // Create scheduler
 *   TpSchedulerConfig cfg = tp_scheduler_config_default();
 *   TpScheduler* sched = tp_scheduler_create(&cfg);
 *
 *   // Add tasks (ticks_delay: 0 = ASAP, N = ready in N ticks from now)
 *   scheduler_add(sched, &task, 0);      // Assign ASAP (next tick)
 *   scheduler_add(sched, &task, 100);    // Assign in 100 ticks
 *
 *   // Integrate with updater (use scheduler_get_ready as task source)
 *   TpUpdaterContext* updater = tp_updater_create(pool, scheduler_get_ready, sched);
 */

#ifndef THREADPOOL_SCHEDULER_H
#define THREADPOOL_SCHEDULER_H

#include "threadpool.h"
#include <stdbool.h>
#include <stdatomic.h>
#include <stdint.h>
#include <pthread.h>

/* {{{ Global tick counter
 * Incremented by game loop or timer thread (independent of scheduler/updater).
 * Scheduler compares task ready times against this value.
 *
 * NOTE: This must be defined by the user application.
 * Example initialization:
 *   atomic_uint64_t g_current_tick = 0;
 *
 * The game loop should increment this periodically:
 *   atomic_fetch_add(&g_current_tick, 1);  // Once per frame/tick
 */
extern atomic_uint64_t g_current_tick;
/* }}} */

/* {{{ TpScheduledTask
 * A task with an absolute ready time. */
typedef struct tp_scheduled_task {
    TpTask task;                   /* The task to execute */
    uint64_t ready_at_tick;        /* Absolute tick number when task becomes ready */
} TpScheduledTask;
/* }}} */

/* {{{ TpScheduler
 * Scheduler state for managing deferred tasks. */
typedef struct tp_scheduler {
    TpScheduledTask* tasks;        /* Flat array of scheduled tasks */
    size_t capacity;               /* Max tasks */
    size_t count;                  /* Current task count */

    pthread_mutex_t lock;          /* Protects task array */
    pthread_cond_t wake_signal;    /* Signal for new task arrivals */

    atomic_bool running;           /* Shutdown flag */
} TpScheduler;
/* }}} */

/* {{{ TpSchedulerConfig
 * Configuration for scheduler module. */
typedef struct tp_scheduler_config {
    size_t capacity;               /* Max scheduled tasks (default: 1024) */
    void (*log_fn)(const char* fmt, ...);  /* Optional logging callback */
} TpSchedulerConfig;
/* }}} */

/* {{{ Configuration */

/* Get default scheduler configuration */
TpSchedulerConfig tp_scheduler_config_default(void);

/* }}} */

/* {{{ Lifecycle */

/* Create scheduler with specified configuration
 * Returns NULL on allocation failure */
TpScheduler* tp_scheduler_create(TpSchedulerConfig* config);

/* Destroy scheduler (does not cancel pending tasks) */
void tp_scheduler_destroy(TpScheduler* sched);

/* }}} */

/* {{{ Task Management */

/* Add task to scheduler
 * ticks_delay: 0 = ASAP (ready at g_current_tick), N = ready in N ticks from now
 * Internally: ready_at_tick = g_current_tick + ticks_delay
 * Returns false if scheduler is full */
bool tp_scheduler_add(TpScheduler* sched, TpTask* task, uint32_t ticks_delay);

/* Remove all tasks matching predicate (for cancellation)
 * predicate returns true to remove, false to keep */
void tp_scheduler_remove_if(TpScheduler* sched,
                             bool (*predicate)(TpTask* task, void* user_data),
                             void* user_data);

/* Get count of scheduled tasks */
size_t tp_scheduler_count(TpScheduler* sched);

/* }}} */

/* {{{ Updater Integration */

/* Callback for updater's get_pending_tasks
 * Returns tasks where g_current_tick >= ready_at_tick
 * context should be the TpScheduler*
 * out: array of ready tasks (allocated by scheduler, valid until next call)
 * count: number of ready tasks
 * Returns true if tasks were found, false otherwise */
bool tp_scheduler_get_ready(void* context, TpTask** out, size_t* count);

/* Find earliest ready tick (for sleep optimization)
 * Returns UINT64_MAX if no tasks scheduled */
uint64_t tp_scheduler_earliest_ready_tick(TpScheduler* sched);

/* Sleep until earliest task or new task arrival (interruptible)
 * ticks_to_sleep: number of ticks to sleep (calculated externally: earliest_tick - g_current_tick)
 * Returns early if new task added (via pthread_cond_signal) */
void tp_scheduler_sleep_ticks(TpScheduler* sched, uint64_t ticks_to_sleep);

/* }}} */

#endif /* THREADPOOL_SCHEDULER_H */
