/*
 * Threading Infrastructure
 *
 * General-purpose thread pool with ring buffer task lists.
 * See docs/render-threading-v2.md for architecture specification.
 *
 * Key changes from v1:
 * - Workers execute function pointers from ring buffers (not fixed slots)
 * - Worker count scales to CPU cores
 * - Load balancing via weighted task counts
 * - Sync uses watch list (no blocking)
 */

#ifndef THREADING_V2_H
#define THREADING_V2_H

#include <pthread.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdint.h>

/* {{{ Configuration */
#define TASK_LIST_SIZE 1024     /* Ring buffer capacity per worker */
#define WATCH_LIST_SIZE 2048    /* Sync watch list capacity */
#define TARGET_TICK_US 16000    /* 16ms = 62.5Hz (WC3 tick rate) */
#define CONTINUATION_THRESHOLD_US 8000  /* 50% of target */
/* }}} */

/* {{{ Task Weight Constants
 * Used for load balancing. Higher weight = more expensive task. */
#define WEIGHT_SLEEP   0        /* No-op task */
#define WEIGHT_LIGHT   1        /* Simple operations */
#define WEIGHT_MEDIUM  5        /* Standard render slot */
#define WEIGHT_HEAVY   20       /* Complex physics/AI */
#define WEIGHT_UPDATER 10       /* Updater task */
/* }}} */

/* Forward declarations */
struct worker;
struct worker_pool;

/* {{{ WorkerTask
 * A task is a function pointer with context and metadata.
 * Workers execute these from their ring buffer. */
typedef struct worker_task {
    /* Function to execute */
    void (*execute)(void* context);

    /* Optional callback when repeat_count reaches 0 */
    void (*on_complete)(void* context);

    /* Task-specific data passed to execute/on_complete */
    void* context;

    /* Cost estimate for load balancing (higher = heavier) */
    uint16_t weight;

    /* Repeat behavior:
     *  N > 0 = run N more times then call on_complete
     *  0 = already completed (skip this slot)
     *  N < 0 = treat as 0 (completed), -1 does NOT mean infinite
     * Use INT16_MAX (32767) for "essentially infinite" execution */
    int16_t repeat_count;
} WorkerTask;
/* }}} */

/* {{{ Worker
 * A worker thread with a ring buffer of tasks. */
typedef struct worker {
    pthread_t thread;
    int worker_id;

    /* Task ring buffer */
    WorkerTask* task_list;
    size_t task_list_size;
    size_t start_ptr;           /* Current execution position */
    size_t end_ptr;             /* Next write position */

    /* Load balancing: weighted sum of pending task weights */
    atomic_uint num_tasks;

    /* Shutdown flag */
    atomic_bool running;

    /* Back-reference to pool */
    struct worker_pool* pool;
} Worker;
/* }}} */

/* {{{ WorkerPool
 * Manages all worker threads. */
typedef struct worker_pool {
    Worker* workers;
    int count;

    /* Global shutdown flag */
    atomic_bool running;
} WorkerPool;
/* }}} */

/* {{{ WatchEntry
 * An entry in the sync thread's watch list.
 * When ready_flag becomes true, target_ptr is set to source_ptr. */
typedef struct watch_entry {
    atomic_bool* ready_flag;    /* Worker sets true when output ready */
    void** target_ptr;          /* Primary buffer slot to update */
    void* source_ptr;           /* New pointer value */
} WatchEntry;
/* }}} */

/* {{{ SyncContext
 * State for the sync thread. */
typedef struct sync_context {
    WatchEntry* watch_list;
    size_t watch_capacity;
    atomic_size_t watch_count;

    atomic_bool running;

    /* Lock for adding entries */
    pthread_spinlock_t watch_lock;

    /* Stats */
    uint64_t swaps_performed;
    uint64_t idle_cycles;
} SyncContext;
/* }}} */

/* {{{ Function Declarations - Pool Lifecycle */

/* Create a worker pool with specified count (0 = auto-detect CPU cores) */
WorkerPool* pool_create(int worker_count);

