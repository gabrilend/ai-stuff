# Issue 512f: Main.c Threading Integration

**Phase:** 5 - Rendering
**Type:** Integration / Migration
**Priority:** High
**Dependencies:** 512a-512e (threading v2 architecture)

---

## Threading Architecture Comparison

### Architecture v1 (Current - What main.c Uses)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     FIXED BUFFER ARCHITECTURE                            │
│                                                                          │
│  ┌────────────────┐                                                      │
│  │ UPDATER THREAD │                                                      │
│  │ get_input() ───┼──▶ Populates WorkerInput for all workers            │
│  │                │    (game_time, camera, entity_data)                  │
│  └───────┬────────┘                                                      │
│          │ writes to                                                     │
│          ▼                                                               │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    WORKER POOL (fixed N workers)                  │   │
│  │                                                                   │   │
│  │   Worker 0                    Worker 1                            │   │
│  │   ┌────────────────────┐     ┌────────────────────┐              │   │
│  │   │ WorkerBuffers      │     │ WorkerBuffers      │              │   │
│  │   │ ┌────────────────┐ │     │ ┌────────────────┐ │              │   │
│  │   │ │ WorkerInput    │ │     │ │ WorkerInput    │ │              │   │
│  │   │ │ - tick         │ │     │ │ - tick         │ │              │   │
│  │   │ │ - game_time    │ │     │ │ - game_time    │ │              │   │
│  │   │ │ - entity_data  │ │     │ │ - entity_data  │ │              │   │
│  │   │ └────────────────┘ │     │ └────────────────┘ │              │   │
│  │   │ ┌────────────────┐ │     │ ┌────────────────┐ │              │   │
│  │   │ │ WorkerOutput   │ │     │ │ WorkerOutput   │ │              │   │
│  │   │ │ - tick         │ │     │ │ - tick         │ │              │   │
│  │   │ │ - slot_data    │ │     │ │ - slot_data    │ │              │   │
│  │   │ └────────────────┘ │     │ └────────────────┘ │              │   │
│  │   │ output_ready flag  │     │ output_ready flag  │              │   │
│  │   │ input_lock         │     │ input_lock         │              │   │
│  │   │ output_lock        │     │ output_lock        │              │   │
│  │   └────────────────────┘     └────────────────────┘              │   │
│  │                                                                   │   │
│  │   WorkerContext:                                                  │   │
│  │   - worker_id: 0              - worker_id: 1                      │   │
│  │   - slot_start: 0             - slot_start: 2048                  │   │
│  │   - slot_end: 2047            - slot_end: 4095                    │   │
│  │                                                                   │   │
│  │   process_fn(ctx, input, output) called in loop                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│          │ sets output_ready                                             │
│          ▼                                                               │
│  ┌────────────────┐                                                      │
│  │  SYNC THREAD   │                                                      │
│  │                │                                                      │
│  │  Polls each worker's output_ready flag                               │
│  │  When ready: lock, copy slot_data to primary buffer, unlock           │
│  └───────┬────────┘                                                      │
│          │                                                               │
│          ▼                                                               │
│  ┌────────────────┐                                                      │
│  │ PRIMARY BUFFER │ ◄──────── DRAW THREAD reads (main thread)            │
│  │ (slot_data)    │                                                      │
│  └────────────────┘                                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key Characteristics:**
- Fixed number of workers (typically 2)
- Each worker has dedicated input/output buffer pair
- Workers have fixed slot ranges (slot_start to slot_end)
- Single process function applied to all workers
- Sync thread polls each worker sequentially
- Mutex locks for input and output access

**Data Flow:**
```
1. Updater: get_input() → WorkerInput struct with game state
2. Updater: distribute_input_to_workers() → copies to each worker's input buffer
3. Worker: process_fn(ctx, input, output) → computes render data
4. Worker: atomic_store(&output_ready, true)
5. Sync: polls output_ready, locks, copies to primary buffer
6. Draw: reads primary buffer (no synchronization needed)
```

---

