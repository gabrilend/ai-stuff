/*
 * Threadpool Sync Module
 *
 * Optional module for coordinated pointer updates (watch list pattern).
 * Common use cases: double-buffering, render pipelines, producer-consumer patterns.
 *
 * The sync thread continuously polls ready flags and performs pointer swaps
 * when ready. This non-blocking approach is more responsive than condition
 * variables for high-frequency updates.
 *
 * Handoff rule: the sync thread writes *target_ptr and THEN clears ready_flag
 * (an atomic store). A thread that reads *target_ptr after it has seen
 * ready_flag go back to false is guaranteed to see the new pointer. Reading
 * *target_ptr at any other time races with the swap.
 */

#ifndef THREADPOOL_SYNC_H
#define THREADPOOL_SYNC_H

#include "threadpool_platform.h"
#include <stdbool.h>
#include <stdatomic.h>
#include <stdint.h>

/* {{{ WatchEntry
 * An entry in the sync thread's watch list.
 * When ready_flag becomes true, target_ptr is set to source_ptr. */
typedef struct tp_watch_entry {
    atomic_bool* ready_flag;    /* Worker sets true when output ready */
    void** target_ptr;          /* Primary buffer slot to update */
    void* source_ptr;           /* New pointer value */
} TpWatchEntry;
/* }}} */

/* {{{ TpSyncContext
 * State for the sync thread. */
typedef struct tp_sync_context {
    TpWatchEntry* watch_list;
    size_t watch_capacity;
    atomic_size_t watch_count;

    atomic_bool running;

    /* Lock for adding entries */
    tp_spinlock_t watch_lock;

    /* Stats (written by the sync thread, read from anywhere) */
    _Atomic uint64_t swaps_performed;
    _Atomic uint64_t idle_cycles;

    /* Optional logging callback copied from the config (NULL = silent) */
    void (*log_fn)(const char* fmt, ...);
} TpSyncContext;
/* }}} */

/* {{{ TpSyncConfig
 * Configuration for sync module. */
typedef struct tp_sync_config {
    size_t watch_list_size;     /* Default: 2048 */
    void (*log_fn)(const char* fmt, ...);  /* Optional logging callback */
} TpSyncConfig;
/* }}} */

/* {{{ Configuration */

/* Get default sync configuration */
TpSyncConfig tp_sync_config_default(void);

/* }}} */

/* {{{ Lifecycle */

/* Create sync context with specified configuration (NULL = defaults)
 * Returns NULL on allocation failure */
TpSyncContext* tp_sync_create(TpSyncConfig* config);

/* Destroy sync context and free resources */
void tp_sync_destroy(TpSyncContext* ctx);

/* }}} */

/* {{{ Watch List Management */

/* Add an entry to the watch list (thread-safe)
 * Returns false if watch list is full */
bool tp_sync_add_watch(TpSyncContext* ctx,
                       atomic_bool* ready_flag,
                       void** target_ptr,
                       void* source_ptr);

/* }}} */

/* {{{ Thread Control */

/* Spawn the sync thread
 * Returns thread handle; join it with tp_thread_join() after
 * tp_sync_stop(). If the thread cannot be started, logs and returns a
 * zeroed handle, and the context stays usable for another try. */
tp_thread_t tp_sync_spawn(TpSyncContext* ctx);

/* Stop the sync thread (sets running flag to false)
 * Thread will exit on next iteration */
void tp_sync_stop(TpSyncContext* ctx);

/* }}} */

/* {{{ Statistics */

/* Get number of pointer swaps performed */
uint64_t tp_sync_get_swaps(TpSyncContext* ctx);

/* Get number of idle cycles (when watch list was empty) */
uint64_t tp_sync_get_idle_cycles(TpSyncContext* ctx);

/* }}} */

#endif /* THREADPOOL_SYNC_H */
