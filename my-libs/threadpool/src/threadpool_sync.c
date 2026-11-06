/*
 * Threadpool Sync Module Implementation
 *
 * Provides non-blocking pointer synchronization via watch list polling.
 * See threadpool_sync.h for API documentation.
 */

#include "threadpool_sync.h"
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Conditional logging through the context's callback */
#define SYNC_LOG(ctx, fmt, ...) \
    do { \
        if ((ctx)->log_fn) { \
            (ctx)->log_fn(fmt, ##__VA_ARGS__); \
        } \
    } while(0)

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
    TpSyncConfig cfg = config ? *config : tp_sync_config_default();

    TpSyncContext* ctx = calloc(1, sizeof(TpSyncContext));
    if (!ctx) {
        if (cfg.log_fn) cfg.log_fn("[threadpool_sync] Failed to allocate context\n");
        return NULL;
    }
    ctx->log_fn = cfg.log_fn;

    /* Allocate watch list (calloc(0) may return NULL, so ask for at least 1) */
    ctx->watch_list = calloc(cfg.watch_list_size ? cfg.watch_list_size : 1,
                             sizeof(TpWatchEntry));
    if (!ctx->watch_list) {
        SYNC_LOG(ctx, "[threadpool_sync] Failed to allocate watch list\n");
        free(ctx);
        return NULL;
    }

    ctx->watch_capacity = cfg.watch_list_size;
    atomic_store(&ctx->watch_count, 0);
    atomic_store(&ctx->running, true);
    tp_spin_init(&ctx->watch_lock);
    atomic_store(&ctx->swaps_performed, 0);
    atomic_store(&ctx->idle_cycles, 0);

    SYNC_LOG(ctx, "[threadpool_sync] Created context (capacity: %zu)\n",
             cfg.watch_list_size);

    return ctx;
}
/* }}} */

/* {{{ tp_sync_destroy
 * Destroys a sync context and frees resources. */
void tp_sync_destroy(TpSyncContext* ctx) {
    if (!ctx) return;

    tp_spin_destroy(&ctx->watch_lock);
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

    tp_spin_lock(&ctx->watch_lock);

    size_t count = atomic_load(&ctx->watch_count);
    if (count >= ctx->watch_capacity) {
        tp_spin_unlock(&ctx->watch_lock);
        SYNC_LOG(ctx, "[threadpool_sync] Watch list full\n");
        return false;
    }

    ctx->watch_list[count].ready_flag = ready_flag;
    ctx->watch_list[count].target_ptr = target_ptr;
    ctx->watch_list[count].source_ptr = source_ptr;
    atomic_fetch_add(&ctx->watch_count, 1);

    tp_spin_unlock(&ctx->watch_lock);
    return true;
}
/* }}} */

/* {{{ sync_loop
 * Main loop for sync thread.
 * Continuously monitors watch list, swaps pointers when ready. */
static void* sync_loop(void* arg) {
    TpSyncContext* ctx = (TpSyncContext*)arg;

    SYNC_LOG(ctx, "[threadpool_sync] Starting sync thread\n");

    while (atomic_load(&ctx->running)) {
        size_t count = atomic_load(&ctx->watch_count);

        /* Scan watch list for ready flags */
        for (size_t i = 0; i < count; /* manual increment */) {
            TpWatchEntry* entry = &ctx->watch_list[i];

            if (atomic_load(entry->ready_flag)) {
                /* Swap the pointer, then clear the flag: the atomic store
                 * publishes the new pointer to whoever sees the flag clear */
                *entry->target_ptr = entry->source_ptr;
                atomic_store(entry->ready_flag, false);

                /* Remove from list: swap with last, decrement count */
                tp_spin_lock(&ctx->watch_lock);
                count = atomic_load(&ctx->watch_count);
                if (count > 0 && i < count) {
                    ctx->watch_list[i] = ctx->watch_list[count - 1];
                    atomic_store(&ctx->watch_count, count - 1);
                    count--;
                }
                tp_spin_unlock(&ctx->watch_lock);

                atomic_fetch_add(&ctx->swaps_performed, 1);
                /* Don't increment i - check swapped-in entry */
            } else {
                i++;
            }
        }

        /* Brief yield when list is empty */
        if (count == 0) {
            atomic_fetch_add(&ctx->idle_cycles, 1);
            tp_sleep_us(100);  /* 0.1ms */
        }
    }

    SYNC_LOG(ctx, "[threadpool_sync] Exiting (swaps: %" PRIu64 ", idle cycles: %" PRIu64 ")\n",
             atomic_load(&ctx->swaps_performed), atomic_load(&ctx->idle_cycles));
    return NULL;
}
/* }}} */

/* {{{ tp_sync_spawn
 * Creates and starts the sync thread.
 * Returns thread handle (zeroed if the thread could not start). */
tp_thread_t tp_sync_spawn(TpSyncContext* ctx) {
    tp_thread_t thread;
    memset(&thread, 0, sizeof(thread));
    if (!ctx) return thread;

    atomic_store(&ctx->running, true);
    int result = tp_thread_create(&thread, sync_loop, ctx);
    if (result != 0) {
        SYNC_LOG(ctx, "[threadpool_sync] Failed to create sync thread\n");
        memset(&thread, 0, sizeof(thread));
    } else {
        SYNC_LOG(ctx, "[threadpool_sync] Sync thread spawned\n");
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
    return ctx ? atomic_load(&ctx->swaps_performed) : 0;
}
/* }}} */

/* {{{ tp_sync_get_idle_cycles
 * Returns number of idle cycles (when watch list was empty). */
uint64_t tp_sync_get_idle_cycles(TpSyncContext* ctx) {
    return ctx ? atomic_load(&ctx->idle_cycles) : 0;
}
/* }}} */
