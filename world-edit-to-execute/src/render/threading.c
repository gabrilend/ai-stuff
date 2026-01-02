/*
 * Threading Infrastructure Implementation
 *
 * See threading.h for architecture documentation.
 * See docs/render-architecture.md for design rationale.
 */

#include "threading.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* {{{ pool_create
 * Allocates and initializes a worker pool with the specified number of workers.
 * Workers start immediately and begin processing (or waiting for input). */
WorkerPool* pool_create(int worker_count) {
    if (worker_count <= 0) worker_count = DEFAULT_WORKERS;
    if (worker_count > MAX_WORKERS) worker_count = MAX_WORKERS;

    WorkerPool* pool = (WorkerPool*)calloc(1, sizeof(WorkerPool));
    if (!pool) {
        fprintf(stderr, "[threading] Failed to allocate pool\n");
        return NULL;
    }

    pool->count = worker_count;
    atomic_store(&pool->running, true);
    pool->process_fn = NULL;
    pool->primary_buffer = NULL;

    printf("[threading] Creating pool with %d workers\n", worker_count);

    /* Initialize per-worker buffers and contexts */
    for (int i = 0; i < worker_count; i++) {
        WorkerBuffers* buf = &pool->buffers[i];
        WorkerContext* ctx = &pool->contexts[i];

        /* Initialize buffers */
        memset(&buf->input, 0, sizeof(WorkerInput));
        memset(&buf->output, 0, sizeof(WorkerOutput));
        atomic_store(&buf->output_ready, false);
        pthread_mutex_init(&buf->input_lock, NULL);
        pthread_mutex_init(&buf->output_lock, NULL);

        /* Initialize context */
        ctx->worker_id = i;
        ctx->buffers = buf;
        ctx->pool = pool;
        ctx->slot_start = 0;  /* Set by caller after pool creation */
        ctx->slot_end = 0;
    }

    /* Spawn worker threads */
    for (int i = 0; i < worker_count; i++) {
        int result = pthread_create(&pool->threads[i], NULL, worker_loop, &pool->contexts[i]);
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
 * Signals workers to stop, joins all threads, and frees resources. */
void pool_destroy(WorkerPool* pool) {
    if (!pool) return;

    printf("[threading] Destroying pool...\n");

    /* Signal shutdown */
    atomic_store(&pool->running, false);

    /* Join all worker threads */
    for (int i = 0; i < pool->count; i++) {
        pthread_join(pool->threads[i], NULL);
        printf("[threading] Worker %d joined\n", i);
    }

    /* Destroy mutexes */
    for (int i = 0; i < pool->count; i++) {
        pthread_mutex_destroy(&pool->buffers[i].input_lock);
        pthread_mutex_destroy(&pool->buffers[i].output_lock);
    }

    free(pool);
    printf("[threading] Pool destroyed\n");
}
/* }}} */

/* {{{ pool_set_process_fn
 * Sets the processing function called by workers. */
void pool_set_process_fn(WorkerPool* pool, void (*fn)(WorkerContext*, void*, void*)) {
    pool->process_fn = fn;
}
/* }}} */

/* {{{ pool_set_primary_buffer
 * Sets the primary buffer that sync thread writes to. */
void pool_set_primary_buffer(WorkerPool* pool, void* buffer) {
    pool->primary_buffer = buffer;
}
/* }}} */

/* {{{ worker_loop
 * Main loop for worker threads. Always processing - never idles.
 * Reads from input buffer, computes GPU-ready output, sets output_ready flag. */
void* worker_loop(void* arg) {
    WorkerContext* ctx = (WorkerContext*)arg;
    WorkerBuffers* buf = ctx->buffers;
    WorkerPool* pool = ctx->pool;

    printf("[worker %d] Starting\n", ctx->worker_id);

    unsigned int last_tick = 0;

    while (atomic_load(&pool->running)) {
        /* Read input (with lock) */
        pthread_mutex_lock(&buf->input_lock);
        WorkerInput input_copy = buf->input;
        pthread_mutex_unlock(&buf->input_lock);

        /* Skip if we already processed this tick */
        if (input_copy.tick == last_tick && last_tick > 0) {
            /* No new input - brief sleep to avoid spin */
            usleep(100);  /* 0.1ms - very short, workers stay responsive */
            continue;
        }

        last_tick = input_copy.tick;

        /* Process if we have a processing function */
        if (pool->process_fn) {
            /* Lock output for writing */
            pthread_mutex_lock(&buf->output_lock);

            /* Call processing function
             * This is where heavy computation happens */
            pool->process_fn(ctx, &input_copy, &buf->output);

            /* Mark output as ready */
            buf->output.tick = input_copy.tick;
            atomic_store(&buf->output_ready, true);

            pthread_mutex_unlock(&buf->output_lock);
        }
    }

    printf("[worker %d] Exiting\n", ctx->worker_id);
    return NULL;
}
/* }}} */

/* {{{ sync_loop
 * Main loop for sync thread. Swaps ready outputs into primary buffer.
 * Near-zero work: just pointer operations, no computation. */
void* sync_loop(void* arg) {
    SyncContext* ctx = (SyncContext*)arg;
    WorkerPool* pool = ctx->pool;

    printf("[sync] Starting\n");

    while (atomic_load(ctx->running)) {
        bool any_swapped = false;

        /* Check each worker for ready output */
        for (int i = 0; i < pool->count; i++) {
            WorkerBuffers* buf = &pool->buffers[i];

            if (atomic_load(&buf->output_ready)) {
                pthread_mutex_lock(&buf->output_lock);

                /* Swap output into primary buffer
                 * This is the key operation - just a pointer copy.
                 * The actual data is already computed by worker.
                 *
                 * Note: Real implementation would swap specific slots.
                 * For now, we just copy the output pointer. */
                if (ctx->primary_buffer && buf->output.slot_data) {
                    /* In full implementation: memcpy to correct slot range
                     * For now: just note that swap would happen here */
                    ctx->swaps_performed++;
                }

                /* Clear ready flag */
                atomic_store(&buf->output_ready, false);

                pthread_mutex_unlock(&buf->output_lock);
                any_swapped = true;
            }
        }

        if (!any_swapped) {
            /* No outputs ready - sleep briefly */
            ctx->idle_cycles++;
            usleep(1000);  /* 1ms */
        }
    }

    printf("[sync] Exiting (swaps: %u, idle cycles: %u)\n",
           ctx->swaps_performed, ctx->idle_cycles);
    return NULL;
}
/* }}} */

/* {{{ updater_loop
 * Main loop for updater thread. Populates worker inputs from game state.
 * Sleeps when no new input available. */
void* updater_loop(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;
    WorkerPool* pool = ctx->pool;

    printf("[updater] Starting\n");

    WorkerInput new_input;
    memset(&new_input, 0, sizeof(new_input));

    while (atomic_load(ctx->running)) {
        /* Check for new input via callback */
        bool has_new = false;
        if (ctx->get_input) {
            has_new = ctx->get_input(&new_input);
        }

        if (has_new) {
            /* Distribute to all workers */
            distribute_input_to_workers(pool, &new_input);
            ctx->updates_sent++;
        } else {
            /* No new input - sleep */
            ctx->idle_cycles++;
            usleep(5000);  /* 5ms */
        }
    }

    printf("[updater] Exiting (updates: %u, idle cycles: %u)\n",
           ctx->updates_sent, ctx->idle_cycles);
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

/* {{{ spawn_updater_thread
 * Creates and starts the updater thread. */
pthread_t spawn_updater_thread(UpdaterContext* ctx) {
    pthread_t thread;
    int result = pthread_create(&thread, NULL, updater_loop, ctx);
    if (result != 0) {
        fprintf(stderr, "[threading] Failed to create updater thread\n");
    } else {
        printf("[threading] Updater thread spawned\n");
    }
    return thread;
}
/* }}} */

/* {{{ distribute_input_to_workers
 * Copies input to all worker input buffers. */
void distribute_input_to_workers(WorkerPool* pool, WorkerInput* input) {
    for (int i = 0; i < pool->count; i++) {
        WorkerBuffers* buf = &pool->buffers[i];

        pthread_mutex_lock(&buf->input_lock);
        buf->input = *input;  /* Struct copy */
        pthread_mutex_unlock(&buf->input_lock);
    }
}
/* }}} */

/* {{{ has_any_output_ready
 * Returns true if any worker has pending output. */
bool has_any_output_ready(WorkerPool* pool) {
    for (int i = 0; i < pool->count; i++) {
        if (atomic_load(&pool->buffers[i].output_ready)) {
            return true;
        }
    }
    return false;
}
/* }}} */
