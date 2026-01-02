/*
 * Threading Infrastructure for Render System
 *
 * Implements the staged threading model from docs/render-architecture.md:
 * - Updater thread populates worker input buffers
 * - Worker threads compute GPU-ready data (always busy)
 * - Sync thread swaps outputs to primary buffer (near-zero work)
 * - Draw thread reads primary buffer (near-zero work)
 *
 * Workers do heavy computation; sync/draw do pointer operations only.
 */

#ifndef THREADING_H
#define THREADING_H

#include <pthread.h>
#include <stdbool.h>
#include <stdatomic.h>

/* {{{ Configuration */
#define MAX_WORKERS 4
#define DEFAULT_WORKERS 2
/* }}} */

/* {{{ WorkerInput - data fed to workers by updater
 * Contains game state snapshot for workers to process.
 * Workers read this, never write to it. */
typedef struct worker_input {
    /* Game tick number (for sync detection) */
    unsigned int tick;

    /* Number of entities to process */
    int entity_count;

    /* Entity data array (positions, states, etc.)
     * This is a snapshot - workers can read freely */
    void* entity_data;

    /* Additional context (camera, time, etc.) */
    float game_time;
    float camera_x, camera_y, camera_z;
} WorkerInput;
/* }}} */

/* {{{ WorkerOutput - computed results from workers
 * Contains GPU-ready render data.
 * Workers write this, sync thread reads it. */
typedef struct worker_output {
    /* Tick this output corresponds to */
    unsigned int tick;

    /* Number of render slots updated */
    int slot_count;

    /* Pointer to computed slot data
     * This gets swapped into primary buffer by sync */
    void* slot_data;
} WorkerOutput;
/* }}} */

/* {{{ WorkerBuffers - per-worker input/output pair */
typedef struct worker_buffers {
    WorkerInput input;
    WorkerOutput output;

    /* Flag set by worker when output is ready */
    atomic_bool output_ready;

    /* Lock for input updates (updater writes, worker reads) */
    pthread_mutex_t input_lock;

    /* Lock for output swaps (worker writes, sync reads) */
    pthread_mutex_t output_lock;
} WorkerBuffers;
/* }}} */

/* {{{ WorkerContext - passed to each worker thread */
typedef struct worker_context {
    int worker_id;
    WorkerBuffers* buffers;
    struct worker_pool* pool;

    /* Slot range this worker is responsible for */
    int slot_start;
    int slot_end;
} WorkerContext;
/* }}} */

/* {{{ WorkerPool - manages all worker threads */
typedef struct worker_pool {
    pthread_t threads[MAX_WORKERS];
    WorkerContext contexts[MAX_WORKERS];
    WorkerBuffers buffers[MAX_WORKERS];
    int count;

    /* Running flag - set false to shutdown */
    atomic_bool running;

    /* Pointer to primary buffer (owned by main/draw) */
    void* primary_buffer;

    /* Processing function pointer
     * Signature: void process(WorkerContext* ctx, void* input, void* output) */
    void (*process_fn)(WorkerContext*, void*, void*);
} WorkerPool;
/* }}} */

/* {{{ SyncContext - passed to sync thread */
typedef struct sync_context {
    WorkerPool* pool;
    void* primary_buffer;
    atomic_bool* running;

    /* Stats */
    unsigned int swaps_performed;
    unsigned int idle_cycles;
} SyncContext;
/* }}} */

/* {{{ UpdaterContext - passed to updater thread */
typedef struct updater_context {
    WorkerPool* pool;
    atomic_bool* running;

    /* Input source callback
     * Returns true if new input was provided */
    bool (*get_input)(WorkerInput* out);

    /* Stats */
    unsigned int updates_sent;
    unsigned int idle_cycles;
} UpdaterContext;
/* }}} */

/* {{{ Function Declarations */

/* Pool lifecycle */
WorkerPool* pool_create(int worker_count);
void pool_destroy(WorkerPool* pool);
void pool_set_process_fn(WorkerPool* pool, void (*fn)(WorkerContext*, void*, void*));
void pool_set_primary_buffer(WorkerPool* pool, void* buffer);

/* Thread entry points (used internally, exposed for testing) */
void* worker_loop(void* arg);
void* sync_loop(void* arg);
void* updater_loop(void* arg);

/* Thread spawning */
pthread_t spawn_sync_thread(SyncContext* ctx);
pthread_t spawn_updater_thread(UpdaterContext* ctx);

/* Utility */
void distribute_input_to_workers(WorkerPool* pool, WorkerInput* input);
bool has_any_output_ready(WorkerPool* pool);

/* }}} */

#endif /* THREADING_H */
