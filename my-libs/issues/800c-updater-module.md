# Issue 800c: Updater Module (Self-Evaluating Task Distribution)

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 800a-core-threadpool-module.md
**Parent:** 800-threadpool-library-extraction.md

---

## Current Behavior

Updater functionality (UpdaterContext, self-evaluating helpers, adaptive spawning)
is in `src/render/threading.c`. The updater distributes tasks to workers and spawns
helper updaters when overloaded, which self-terminate when load decreases.

## Intended Behavior

Optional updater module for users who need adaptive task distribution with
self-regulating helper spawning.

```c
/* Updater-specific configuration */
typedef struct tp_updater_config {
    uint64_t target_tick_us;            /* Default: 10000 (10ms = 100Hz) */
    uint64_t continuation_threshold_us; /* Default: 5000 (50% of target) */
    uint64_t overload_threshold_us;     /* Default: 5000 */
    void (*log_fn)(const char* fmt, ...);
} TpUpdaterConfig;

/* Task source callback - user provides pending tasks */
typedef bool (*TpTaskSource)(void* user_data, WorkerTask** out_tasks, size_t* out_count);

/* Public API */
TpUpdaterConfig tp_updater_config_default(void);
UpdaterContext* tp_updater_create(WorkerPool* pool, TpUpdaterConfig* config,
                                   TpTaskSource source, void* user_data);
void tp_updater_destroy(UpdaterContext* ctx);
void tp_updater_start(UpdaterContext* ctx);

/* Statistics */
unsigned int tp_updater_get_active_count(void);  /* Global across all updaters */
uint64_t tp_updater_get_last_tick_us(UpdaterContext* ctx);
```

## Suggested Implementation Steps

1. Create updater module files:
   ```
   my-libs/threadpool/
   ├── threadpool_updater.h    # Updater public API
   └── threadpool_updater.c    # Updater implementation
   ```

2. Extract from threading.h:
   - UpdaterContext struct (generalize get_pending_tasks callback)
   - WEIGHT_UPDATER constant

3. Extract from threading.c:
   - g_active_updater_count (global atomic)
   - updater_create() → tp_updater_create()
   - updater_destroy() → tp_updater_destroy()
   - updater_start() → tp_updater_start()
   - primary_updater_execute()
   - helper_updater_execute()
   - helper_updater_on_complete()
   - updater_on_complete() (static)
   - spawn_helper_updater()

4. Generalize task source callback:
   - Current: `bool (*get_pending_tasks)(UpdaterContext*, WorkerTask**, size_t*)`
   - New: `typedef bool (*TpTaskSource)(void* user_data, WorkerTask** out, size_t* count)`
   - Cleaner separation - user provides tasks, updater distributes them

5. Add configurable thresholds:
   - target_tick_us (when to consider overloaded)
   - continuation_threshold_us (when helpers should persist)
   - overload_threshold_us (when to spawn replacement)

## Acceptance Criteria

- [x] Updater module compiles with only core module as dependency
- [x] Updater module is optional (core + sync work without it)
- [x] Primary updater runs forever (repeat_count = INT16_MAX pattern)
- [x] Helper updaters spawn when overloaded
- [x] Helper updaters self-terminate when load decreases (< 50% threshold)
- [x] Task source callback receives user_data correctly
- [x] Thresholds are configurable
- [x] Active updater count accessible globally

## Files to Create

- `my-libs/threadpool/threadpool_updater.h`
- `my-libs/threadpool/threadpool_updater.c`

## Notes

The self-evaluating pattern is the novel contribution of this threading model:

1. Updater is a worker task, not a special thread type
2. When repeat_count reaches 0, updater evaluates its own timing
3. If last tick > 50% of target: recreate (might land on different worker)
4. If last tick <= 50% of target: don't recreate (exit gracefully)

This creates natural load-responsive scaling without explicit thread management.
The "50% continuation threshold" is key - it's conservative enough that helpers
stick around under moderate load but disappear quickly when truly idle.

## Implementation Notes

**Completed:** 2026-01-08

Created two files in `my-libs/threadpool/src/`:
- `threadpool_updater.h` - Public API with TpUpdaterContext, TpUpdaterConfig
- `threadpool_updater.c` - Implementation extracted from threading.c

Key changes from original:
- Renamed types: UpdaterContext → TpUpdaterContext
- Added TpUpdaterConfig for configurable timing thresholds and logging
- Generalized task source callback to use user_data instead of context pointer
- Static g_active_updater_count for cross-pool coordination
- All execute functions (primary, helper) made static (internal)
- Added tp_updater_get_active_count() and tp_updater_get_last_tick_us() for statistics

The module depends only on the core threadpool module and implements the
full self-evaluating pattern with adaptive helper spawning.
Testing will be added in issue 800d (test suite).
