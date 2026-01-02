# Issue 512: Threading Architecture Rewrite

**Phase:** 5 - Rendering
**Type:** Architecture / Refactor
**Priority:** Critical
**Dependencies:** 508a (current threading prototype)

---

## Current Behavior

The current threading implementation (`src/render/threading.c`) has several
architectural problems identified during review:

1. **Fixed worker count (2-4)** - Wastes CPU on many-core systems
2. **Workers tied to slot ranges** - Poor load distribution
3. **Sync thread blocks** - Waits for all workers before swapping
4. **Draw thread notified** - Unnecessary coupling
5. **Fixed sleep times** - Not adaptive to workload
6. **Render-specific workers** - Can't reuse for physics/AI

See `docs/render-threading-v2.md` for the target architecture specification.

---

## Intended Behavior

A general-purpose thread pool that:

1. Scales workers to available CPU cores
2. Uses ring buffers of function pointers instead of fixed slots
3. Load-balances tasks to least-busy workers
4. Spawns helper updaters when falling behind 100Hz target
5. Runs sync thread in parallel (no blocking)
6. Leaves draw thread completely independent

### Target Tick Rate

| System | Rate | Interval |
|--------|------|----------|
| WC3 | 50 Hz | 20ms |
| AzerothCore | 100 Hz | 10ms |
| **Target** | **100 Hz** | **10ms** |

---

## Sub-Issues

| ID | Name | Description |
|----|------|-------------|
| 512a | Worker Ring Buffer | Replace input/output buffers with task ring buffer |
| 512b | Updater Load Balancing | Add num_tasks counter, least-busy distribution |
| 512c | Self-Evaluating Updaters | Updaters as worker tasks with 50% threshold continuation |
| 512d | Sync Parallel Scan | Replace blocking sync with continuous watch list |
| 512e | Integration Testing | Wire render/physics/AI to unified pool |

---

## Key Data Structures

### WorkerTask

```c
typedef struct worker_task {
    void (*execute)(void* context);   // Function to run
    void* context;                    // Task-specific data
    uint16_t weight;                  // Profiler-determined cost
    int16_t repeat_count;             // N times then remove, -1 = infinite
} WorkerTask;
```

### Worker

```c
typedef struct worker {
    pthread_t thread;

    // Task ring buffer
    WorkerTask* task_list;
    size_t task_list_size;
    size_t start_ptr;
    size_t end_ptr;

    // Load balancing
    atomic_uint num_tasks;  // Weighted count

    atomic_bool running;
} Worker;
```

### UpdaterContext (for self-evaluating updaters)

```c
typedef struct updater_context {
    Worker* workers;
    int worker_count;

    // Task queue partition
    WorkerTask* pending_queue;
    size_t partition_start;
    size_t partition_end;

    // Timing for self-evaluation
    uint64_t last_tick_duration_us;
    uint64_t continuation_threshold;  // 5000us (50% of 10ms)
} UpdaterContext;
```

### WatchEntry (for sync)

```c
typedef struct watch_entry {
    atomic_bool* ready_flag;
    void** target_ptr;
    void* source_ptr;
} WatchEntry;
```

---

## Worker Loop (No Conditionals)

The worker loop executes tasks without if-checks:

```c
void* worker_loop(void* arg) {
    Worker* w = (Worker*)arg;

    while (atomic_load(&w->running)) {
        // Always execute (even if it's sleep)
        WorkerTask* task = &w->task_list[w->start_ptr];
        task->execute(task->context);

        // Handle repeat
        if (task->repeat_count > 0) task->repeat_count--;
        if (task->repeat_count == 0) {
            task->execute = sleep_task;
            atomic_fetch_sub(&w->num_tasks, task->weight);
        }

        // Advance
        w->start_ptr = (w->start_ptr + 1) % w->task_list_size;
    }
    return NULL;
}
```

The `sleep_task` function is the default endcap that yields for one tick.

---

## Ring Buffer Wraparound

When `end_ptr` enters the last N% of the buffer (N = thread count):
- Append a "relocate" task
- This task copies remaining active tasks to buffer start
- Guarantees space for burst writes from multiple updaters

---

## Updater Self-Evaluation