### Architecture v2 (Target - What 512 Implemented)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     RING BUFFER TASK ARCHITECTURE                        │
│                                                                          │
│  ┌────────────────────────┐                                              │
│  │   UPDATER (as task)    │                                              │
│  │   - Is a WorkerTask    │                                              │
│  │   - Runs on a worker   │                                              │
│  │   - Spawns helpers if  │                                              │
│  │     update pass >10ms  │                                              │
│  └───────────┬────────────┘                                              │
│              │ appends tasks to least-busy worker                        │
│              ▼                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │              WORKER POOL (N = CPU core count)                     │   │
│  │                                                                   │   │
│  │   Worker 0                    Worker 1        ...  Worker N-1     │   │
│  │   ┌─────────────────────────────────────────────────────────┐    │   │
│  │   │ TASK RING BUFFER                                        │    │   │
│  │   │ [task0][task1][task2][sleep][...reserved space...]      │    │   │
│  │   │    ▲                    ▲                               │    │   │
│  │   │    └─ start_ptr         └─ end_ptr                      │    │   │
│  │   │                                                         │    │   │
│  │   │ WorkerTask = {                                          │    │   │
│  │   │   void (*execute)(void* context);  // Function pointer  │    │   │
│  │   │   void (*on_complete)(void* ctx);  // Callback when done│    │   │
│  │   │   void* context;                   // Task data         │    │   │
│  │   │   uint16_t weight;                 // Load balancing    │    │   │
│  │   │   int16_t repeat_count;            // -1=forever, N=N   │    │   │
│  │   │ }                                                       │    │   │
│  │   └─────────────────────────────────────────────────────────┘    │   │
│  │                                                                   │   │
│  │   atomic_uint num_tasks: weighted sum for load balancing          │   │
│  │                                                                   │   │
│  │   Worker loop:                                                    │   │
│  │   1. If buffer empty → usleep(10ms)                               │   │
│  │   2. Execute task[start_ptr]                                      │   │
│  │   3. Decrement repeat_count                                       │   │
│  │   4. If repeat_count == 0: call on_complete, clear slot           │   │
│  │   5. Advance start_ptr                                            │   │
│  │   6. Goto 1                                                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│              │ adds to watch list when ready                             │
│              ▼                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │   SYNC THREAD (parallel watch list)                                 │ │
│  │                                                                     │ │
│  │   WatchEntry = {                                                    │ │
│  │     atomic_bool* ready_flag;   // Worker sets when done             │ │
│  │     void** target_ptr;         // Primary buffer slot to update     │ │
│  │     void* source_ptr;          // New pointer value                 │ │
│  │   }                                                                 │ │
│  │                                                                     │ │
│  │   Continuously scans watch_list[]:                                  │ │
│  │   - If ready_flag true: *target_ptr = source_ptr, remove entry      │ │
│  │   - No waiting for specific workers                                 │ │
│  └───────────────────────────────────────────────────────────────────┘  │
│              │                                                           │
│              ▼                                                           │
│  ┌────────────────┐                                                      │
│  │ PRIMARY BUFFER │ ◄──────── DRAW THREAD reads (main thread)            │
│  │ (pointers)     │           No notification needed                     │
│  └────────────────┘                                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key Characteristics:**
- Workers scale to CPU core count automatically
- Each worker has a ring buffer of function pointers (tasks)
- Tasks are general-purpose (any function, not just render)
- Load balancing via least-busy worker selection
- Updaters are tasks themselves (can spawn helpers)
- Sync uses watch list (parallel, non-blocking)

**Data Flow:**
```
1. Updater task: get_pending_tasks() → array of WorkerTask structs
2. Updater: find_least_busy_worker() → selects target worker
3. Updater: task_append(worker, task) → adds to ring buffer
4. Worker: executes task->execute(task->context)
5. Worker: sync_add_watch(ready_flag, target_ptr, source_ptr)
6. Sync: scans watch list, swaps pointers when ready
7. Draw: reads primary buffer pointers (atomic, no locks)
```

---

## Critical Differences

