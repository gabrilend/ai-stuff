# Issue 512f: Main.c Threading Integration

**Phase:** 5 - Rendering
**Type:** Bug Fix / Integration
**Priority:** High
**Dependencies:** 512a-512e (threading v2 architecture)

---

## Current Behavior

Issue 512 rewrote the threading infrastructure with a new ring-buffer task-based API, but
main.c still uses the old buffer-based API. The two are incompatible:

**Old API (what main.c expects):**
- `WorkerContext` with slot_start/slot_end
- `WorkerBuffers` with input/output locks
- `pool_set_process_fn()` and `pool_set_primary_buffer()`
- Fixed input/output buffer pairs per worker

**New API (512 implementation):**
- `WorkerTask` function pointers
- Ring buffer task lists per worker
- `find_least_busy_worker()` for load balancing
- Self-evaluating updaters

**Result:** main.c doesn't compile with new threading.h

---

## Workaround Applied

Temporarily restored old threading.h/c to allow main.c to compile.
The new threading v2 code is preserved in test_threading_v2.c for future integration.

---

## Intended Behavior

main.c should be updated to use the new threading v2 API, OR a compatibility layer
should bridge the two approaches.

---

## Suggested Implementation Steps

### Option A: Full Migration

1. Rewrite main.c's worker functions as WorkerTask instances
2. Replace `sync_to_primary()` with sync watch list pattern
3. Replace `custom_updater_loop()` with UpdaterContext
4. Test with profiler to verify performance

### Option B: Compatibility Layer

1. Create `threading_compat.h` that provides old API on top of new
2. Implement `pool_set_process_fn()` to create tasks from function pointer
3. Implement buffer pairs using ring buffer slots
4. Minimal changes to main.c

### Option C: Parallel APIs

1. Keep both threading.h (old) and threading_v2.h (new)
2. New code uses v2, old code uses v1
3. Eventually migrate all code to v2

---

## Acceptance Criteria

- [ ] main.c compiles with new threading API
- [ ] Render demo runs correctly
- [ ] Profiler shows per-thread timing
- [ ] Performance comparable to old implementation

---

## Notes

The 512 unit tests (test_threading.c) all pass - the new API works correctly in isolation.
The integration gap is main.c not being updated to use it.

For now, old threading API is restored so the render demo works.
