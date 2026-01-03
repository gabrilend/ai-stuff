/*
 * Threading Infrastructure Implementation
 *
 * See threading.h for structure definitions.
 * See docs/render-threading-v2.md for architecture rationale.
 *
 * This implementation provides:
 * - Ring buffer task lists for workers
 * - Load-balanced task distribution
 * - Parallel sync via watch list
 */

#include "threading.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <limits.h>

/* Global active updater count - for dynamic scaling decisions */
atomic_uint g_active_updater_count = 0;

/* {{{ get_timestamp_us
 * Returns current time in microseconds (monotonic clock). */
uint64_t get_timestamp_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000ULL + (uint64_t)ts.tv_nsec / 1000ULL;
}
/* }}} */

/* {{{ sleep_task
 * Default no-op task that yields briefly.
 * Used as a placeholder or for testing. */
void sleep_task(void* context) {
    (void)context;  /* Unused */
    usleep(1000);  /* 1ms yield */
}
/* }}} */

/* {{{ relocate_task
 * Compacts the ring buffer by copying active tasks to the start.
 * Called when end_ptr approaches the buffer end. */
void relocate_task(void* context) {
    Worker* w = (Worker*)context;

    /* Count active tasks (from current position to end) */
    size_t active_count = 0;
    size_t read_ptr = w->start_ptr;

    while (read_ptr != w->end_ptr) {
        WorkerTask* task = &w->task_list[read_ptr];
        if (task->execute != sleep_task) {
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
    WorkerTask* temp = malloc(active_count * sizeof(WorkerTask));
    if (!temp) {
        fprintf(stderr, "[worker %d] relocate_task: malloc failed\n", w->worker_id);
        return;
    }

    size_t write_idx = 0;
    read_ptr = w->start_ptr;
    while (read_ptr != w->end_ptr && write_idx < active_count) {
        WorkerTask* task = &w->task_list[read_ptr];
        if (task->execute != sleep_task) {
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

    printf("[worker %d] Relocated %zu active tasks to buffer start\n",
           w->worker_id, active_count);
}
/* }}} */

/* {{{ task_append
 * Appends a task to a worker's ring buffer.
 * Returns false if buffer is full. */
bool task_append(Worker* w, WorkerTask* task) {
    /* Calculate next position */
    size_t next = (w->end_ptr + 1) % w->task_list_size;

    /* Check if buffer is full */
    if (next == w->start_ptr) {
        fprintf(stderr, "[worker %d] task_append: buffer full\n", w->worker_id);
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
            w->task_list[w->end_ptr].execute = relocate_task;
            w->task_list[w->end_ptr].on_complete = NULL;
            w->task_list[w->end_ptr].context = w;
            w->task_list[w->end_ptr].weight = WEIGHT_LIGHT;
            w->task_list[w->end_ptr].repeat_count = 1;
            w->end_ptr = reloc_next;
        }
    }

    return true;
}
/* }}} */

/* {{{ find_least_busy_worker
 * Returns the worker with the lowest weighted task count.
 * O(N) scan where N = worker count. */
Worker* find_least_busy_worker(WorkerPool* pool) {
    if (!pool || pool->count == 0) return NULL;

    Worker* best = &pool->workers[0];
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

/* {{{ worker_loop
 * Main loop for worker threads.
 * Executes tasks from the ring buffer.
 *
 * repeat_count behavior:
 *   N > 0: run N more times, then call on_complete and advance
 *   N <= 0: already done, skip this slot (-1 does NOT mean infinite)
 *   Use INT16_MAX for "essentially infinite" execution
 */
void* worker_loop(void* arg) {
    Worker* w = (Worker*)arg;

    printf("[worker %d] Starting\n", w->worker_id);

    while (atomic_load(&w->running)) {
        /* Check if buffer is empty */
        if (w->start_ptr == w->end_ptr) {
            /* Buffer empty - brief yield and retry
             * Use short sleep (100us) to reduce latency while avoiding busy-wait */
            usleep(100);
            continue;
        }

        /* Get current task */
        WorkerTask* task = &w->task_list[w->start_ptr];

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

    printf("[worker %d] Exiting\n", w->worker_id);
    return NULL;
}
/* }}} */

/* {{{ pool_create
 * Creates a worker pool with the specified number of workers.
 * If worker_count is 0, auto-detects CPU cores. */
WorkerPool* pool_create(int worker_count) {
    /* Auto-detect CPU cores if not specified */
    if (worker_count <= 0) {
        worker_count = (int)sysconf(_SC_NPROCESSORS_ONLN);
        if (worker_count <= 0) worker_count = 4;  /* Fallback */
    }

    printf("[threading] Creating pool with %d workers\n", worker_count);

    /* Allocate pool */
    WorkerPool* pool = calloc(1, sizeof(WorkerPool));
    if (!pool) {
        fprintf(stderr, "[threading] Failed to allocate pool\n");
        return NULL;
    }

    pool->count = worker_count;
    atomic_store(&pool->running, true);

    /* Allocate worker array */
    pool->workers = calloc(worker_count, sizeof(Worker));
    if (!pool->workers) {
        fprintf(stderr, "[threading] Failed to allocate workers\n");
        free(pool);
        return NULL;
    }

    /* Initialize each worker */
    for (int i = 0; i < worker_count; i++) {
        Worker* w = &pool->workers[i];
        w->worker_id = i;
        w->pool = pool;
        w->task_list_size = TASK_LIST_SIZE;
        atomic_store(&w->num_tasks, 0);
        atomic_store(&w->running, true);

        /* Allocate task ring buffer */
        w->task_list = calloc(TASK_LIST_SIZE, sizeof(WorkerTask));
        if (!w->task_list) {
            fprintf(stderr, "[threading] Failed to allocate task list for worker %d\n", i);
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
                                    worker_loop, &pool->workers[i]);
        if (result != 0) {
            fprintf(stderr, "[threading] Failed to create worker %d\n", i);
        } else {
            printf("[threading] Worker %d spawned\n", i);
        }
    }

    return pool;
}
/* }}} */

/* {{{ pool_destroy
 * Signals workers to stop, joins all threads, frees resources. */
void pool_destroy(WorkerPool* pool) {
    if (!pool) return;

    printf("[threading] Destroying pool...\n");

    /* Signal shutdown */
    atomic_store(&pool->running, false);
    for (int i = 0; i < pool->count; i++) {
        atomic_store(&pool->workers[i].running, false);
    }

    /* Join all worker threads */
    for (int i = 0; i < pool->count; i++) {
        pthread_join(pool->workers[i].thread, NULL);
        printf("[threading] Worker %d joined\n", i);
    }

    /* Free task lists */
    for (int i = 0; i < pool->count; i++) {
        free(pool->workers[i].task_list);
    }

    /* Free workers array and pool */
    free(pool->workers);
    free(pool);

    printf("[threading] Pool destroyed\n");
}
/* }}} */

/* {{{ pool_get_total_load
 * Returns the sum of weighted task counts across all workers. */
unsigned int pool_get_total_load(WorkerPool* pool) {
    if (!pool) return 0;

    unsigned int total = 0;
    for (int i = 0; i < pool->count; i++) {
        total += atomic_load(&pool->workers[i].num_tasks);
    }
    return total;
}
/* }}} */

/* {{{ sync_create
 * Creates a sync context with the specified watch list capacity. */
SyncContext* sync_create(size_t capacity) {
    SyncContext* ctx = calloc(1, sizeof(SyncContext));
    if (!ctx) {
        fprintf(stderr, "[sync] Failed to allocate context\n");
        return NULL;
    }

    ctx->watch_list = calloc(capacity, sizeof(WatchEntry));
    if (!ctx->watch_list) {
        fprintf(stderr, "[sync] Failed to allocate watch list\n");
        free(ctx);
        return NULL;
    }

    ctx->watch_capacity = capacity;
    atomic_store(&ctx->watch_count, 0);
    atomic_store(&ctx->running, true);
    pthread_spin_init(&ctx->watch_lock, PTHREAD_PROCESS_PRIVATE);
    ctx->swaps_performed = 0;
    ctx->idle_cycles = 0;

    return ctx;
}
/* }}} */

/* {{{ sync_destroy
 * Destroys a sync context and frees resources. */
void sync_destroy(SyncContext* ctx) {
    if (!ctx) return;

    pthread_spin_destroy(&ctx->watch_lock);
    free(ctx->watch_list);
    free(ctx);
}
/* }}} */

/* {{{ sync_add_watch
 * Adds an entry to the watch list (thread-safe).
 * Returns false if watch list is full. */
bool sync_add_watch(SyncContext* ctx,
                    atomic_bool* ready_flag,
                    void** target_ptr,
                    void* source_ptr) {
    pthread_spin_lock(&ctx->watch_lock);

    size_t count = atomic_load(&ctx->watch_count);
    if (count >= ctx->watch_capacity) {
        pthread_spin_unlock(&ctx->watch_lock);
        fprintf(stderr, "[sync] Watch list full\n");
        return false;
    }

    ctx->watch_list[count].ready_flag = ready_flag;
    ctx->watch_list[count].target_ptr = target_ptr;
    ctx->watch_list[count].source_ptr = source_ptr;
    atomic_fetch_add(&ctx->watch_count, 1);

    pthread_spin_unlock(&ctx->watch_lock);
    return true;
}
/* }}} */

/* {{{ sync_loop
 * Main loop for sync thread.
 * Continuously monitors watch list, swaps pointers when ready. */
void* sync_loop(void* arg) {
    SyncContext* ctx = (SyncContext*)arg;

    printf("[sync] Starting\n");

    while (atomic_load(&ctx->running)) {
        size_t count = atomic_load(&ctx->watch_count);

        for (size_t i = 0; i < count; /* manual increment */) {
            WatchEntry* entry = &ctx->watch_list[i];

            if (atomic_load(entry->ready_flag)) {
                /* Swap pointer atomically */
                *entry->target_ptr = entry->source_ptr;

                /* Clear ready flag */
                atomic_store(entry->ready_flag, false);

                /* Remove from list: swap with last, decrement count */
                pthread_spin_lock(&ctx->watch_lock);
                count = atomic_load(&ctx->watch_count);
                if (count > 0 && i < count) {
                    ctx->watch_list[i] = ctx->watch_list[count - 1];
                    atomic_store(&ctx->watch_count, count - 1);
                    count--;
                }
                pthread_spin_unlock(&ctx->watch_lock);

                ctx->swaps_performed++;
                /* Don't increment i - check swapped-in entry */
            } else {
                i++;
            }
        }

        /* Brief yield when list is empty */
        if (count == 0) {
            ctx->idle_cycles++;
            usleep(100);  /* 0.1ms */
        }
    }

    printf("[sync] Exiting (swaps: %lu, idle cycles: %lu)\n",
           ctx->swaps_performed, ctx->idle_cycles);
    return NULL;
}
/* }}} */

/* {{{ spawn_sync_thread
 * Creates and starts the sync thread. */
pthread_t spawn_sync_thread(SyncContext* ctx) {
    pthread_t thread;
    int result = pthread_create(&thread, NULL, sync_loop, ctx);
    if (result != 0) {
        fprintf(stderr, "[threading] Failed to create sync thread\n");
    } else {
        printf("[threading] Sync thread spawned\n");
    }
    return thread;
}
/* }}} */

/* {{{ updater_create
 * Creates a primary updater context. */
UpdaterContext* updater_create(WorkerPool* pool,
                               bool (*get_pending_tasks)(UpdaterContext*, WorkerTask**, size_t*),
                               void* user_data) {
    UpdaterContext* ctx = calloc(1, sizeof(UpdaterContext));
    if (!ctx) {
        fprintf(stderr, "[updater] Failed to allocate context\n");
        return NULL;
    }

    ctx->pool = pool;
    ctx->get_pending_tasks = get_pending_tasks;
    ctx->user_data = user_data;
    ctx->partition_start = 0;
    ctx->partition_end = 0;  /* Set by callback */
    ctx->last_tick_duration_us = 0;
    ctx->is_primary = true;
    ctx->is_allocated = true;

    return ctx;
}
/* }}} */

/* {{{ updater_destroy
 * Destroys an updater context. */
void updater_destroy(UpdaterContext* ctx) {
    if (ctx && ctx->is_allocated) {
        free(ctx);
    }
}
/* }}} */

/* Forward declaration for on_complete callback */
static void updater_on_complete(void* arg);

/* {{{ updater_start
 * Starts the primary updater as a worker task.
 * Uses INT16_MAX for essentially infinite execution, with on_complete
 * for self-evaluation when repeat_count reaches 0. */
void updater_start(UpdaterContext* ctx) {
    if (!ctx || !ctx->pool) return;

    Worker* target = find_least_busy_worker(ctx->pool);
    if (!target) return;

    /* Increment active updater count */
    atomic_fetch_add(&g_active_updater_count, 1);

    WorkerTask task = {
        .execute = primary_updater_execute,
        .on_complete = updater_on_complete,
        .context = ctx,
        .weight = WEIGHT_UPDATER,
        .repeat_count = INT16_MAX  /* Run ~32K times then re-evaluate */
    };

    task_append(target, &task);
    printf("[updater] Primary updater started on worker %d (active: %u)\n",
           target->worker_id, atomic_load(&g_active_updater_count));
}
/* }}} */

/* {{{ primary_updater_execute
 * Main execution function for the primary updater.
 * Distributes tasks to workers and spawns helpers if overloaded. */
void primary_updater_execute(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;
    if (!ctx || !ctx->get_pending_tasks) return;

    uint64_t start = get_timestamp_us();

    /* Get pending tasks from callback */
    WorkerTask* pending = NULL;
    size_t count = 0;
    if (!ctx->get_pending_tasks(ctx, &pending, &count) || count == 0) {
        /* No tasks available - very brief yield to avoid busy-wait */
        usleep(100);  /* 0.1ms */
        return;
    }

    /* Distribute all tasks to workers */
    for (size_t i = 0; i < count; i++) {
        Worker* target = find_least_busy_worker(ctx->pool);
        if (target) {
            task_append(target, &pending[i]);
        }
    }

    uint64_t elapsed = get_timestamp_us() - start;
    ctx->last_tick_duration_us = elapsed;

    /* Check for overload - if we took longer than target tick time */
    if (elapsed > TARGET_TICK_US && count > 1) {
        /* Spawn a helper to take half the work next tick
         * Note: This is a simple heuristic. In practice, the pending tasks
         * may be different each tick, so we can't really "split" them.
         * Instead, we just note that helpers would be spawned here. */
        printf("[updater] Overload detected: %lu us (target: %d us)\n",
               elapsed, TARGET_TICK_US);
    }
}
/* }}} */

/* {{{ helper_updater_execute
 * Execution function for helper updaters.
 * Distributes a partition of tasks and records timing. */
void helper_updater_execute(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;
    if (!ctx || !ctx->get_pending_tasks) return;

    uint64_t start = get_timestamp_us();

    /* Get pending tasks */
    WorkerTask* pending = NULL;
    size_t count = 0;
    if (!ctx->get_pending_tasks(ctx, &pending, &count)) {
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
        Worker* target = find_least_busy_worker(ctx->pool);
        if (target) {
            task_append(target, &pending[i]);
        }
    }

    ctx->last_tick_duration_us = get_timestamp_us() - start;
}
/* }}} */

/* {{{ helper_updater_on_complete
 * Self-evaluation callback for helper updaters.
 * If last tick took > 50% of target, recreate. Otherwise, exit. */
void helper_updater_on_complete(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;
    if (!ctx) return;

    if (ctx->last_tick_duration_us > CONTINUATION_THRESHOLD_US) {
        /* Still under load - recreate task on least-busy worker */
        Worker* target = find_least_busy_worker(ctx->pool);
        if (target) {
            WorkerTask task = {
                .execute = helper_updater_execute,
                .on_complete = helper_updater_on_complete,
                .context = ctx,
                .weight = WEIGHT_UPDATER,
                .repeat_count = 1
            };
            task_append(target, &task);
            printf("[updater] Helper continuing (last: %lu us)\n",
                   ctx->last_tick_duration_us);
        }
    } else {
        /* Load decreased - exit and free context */
        printf("[updater] Helper exiting (last: %lu us <= %d us threshold)\n",
               ctx->last_tick_duration_us, CONTINUATION_THRESHOLD_US);
        if (ctx->is_allocated) {
            free(ctx);
        }
    }
}
/* }}} */

/* {{{ spawn_helper_updater
 * Spawns a helper updater to handle a partition of the workload. */
void spawn_helper_updater(UpdaterContext* primary, size_t partition_start, size_t partition_end) {
    if (!primary || !primary->pool) return;

    /* Allocate helper context */
    UpdaterContext* helper = calloc(1, sizeof(UpdaterContext));
    if (!helper) {
        fprintf(stderr, "[updater] Failed to allocate helper context\n");
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

    /* Submit as worker task */
    Worker* target = find_least_busy_worker(primary->pool);
    if (!target) {
        free(helper);
        return;
    }

    WorkerTask task = {
        .execute = helper_updater_execute,
        .on_complete = helper_updater_on_complete,
        .context = helper,
        .weight = WEIGHT_UPDATER,
        .repeat_count = 1
    };

    task_append(target, &task);
    printf("[updater] Helper spawned for partition [%zu, %zu) on worker %d\n",
           partition_start, partition_end, target->worker_id);
}
/* }}} */

/* {{{ updater_on_complete
 * Self-evaluation callback for updaters.
 * Called when repeat_count reaches 0. Implements dynamic scaling:
 * - If only 1 updater active: re-spawn with INT16_MAX (must keep running)
 * - If multiple updaters and last update > 5ms: spawn replacement, terminate
 * - Otherwise: terminate (allow pool to shrink) */
static void updater_on_complete(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;
    if (!ctx || !ctx->pool) return;

    unsigned int active = atomic_load(&g_active_updater_count);

    if (active <= 1) {
        /* Last updater - must keep running, re-spawn with INT16_MAX */
        Worker* target = find_least_busy_worker(ctx->pool);
        if (target) {
            WorkerTask task = {
                .execute = primary_updater_execute,
                .on_complete = updater_on_complete,
                .context = ctx,
                .weight = WEIGHT_UPDATER,
                .repeat_count = INT16_MAX
            };
            task_append(target, &task);
            printf("[updater] Re-spawned (only %u active, last: %lu us)\n",
                   active, ctx->last_tick_duration_us);
        }
    } else if (ctx->last_tick_duration_us > UPDATER_OVERLOAD_THRESHOLD_US) {
        /* Multiple updaters and heavy load - spawn replacement, terminate this one */
        Worker* target = find_least_busy_worker(ctx->pool);
        if (target) {
            WorkerTask task = {
                .execute = primary_updater_execute,
                .on_complete = updater_on_complete,
                .context = ctx,
                .weight = WEIGHT_UPDATER,
                .repeat_count = INT16_MAX
            };
            task_append(target, &task);
            printf("[updater] Spawned replacement on worker %d (last: %lu us > %d us)\n",
                   target->worker_id, ctx->last_tick_duration_us,
                   UPDATER_OVERLOAD_THRESHOLD_US);
        }
        /* Decrement count - this updater is terminating */
        atomic_fetch_sub(&g_active_updater_count, 1);
    } else {
        /* Multiple updaters and light load - terminate to shrink pool */
        atomic_fetch_sub(&g_active_updater_count, 1);
        printf("[updater] Terminating (active: %u, last: %lu us <= %d us)\n",
               active - 1, ctx->last_tick_duration_us, UPDATER_OVERLOAD_THRESHOLD_US);

        /* Free context if dynamically allocated */
        if (ctx->is_allocated) {
            free(ctx);
        }
    }
}
/* }}} */