Helper updaters are worker tasks, not separate threads. When their `repeat_count`
reaches 0, they evaluate whether to continue existing:

```
┌─────────────────────────────────────────────────────────────────┐
│ Primary Updater (repeat_count = -1, runs forever)               │
│                                                                 │
│   Detects overload (pass > 10ms)                                │
│   ↓                                                             │
│   Creates helper updater task with repeat_count = 1             │
│   Assigns to least-busy worker                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Helper Updater Task (repeat_count = 1)                          │
│                                                                 │
│   1. Execute: distribute partition of tasks, record timing      │
│   2. repeat_count decrements to 0                               │
│   3. Self-evaluate:                                             │
│      ├── If last_tick > 5ms (50%): recreate task                │
│      │   (may land on different worker - load balancing)        │
│      └── If last_tick ≤ 5ms: don't recreate (exit)              │
└─────────────────────────────────────────────────────────────────┘
```

**50% threshold (5ms):** Conservative - helpers persist until load clearly subsides.
This prevents oscillation where helpers repeatedly spawn and exit.

---

## Acceptance Criteria

- [x] Worker count = sysconf(_SC_NPROCESSORS_ONLN)
- [x] Workers use ring buffer task lists
- [x] Updater distributes to least-busy worker
- [x] Helper updaters are worker tasks (not threads)
- [x] Helpers self-evaluate at 50% threshold (5ms)
- [x] Helpers recreate on different workers (implicit load balance)
- [x] Sync thread runs in parallel, never blocks
- [x] Draw thread receives no notifications
- [x] Same pool handles render + physics + AI tasks
- [ ] 100Hz update rate maintained under load (requires game system integration)
- [x] Task weights are developer-configurable

---

## Files to Modify

```
src/render/
├── threading.h    (new structures)
├── threading.c    (new implementation)
├── main.c         (integration)

docs/
├── render-architecture.md    (update to reference v2)
├── render-threading-v2.md    (target specification)
```

---

## Notes

This is a significant rewrite of the threading model. The prototype in 508a
was useful for validating the basic approach but doesn't scale or adapt.

Key insight: Workers are not "render workers" - they are general-purpose
task executors. Any game system (physics, AI, animation, rendering) can
submit tasks to the same pool.

Task weights are crucial for load balancing. Initially these will be
developer-estimated; later, issue 511 (render profiler) will measure
actual execution times to tune weights automatically.

---

## Related Documents

- `docs/render-architecture.md` - Original architecture (prototype)
- `docs/render-threading-v2.md` - Target architecture specification
- `issues/508a-threading-infrastructure.md` - Current prototype
- `issues/511-render-profiler.md` - Task weight profiling

---

## Generated Sub-Issues

| File | Status |
|------|--------|
| `issues/completed/512a-worker-ring-buffer.md` | Completed |
| `issues/completed/512b-updater-load-balancing.md` | Completed |
| `issues/completed/512c-self-evaluating-updaters.md` | Completed |
| `issues/completed/512d-sync-parallel-scan.md` | Completed |
| `issues/completed/512e-integration-testing.md` | Completed |

---

## Implementation Notes

**Completed:** 2026-01-01

### Architecture Summary

The threading infrastructure has been completely rewritten from fixed slot-based
workers to a general-purpose task pool:

| Component | Implementation |
|-----------|----------------|
| WorkerPool | Dynamic worker count (CPU cores), manages all workers |
| Worker | Ring buffer task list, atomic load counter |
| WorkerTask | Function pointer + context + weight + repeat_count |
| SyncContext | Watch list for parallel pointer swaps |
| UpdaterContext | Self-evaluating task-based updater |

### Key Files

| File | Purpose |
|------|---------|
| src/render/threading.h | All structure definitions and API |
| src/render/threading.c | Complete implementation (~700 lines) |
| src/render/test_threading.c | 14 tests covering all functionality |

### Test Results

All 14 tests pass on 16-core system:
- Pool lifecycle and auto-detection
- Task execution and repeat counts
- Load balancing and distribution
- Sync watch list operations
- Updater creation and helper spawning

### Remaining Work

The 100Hz target validation requires integration with actual game systems
(render, physics, AI). This will be tested as part of Issue 508 (Vertical Slice).