| Aspect | v1 (Current) | v2 (Target) |
|--------|--------------|-------------|
| **Worker count** | Fixed (MAX_WORKERS=4, typically 2) | Dynamic (sysconf(_SC_NPROCESSORS_ONLN)) |
| **Task model** | Single process_fn for all work | Array of function pointers per worker |
| **Input/Output** | Dedicated buffers per worker | Tasks carry their own context |
| **Slot assignment** | Fixed ranges (slot_start/slot_end) | No fixed assignment, any task on any worker |
| **Load balancing** | None (fixed distribution) | O(N) scan of num_tasks |
| **Updater** | Separate thread | Task running on a worker |
| **Sync behavior** | Poll each worker sequentially | Parallel watch list scan |
| **Extensibility** | Render-specific | General-purpose (physics, AI, etc.) |

---

## Integration Strategy

### Option A: Adapter Pattern (Recommended)

Create a thin adapter that exposes v1 API but uses v2 internals.

**Why this works:**
- main.c continues using familiar API
- v2 infrastructure gets exercised
- Can migrate piece by piece
- Tests for both APIs continue to work

```c
/* {{{ Adapter: v1 API on v2 internals */

/* v2 structures (internal) */
static WorkerPool* g_pool_v2 = NULL;
static SyncContext* g_sync_v2 = NULL;

/* v1-style process function converted to v2 task */
typedef struct render_task_context {
    WorkerContext v1_ctx;       /* For slot_start/slot_end */
    WorkerInput input;
    WorkerOutput output;
    void (*v1_process_fn)(WorkerContext*, void*, void*);
    atomic_bool output_ready;
} RenderTaskContext;

void render_task_execute(void* arg) {
    RenderTaskContext* ctx = (RenderTaskContext*)arg;

    /* Call v1-style process function */
    ctx->v1_process_fn(&ctx->v1_ctx, &ctx->input, &ctx->output);

    /* Add to sync watch list */
    sync_add_watch(g_sync_v2, &ctx->output_ready,
                   /* target_ptr */, ctx->output.slot_data);
    atomic_store(&ctx->output_ready, true);
}

/* v1-compatible pool_create */
WorkerPool* pool_create(int worker_count) {
    g_pool_v2 = pool_create_v2(worker_count);  /* Uses new API */
    g_sync_v2 = sync_create(2048);

    /* Return v1-style wrapper */
    /* ... */
}
/* }}} */
```

### Option B: Full Migration

Rewrite main.c to use v2 API directly.

**Changes required:**
1. Replace `worker_process_fn` with `WorkerTask` instances
2. Replace `custom_updater_loop` with `UpdaterContext`
3. Replace `custom_sync_loop` with `spawn_sync_thread`
4. Replace buffer polling with watch list pattern

```c
/* Before (v1): */
void worker_process_fn(WorkerContext* ctx, void* input_ptr, void* output_ptr) {
    WorkerInput* input = (WorkerInput*)input_ptr;
    WorkerOutput* output = (WorkerOutput*)output_ptr;
    /* ... compute render data ... */
}

/* After (v2): */
void render_slot_task(void* arg) {
    RenderSlotContext* ctx = (RenderSlotContext*)arg;
    /* ... compute render data for this slot ... */

    /* Signal completion via watch list */
    sync_add_watch(g_sync, &ctx->ready, &primary_slot, ctx->computed_data);
    atomic_store(&ctx->ready, true);
}
```

### Option C: Parallel Coexistence

Keep both APIs, use v1 for render demo and v2 for new systems.

**Drawbacks:**
- Code duplication
- Two threading models to maintain
- Confusion about which to use

---

## Implementation Plan (Option A - Adapter)

### Step 1: Create threading_adapter.h

```c
/* Provides v1 API using v2 internals */
#include "threading_v2.h"

/* v1-compatible types (wrappers) */
typedef struct worker_pool_v1 {
    WorkerPool* v2_pool;
    SyncContext* v2_sync;
    void (*process_fn)(WorkerContext*, void*, void*);
    void* primary_buffer;
} WorkerPoolV1;

/* v1-compatible functions */
WorkerPoolV1* pool_create(int count);
void pool_destroy(WorkerPoolV1* pool);
void pool_set_process_fn(WorkerPoolV1* pool, void (*fn)(...));
void pool_set_primary_buffer(WorkerPoolV1* pool, void* buf);
```

