/*
 * Threadpool Sync Module Implementation
 *
 * Provides non-blocking pointer synchronization via watch list polling.
 * See threadpool_sync.h for API documentation.
 */

#include "threadpool_sync.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Default configuration values */
#define DEFAULT_WATCH_LIST_SIZE 2048

/* Internal sync thread entry point */
static void* sync_loop(void* arg);

/* {{{ tp_sync_config_default
 * Returns default configuration for sync module. */
TpSyncConfig tp_sync_config_default(void) {
    TpSyncConfig config = {
        .watch_list_size = DEFAULT_WATCH_LIST_SIZE,
        .log_fn = NULL  /* No logging by default */
    };
    return config;
}
/* }}} */

/* {{{ tp_sync_create
 * Creates a sync context with specified configuration.
 * Returns NULL on allocation failure. */
TpSyncContext* tp_sync_create(TpSyncConfig* config) {
    if (!config) {
        fprintf(stderr, "[threadpool_sync] NULL config provided\n");
        return NULL;
    }

    TpSyncContext* ctx = calloc(1, sizeof(TpSyncContext));
    if (!ctx) {
        fprintf(stderr, "[threadpool_sync] Failed to allocate context\n");
        return NULL;
    }

    /* Allocate watch list */
    ctx->watch_list = calloc(config->watch_list_size, sizeof(TpWatchEntry));
    if (!ctx->watch_list) {
        fprintf(stderr, "[threadpool_sync] Failed to allocate watch list\n");
        free(ctx);
        return NULL;
    }

    ctx->watch_capacity = config->watch_list_size;
    atomic_store(&ctx->watch_count, 0);
    atomic_store(&ctx->running, true);
    pthread_spin_init(&ctx->watch_lock, PTHREAD_PROCESS_PRIVATE);
    ctx->swaps_performed = 0;
    ctx->idle_cycles = 0;

    if (config->log_fn) {
        config->log_fn("[threadpool_sync] Created context (capacity: %zu)\n",
                      config->watch_list_size);
    }

    return ctx;
}
/* }}} */

/* {{{ tp_sync_destroy
 * Destroys a sync context and frees resources. */
void tp_sync_destroy(TpSyncContext* ctx) {
    if (!ctx) return;

    pthread_spin_destroy(&ctx->watch_lock);
    free(ctx->watch_list);
    free(ctx);
}
/* }}} */

/* {{{ tp_sync_add_watch
 * Adds an entry to the watch list (thread-safe).
 * Returns false if watch list is full. */
bool tp_sync_add_watch(TpSyncContext* ctx,
                       atomic_bool* ready_flag,
                       void** target_ptr,
                       void* source_ptr) {
    if (!ctx) return false;

    pthread_spin_lock(&ctx->watch_lock);

    size_t count = atomic_load(&ctx->watch_count);
    if (count >= ctx->watch_capacity) {
        pthread_spin_unlock(&ctx->watch_lock);
        fprintf(stderr, "[threadpool_sync] Watch list full\n");
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
static void* sync_loop(void* arg) {
    TpSyncContext* ctx = (TpSyncContext*)arg;

    printf("[threadpool_sync] Starting sync thread\n");

    while (atomic_load(&ctx->running)) {
        size_t count = atomic_load(&ctx->watch_count);

        /* Scan watch list for ready flags */
        for (size_t i = 0; i < count; /* manual increment */) {
            TpWatchEntry* entry = &ctx->watch_list[i];

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

    printf("[threadpool_sync] Exiting (swaps: %lu, idle cycles: %lu)\n",
           ctx->swaps_performed, ctx->idle_cycles);
    return NULL;
}
/* }}} */

/* {{{ tp_sync_spawn
 * Creates and starts the sync thread.
 * Returns thread handle (pthread_t). */
pthread_t tp_sync_spawn(TpSyncContext* ctx) {
    pthread_t thread;
    int result = pthread_create(&thread, NULL, sync_loop, ctx);
    if (result != 0) {
        fprintf(stderr, "[threadpool_sync] Failed to create sync thread\n");
    } else {
        printf("[threadpool_sync] Sync thread spawned\n");
    }
    return thread;
}
/* }}} */

/* {{{ tp_sync_stop
 * Stops the sync thread by setting running flag to false.
 * Thread will exit on next iteration. */
void tp_sync_stop(TpSyncContext* ctx) {
    if (!ctx) return;
    atomic_store(&ctx->running, false);
}
/* }}} */

/* {{{ tp_sync_get_swaps
 * Returns number of pointer swaps performed. */
uint64_t tp_sync_get_swaps(TpSyncContext* ctx) {
    return ctx ? ctx->swaps_performed : 0;
}
/* }}} */

/* {{{ tp_sync_get_idle_cycles
 * Returns number of idle cycles (when watch list was empty). */
uint64_t tp_sync_get_idle_cycles(TpSyncContext* ctx) {
    return ctx ? ctx->idle_cycles : 0;
}
/* }}} */
