# Issue 800a: Core Threadpool Module

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** High
**Dependencies:** None
**Parent:** 800-threadpool-library-extraction.md

---

## Current Behavior

Core threadpool functionality (WorkerPool, Worker, WorkerTask, ring buffer) is embedded
in `src/render/threading.c` with:

- Hardcoded constants: TASK_LIST_SIZE=1024, weight definitions
- printf debug statements
- Coupled with SyncContext and UpdaterContext in same file

## Intended Behavior

Standalone core module at `my-libs/threadpool/` providing:

```c
/* Configuration with sensible defaults */
typedef struct tp_config {
    size_t task_list_size;      /* Default: 1024 */
    void (*log_fn)(const char* fmt, ...);  /* NULL = no logging */
} TpConfig;

/* Public API */
TpConfig tp_config_default(void);
WorkerPool* tp_pool_create(TpConfig* config, int worker_count);
void tp_pool_destroy(WorkerPool* pool);
bool tp_task_append(Worker* w, WorkerTask* task);
Worker* tp_find_least_busy(WorkerPool* pool);
Worker* tp_find_least_busy_excluding(WorkerPool* pool, int exclude_id);
unsigned int tp_pool_get_load(WorkerPool* pool);
```

## Suggested Implementation Steps

1. Create directory structure:
   ```
   my-libs/threadpool/
   ├── threadpool.h       # Core public API
   ├── threadpool.c       # Core implementation
   ├── threadpool_config.h # Configuration struct and defaults
   └── internal/
       └── ring_buffer.h  # Ring buffer utilities (internal)
   ```

2. Define configuration struct in `threadpool_config.h`:
   - task_list_size with default
   - log callback (NULL for silent operation)
   - Weight constants as defines (user can override before include)

3. Extract from threading.h:
   - WorkerTask struct (unchanged)
   - Worker struct (unchanged)
   - WorkerPool struct (unchanged)
   - Weight constants as defaults

4. Extract from threading.c:
   - get_timestamp_us()
   - sleep_task()
   - relocate_task()
   - task_append() → tp_task_append()
   - find_least_busy_worker() → tp_find_least_busy()
   - find_least_busy_worker_excluding() → tp_find_least_busy_excluding()
   - worker_loop()
   - pool_create() → tp_pool_create()
   - pool_destroy() → tp_pool_destroy()
   - pool_get_total_load() → tp_pool_get_load()

5. Replace printf with conditional log callback:
   ```c
   #define TP_LOG(cfg, fmt, ...) \
       do { if ((cfg)->log_fn) (cfg)->log_fn(fmt, ##__VA_ARGS__); } while(0)
   ```

6. Store config pointer in WorkerPool for log access:
   ```c
   typedef struct worker_pool {
       Worker* workers;
       int count;
       atomic_bool running;
       TpConfig config;  /* Copy of config for logging */
   } WorkerPool;
   ```

## Acceptance Criteria

- [x] Core module compiles standalone (no sync/updater dependencies)
- [x] tp_config_default() returns working configuration
- [x] tp_pool_create(NULL, 0) works (NULL config = defaults, 0 = auto-detect cores)
- [x] Tasks execute correctly via ring buffer
- [x] Load balancing via tp_find_least_busy() works
- [x] Ring buffer relocation triggers at appropriate threshold
- [x] NULL log callback produces no output and minimal overhead
- [x] Custom log callback receives all log messages

## Files to Create

- `my-libs/threadpool/threadpool.h`
- `my-libs/threadpool/threadpool.c`
- `my-libs/threadpool/threadpool_config.h`

## Notes

The core module is the foundation - sync and updater modules depend on it but are
optional. Users who just need a simple thread pool with task queues can use this
module alone.

Key insight: Store TpConfig as value (not pointer) in WorkerPool so it persists
after tp_pool_create() returns. This also allows per-pool logging configuration.

---

## Implementation Notes

**Date:** 2026-01-05

### Files Created

| File | Purpose |
|------|---------|
| `threadpool/src/threadpool_config.h` | Configuration struct, defaults, weight constants, TP_LOG macro |
| `threadpool/src/threadpool.h` | Public API: TpTask, TpWorker, TpPool structs and functions |
| `threadpool/src/threadpool.c` | Core implementation (~300 lines) |
| `threadpool/tests/test_pool.c` | Test suite (6 tests) |
| `threadpool/Makefile` | Build system |

### API Changes from Original

| Original | Library | Notes |
|----------|---------|-------|
| `WorkerTask` | `TpTask` | Prefixed for namespace |
| `Worker` | `TpWorker` | Prefixed for namespace |
| `WorkerPool` | `TpPool` | Prefixed for namespace |
| `pool_create()` | `tp_pool_create()` | Accepts TpConfig* (NULL = defaults) |
| `pool_destroy()` | `tp_pool_destroy()` | Unchanged behavior |
| `task_append()` | `tp_task_append()` | Unchanged behavior |
| `find_least_busy_worker()` | `tp_find_least_busy()` | Shortened name |
| `find_least_busy_worker_excluding()` | `tp_find_least_busy_excluding()` | Shortened name |
| `pool_get_total_load()` | `tp_pool_get_load()` | Shortened name |
| `sleep_task()` | `tp_sleep_task()` | Prefixed |
| `relocate_task()` | `tp_relocate_task()` | Prefixed |

### Build Notes

- Requires `-D_GNU_SOURCE` for usleep() on glibc systems
- Requires `-pthread` for pthread functions
- Uses C11 standard (`-std=c11`) for stdatomic.h

### Test Results

All 6 tests pass:
- `test_pool_create_defaults` - NULL config, 0 workers
- `test_pool_create_specific_count` - Specific worker count
- `test_pool_with_logging` - Custom log callback
- `test_task_execution` - Tasks execute and complete
- `test_load_balancing` - Weighted distribution works
- `test_repeat_count` - Multiple executions per task