/* Destroy pool, join all threads, free resources */
void pool_destroy(WorkerPool* pool);

/* Get total weighted load across all workers */
unsigned int pool_get_total_load(WorkerPool* pool);
/* }}} */

/* {{{ Function Declarations - Task Management */

/* Append a task to a worker's ring buffer
 * Returns false if buffer is full */
bool task_append(Worker* w, WorkerTask* task);

/* Find the worker with lowest num_tasks */
Worker* find_least_busy_worker(WorkerPool* pool);

/* Default task that sleeps for one tick */
void sleep_task(void* context);

/* Task that compacts the ring buffer (internal use) */
void relocate_task(void* context);
/* }}} */

/* {{{ Function Declarations - Sync Thread */

/* Create sync context with specified watch list capacity */
SyncContext* sync_create(size_t capacity);

/* Destroy sync context */
void sync_destroy(SyncContext* ctx);

/* Add an entry to the watch list (thread-safe) */
bool sync_add_watch(SyncContext* ctx,
                    atomic_bool* ready_flag,
                    void** target_ptr,
                    void* source_ptr);

/* Spawn the sync thread */
pthread_t spawn_sync_thread(SyncContext* ctx);

/* Sync thread entry point */
void* sync_loop(void* arg);
/* }}} */

/* {{{ UpdaterContext
 * Context for self-evaluating updater tasks.
 * Updaters distribute tasks to workers and monitor timing.
 *
 * Dynamic scaling: When repeat_count reaches 0, updater evaluates:
 * - If only 1 updater active: re-spawn with INT16_MAX repeat_count
 * - If multiple updaters and last update > 5ms: spawn replacement, terminate
 * - Otherwise: terminate (allow pool to shrink)
 */
typedef struct updater_context {
    WorkerPool* pool;

    /* Task source callback
     * Returns true if new tasks are available, populates out and count */
    bool (*get_pending_tasks)(struct updater_context* ctx,
                              WorkerTask** out,
                              size_t* count);

    /* User-defined data for the callback */
    void* user_data;

    /* Partition this updater handles (for helper splitting) */
    size_t partition_start;
    size_t partition_end;

    /* Timing measurement */
    uint64_t last_tick_duration_us;

    /* Is this the primary updater (runs forever) or a helper (runs once)? */
    bool is_primary;

    /* For helper cleanup: was this context dynamically allocated? */
    bool is_allocated;

    /* Back-reference to the WorkerTask this context is attached to
     * Used by on_complete to modify repeat_count for continuation */
    WorkerTask* task_ref;
} UpdaterContext;

/* Global active updater count - for dynamic scaling decisions */
extern atomic_uint g_active_updater_count;

/* Threshold for spawning replacement updater (microseconds) */
#define UPDATER_OVERLOAD_THRESHOLD_US 8000
/* }}} */

/* {{{ Function Declarations - Updater */

/* Create an updater context (primary updater) */
UpdaterContext* updater_create(WorkerPool* pool,
                               bool (*get_pending_tasks)(UpdaterContext*, WorkerTask**, size_t*),
                               void* user_data);

/* Destroy an updater context */
void updater_destroy(UpdaterContext* ctx);

/* Start the primary updater as a worker task */
void updater_start(UpdaterContext* ctx);

/* Primary updater execute function (runs forever, spawns helpers) */
void primary_updater_execute(void* arg);

/* Helper updater execute function (runs once, distributes partition) */
void helper_updater_execute(void* arg);

/* Helper self-evaluation callback (decides whether to continue) */
void helper_updater_on_complete(void* arg);

/* Spawns a helper updater to handle part of the workload */
void spawn_helper_updater(UpdaterContext* primary, size_t partition_start, size_t partition_end);
/* }}} */

/* {{{ Function Declarations - Utilities */

/* Get current timestamp in microseconds */
uint64_t get_timestamp_us(void);

/* Worker thread entry point */
void* worker_loop(void* arg);
/* }}} */

#endif /* THREADING_V2_H */
