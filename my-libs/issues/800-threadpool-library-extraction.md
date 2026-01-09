# Issue 800: Threadpool Library Extraction

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None (uses existing code from src/render/threading.*)

---

## Current Behavior

Threading infrastructure lives in `src/render/threading.h` and `threading.c` as part of
the render system. The implementation is already general-purpose (workers execute function
pointers, not render-specific code), but:

- Located within render directory, implying render-specific use
- Hardcoded constants (TASK_LIST_SIZE, WATCH_LIST_SIZE, timing thresholds)
- Debug printf statements embedded in implementation
- No standalone test suite
- Sync/watch-list tightly coupled with core pool
- Cannot be reused in other projects without copying files

## Intended Behavior

A modular, reusable threadpool library at `/home/ritz/programming/ai-stuff/my-libs/threadpool/`
with the following characteristics:

1. **Modular architecture:**
   - Core module: WorkerPool, Worker, WorkerTask, ring buffer management
   - Sync module (optional): SyncContext, WatchEntry, pointer swap coordination
   - Updater module (optional): UpdaterContext, self-evaluating task distribution

2. **Configurable via runtime struct:**
   ```c
   typedef struct threadpool_config {
       size_t task_list_size;
       size_t watch_list_size;
       uint64_t target_tick_us;
       uint64_t continuation_threshold_us;
       void (*log_fn)(const char* fmt, ...);
   } ThreadpoolConfig;
   ```

3. **Logging via runtime callback** - NULL callback means no logging, negligible
   performance impact (single pointer check per log call).

4. **POSIX-only initially** - pthread dependency documented, Windows support planned
   as future enhancement.

5. **Standalone test suite** - Verify core functionality independent of render system.

## Suggested Implementation Steps

1. Create library directory structure at `my-libs/threadpool/`
2. Extract core threadpool module (800a):
   - WorkerPool, Worker, WorkerTask structs
   - pool_create(), pool_destroy(), task_append()
   - find_least_busy_worker(), ring buffer management
   - Configuration struct with defaults
3. Extract sync module (800b):
   - SyncContext, WatchEntry structs
   - sync_create(), sync_destroy(), sync_add_watch()
   - spawn_sync_thread(), sync_loop()
4. Extract updater module (800c):
   - UpdaterContext, self-evaluating patterns
   - updater_create(), updater_start()
   - primary_updater_execute(), helper spawning
5. Create test suite (800d):
   - test_pool.c - create/destroy, task execution
   - test_sync.c - watch list, pointer swaps
   - test_updater.c - load-based continuation
6. Update render system to use library (800e):
   - Replace src/render/threading.* with library include
   - Verify demo_threading.c still works
7. Document Windows support requirements (800f):
   - Create future issue for win32 threads abstraction

## Acceptance Criteria

- [x] Library compiles standalone without render system dependencies
- [x] Core module usable without sync or updater modules
- [x] Sync module usable with just core (no updater required)
- [x] Full stack (core + sync + updater + scheduler) matches current functionality
- [x] Runtime configuration works (custom sizes, thresholds, logging)
- [x] NULL log callback has negligible overhead
- [x] Test suite passes (24 tests across 4 test files)
- [ ] Render demo still functions after migration (Issue 800e)
- [x] Library location: `/home/ritz/programming/ai-stuff/my-libs/threadpool/`

## Related Documents

- `src/render/threading.h` - Current implementation header
- `src/render/threading.c` - Current implementation
- `docs/render-threading-v2.md` - Architecture specification
- `docs/render-architecture.md` - Usage context

## Notes

This extraction preserves several novel patterns worth reusing:
- Self-evaluating updaters with continuation threshold (50% of target tick)
- Weighted load balancing via atomic counters
- Ring buffer task lists with relocate-on-wrap
- Parallel sync watch list (non-blocking pointer swaps)

The modular design allows users to pick complexity level:
- Just need a thread pool? Use core module only.
- Need coordinated pointer updates? Add sync module.
- Need adaptive task distribution? Add updater module.
- Need deferred task scheduling? Add scheduler module.

## Implementation Summary

**Status:** Mostly Complete (5/8 sub-issues done)
**Completed:** 2026-01-08

Successfully extracted and modularized threading infrastructure into reusable library:

**Modules Implemented:**
1. Core module (800a) - Worker pools, ring buffers, load balancing
2. Sync module (800b) - Watch list pattern for pointer coordination
3. Updater module (800c) - Self-evaluating task distributors
4. Scheduler module (800g) - Absolute time-based deferred task assignment
5. Test suite (800d) - 24 tests covering all modules

**Key Features:**
- Runtime configuration via config structs
- Optional logging callbacks (NULL = silent, negligible overhead)
- Modular architecture (pick what you need)
- Thread-safe with atomic operations
- Comprehensive test coverage

**Remaining Work:**
- 800e: Migrate render system to use library (validates extraction)
- 800f: Windows support planning (design doc, future work)

Library is ready for use and thoroughly tested.