### Step 2: Implement Adapter in threading_adapter.c

Convert v1 calls to v2 operations internally.

### Step 3: Update Build

```bash
SOURCES="main.c threading_adapter.c threading_v2.c ..."
```

### Step 4: Test

Verify render demo works exactly as before.

### Step 5: Gradually Migrate

New features use v2 directly. Old code migrated over time.

---

## Acceptance Criteria

- [x] Render demo compiles and runs
- [x] F3 profiler shows per-thread timing
- [x] FPS stable at 60
- [ ] No memory leaks (not tested with valgrind)
- [x] test_threading.c tests still pass (14/14)
- [x] v2 API used directly by main.c (v1 removed entirely)

---

## Files to Create/Modify

**Create:**
- `src/render/threading_v2.h` - New API (renamed from current threading.h after 512)
- `src/render/threading_v2.c` - New implementation
- `src/render/threading_adapter.h` - v1 API wrapper
- `src/render/threading_adapter.c` - Adapter implementation

**Modify:**
- `src/render/threading.h` - Keep as v1 API (or include adapter)
- `src/render/run` - Update SOURCES

---

## Notes

The key insight is that v1 and v2 are **fundamentally different models**:

- **v1**: Workers are "slot processors" - each handles a range of slots
- **v2**: Workers are "task executors" - each runs any function pointer

The adapter bridges this by creating tasks that wrap the v1 process function.

This is a common pattern when evolving threaded architectures - the new model
is more flexible, but existing code expects the old model. An adapter layer
allows incremental migration without breaking working code.

---

## Implementation Notes

### Completed (2026-01-02)

**Decision: Full migration to v2 (Option B)**

Rather than using an adapter layer, we migrated main.c directly to the v2 API.
This was chosen because:
1. v1 adds unnecessary complexity - no reason to maintain two threading models
2. The v2 architecture is the target design for the entire engine
3. The demo is simple enough to migrate cleanly

**Changes made:**

1. **Deleted v1 files:**
   - Removed `threading.h` (v1 buffer-based API)
   - Removed `threading.c` (v1 implementation)

2. **Renamed v2 to primary:**
   - `threading_v2.h` → `threading.h`
   - `threading_v2.c` → `threading.c`
   - `test_threading_v2.c` → `test_threading.c`

3. **New structures in main.c:**
   - `RenderTaskContext` - pre-allocated task context pool (MAX_RENDER_TASKS=64)
   - Global `g_pool`, `g_sync`, `g_updater` for v2 components
   - `g_last_processed_tick` for updater to detect new ticks

4. **Replaced v1 functions:**
   - `worker_process_fn()` → `render_task_execute()` - task function
   - `get_game_input()` → `get_render_tasks()` - updater callback
   - `sync_to_primary()` → removed (watch list handles this)
   - `custom_sync_loop()` → removed (uses `spawn_sync_thread()`)
   - `custom_updater_loop()` → removed (uses `updater_start()`)

5. **Updated main() initialization:**
   - `pool_create()` creates v2 ring buffer pool
   - `sync_create()` creates watch list context
   - `updater_create()` + `updater_start()` runs updater as worker task

6. **Updated shutdown:**
   - Stops sync thread via `atomic_store(&g_sync->running, false)`
   - Destroys components with `updater_destroy()`, `pool_destroy()`, `sync_destroy()`

**Verification:**
- Render demo compiles and runs at stable 60fps
- All 14 threading unit tests pass
- Map loading and terrain rendering work correctly
- Profiler overlay (F3) functions properly

**Key architectural benefit:**
The updater now runs as a worker task (repeat_count=-1), demonstrating the
self-hosted nature of v2. If update passes take >10ms, helper updaters could
be spawned automatically to distribute the load - a capability v1 lacked.
