# Render Threading Model v2 (Target Architecture)

This document describes the target threading architecture for the render system.
It supersedes the prototype model in render-architecture.md and will be merged
once implementation begins.

---

## Reference Tick Rates

| System | Tick Rate | Interval | Notes |
|--------|-----------|----------|-------|
| WC3 main game | 62.5 Hz | 16ms | Core simulation rate |
| WC3 unit facing | ~33.33 Hz | 30ms | Rotation updates |
| AzerothCore MapUpdate | 100 Hz | 10ms | Archived - WoW mode not in MVP |

**Target:** 62.5 Hz (16ms) - WC3's core simulation rate. All timing thresholds
derive from this base rate.

---

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            THREAD POOL ARCHITECTURE                              │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────┐                      ┌────────────────────────────┐  │
│  │   UPDATER POOL         │                      │   SYNC THREAD              │  │
│  │   (adaptive spawn)     │                      │   (parallel watch list)    │  │
│  │                        │                      │                            │  │
│  │  Primary updater:      │                      │  Continuously iterates     │  │
│  │  - Distributes tasks   │                      │  memory watch list.        │  │
│  │  - Monitors time       │                      │  On "ready" flag → swap    │  │
│  │                        │                      │  pointer, remove from list │  │
│  │  If update pass > 16ms │                      │                            │  │
│  │  → Spawn helper        │                      │  No waiting for workers.   │  │
│  │  → Split remaining     │                      │  Runs in parallel always.  │  │
│  └───────────┬────────────┘                      └─────────────┬──────────────┘  │
│              │ assigns tasks to least-busy worker              │ swaps ready     │
│              ▼                                                 │ outputs         │
│  ┌───────────────────────────────────────────────────────────┐ │                 │
│  │              PERSISTENT WORKER POOL                       │ │                 │
│  │              (N = system thread count)                    │ ▼                 │
│  │                                                           │  ┌────────────────┐│
│  │  Each worker has:                                         │  │ PRIMARY BUFFER ││
│  │  ┌─────────────────────────────────────────────────────┐  │  │ (render-visible││
│  │  │ TASK LIST (ring buffer)                             │  │  │  pointers)     │┤
│  │  │ [fn0][fn1][fn2][sleep][...reserved...]              │  │  │                ││
│  │  │   ▲                                                 │  │  └────────────────┘│
│  │  │   └── start_ptr (current execution position)        │  │           │       │
│  │  │                                                     │  │           │       │
│  │  │ Worker loop (no conditionals):                      │  │           ▼       │
│  │  │   1. Execute task[start_ptr]                        │  │  ┌────────────────┐│
│  │  │   2. On complete: decrement num_tasks               │  │  │  DRAW THREAD   ││
│  │  │   3. Write sleep to completed slot                  │  │  │  (main thread) ││
│  │  │   4. Increment start_ptr                            │  │  │                ││
│  │  │   5. Goto 1                                         │  │  │  Vsync-paced.  ││
│  │  │                                                     │  │  │  Reads primary ││
│  │  │ When approaching last n% of allocated memory:       │  │  │  buffer only.  ││
│  │  │   → Append "relocate" task to move back to          │  │  │  Never notified││
│  │  │     beginning of ring buffer                        │  │  │  of changes.   ││
│  │  │   (n% = system thread count for safety margin)      │  │  │                ││
│  │  └─────────────────────────────────────────────────────┘  │  └────────────────┘│
│  │                                                           │                   │
│  │  num_tasks: weighted task count for load balancing        │                   │
│  │  Task weights: profiler-determined, developer-cached      │                   │
│  │                                                           │                   │
│  └───────────────────────────────────────────────────────────┘                   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Thread Responsibilities

| Thread | Work | Behavior |
|--------|------|----------|
| **Updaters** | Assign tasks to worker task-lists | Adaptive spawning: if pass > 16ms, spawn helpers and split work |
| **Workers** | Execute function pointers from task-list | Persistent, N = CPU cores. No conditionals - just execute next in list |
| **Sync** | Watch memory locations for ready flags | Parallel, continuous. On ready → swap pointer, remove from watch list |
| **Draw** | Iterate primary buffer, issue GPU commands | Vsync-paced. Unaware of data changes. Just renders what pointers point at |

---

## Worker Task-List Architecture

Workers do **not** have fixed entity slots. They are general-purpose task executors
that run function pointers. A "task" can be:
- Render slot computation
- Physics update
- Animation tick
- Any game system work

```c
/* {{{ WorkerTask - function pointer with execution metadata */
typedef struct worker_task {
    void (*execute)(void* context);   // Function to run
    void* context;                    // Task-specific data
    uint16_t weight;                  // Profiler-determined cost (for load balancing)
    int16_t repeat_count;             // Run N times, then remove. -1 = infinite
} WorkerTask;
/* }}} */
```

### Task Lifecycle

1. Updater writes task to end of worker's task-list
2. Worker executes tasks sequentially (no if-checks, just call and advance)
3. On completion:
   - Decrement `repeat_count` (if > 0)
   - If `repeat_count <= 0`: write `sleep_task` to slot, task is done
   - Decrement worker's `num_tasks` by task weight
   - Increment `start_ptr` to next slot
4. `sleep_task` is the default endcap - worker sleeps for one tick interval then checks again

### Ring Buffer Management

- Task-list is a pre-allocated ring buffer
- `start_ptr` advances as tasks complete
- New tasks written to `end_ptr` (which becomes new end after write)
- When `end_ptr` enters last N% of buffer (N = thread count):
  - Append "relocate" task that copies remaining tasks to buffer start
  - Guarantees space for burst of concurrent writes from multiple updaters

```c
/* {{{ Worker - persistent worker with task ring buffer */
typedef struct worker {
    pthread_t thread;

    // Task ring buffer
    WorkerTask* task_list;           // Pre-allocated array
    size_t task_list_size;           // Total allocated slots
    size_t start_ptr;                // Current execution position
    size_t end_ptr;                  // Next write position

    // Load balancing
    atomic_uint num_tasks;           // Weighted task count (for updater to check)

    // Control
    atomic_bool running;
} Worker;
/* }}} */

/* {{{ worker_loop - execute tasks without conditionals */
void* worker_loop(void* arg) {
    Worker* w = (Worker*)arg;

    while (atomic_load(&w->running)) {
        // Execute current task (always - even if it's sleep)
        WorkerTask* task = &w->task_list[w->start_ptr];
        task->execute(task->context);

        // Handle repeat_count
        if (task->repeat_count > 0) {
            task->repeat_count--;
        }

        // If task is done (not repeating), replace with sleep
        if (task->repeat_count == 0) {
            task->execute = sleep_task;
            task->context = w;  // Sleep needs worker for timing
            atomic_fetch_sub(&w->num_tasks, task->weight);
        }

        // Advance (wrapping handled by ring buffer bounds check elsewhere)
        w->start_ptr++;
        if (w->start_ptr >= w->task_list_size) {
            w->start_ptr = 0;  // Wrap after relocate task ran
        }
    }
    return NULL;
}
/* }}} */

/* {{{ sleep_task - default endcap, yields for one tick */
void sleep_task(void* context) {
    // Sleep for ~16ms (one tick at 62.5Hz)
    // This is the "nothing to do" state
    usleep(16000);
}
/* }}} */
```

---

## Updater as Worker Task (Self-Evaluating)

**Key insight:** Helper updaters are not separate threads - they are worker tasks.
When a helper updater's `repeat_count` reaches 0, it self-evaluates whether to
continue existing based on the previous tick's timing.

### Continuation Threshold

- **Target tick time:** 16ms (62.5Hz)
- **Continuation threshold:** 50% of target = **8ms**
- If previous tick took > 8ms → recreate updater task (might land on different worker)
- If previous tick took ≤ 8ms → don't recreate (helper removes itself)

This creates natural scaling: helpers spawn when needed and disappear when load decreases.

```c
/* {{{ UpdaterContext - context for updater tasks */
typedef struct updater_context {
    Worker* workers;                 // Reference to worker pool
    int worker_count;

    // Task queue partition this updater handles
    WorkerTask* pending_queue;
    size_t partition_start;
    size_t partition_end;

    // Timing measurement
    uint64_t last_tick_duration_us;

    // Constants
    uint64_t target_tick_us;         // 16000 (16ms)
    uint64_t continuation_threshold; // 8000 (50% of target)
} UpdaterContext;
/* }}} */

/* {{{ updater_task_execute - main updater work function */
void updater_task_execute(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;
    uint64_t start = get_timestamp_us();

    // Distribute our partition of tasks to workers
    for (size_t i = ctx->partition_start; i < ctx->partition_end; i++) {
        Worker* target = find_least_busy_worker(ctx);
        append_task(target, &ctx->pending_queue[i]);
        atomic_fetch_add(&target->num_tasks, ctx->pending_queue[i].weight);
    }

    // Record timing for self-evaluation
    ctx->last_tick_duration_us = get_timestamp_us() - start;
}
/* }}} */

/* {{{ updater_task_on_complete - called when repeat_count reaches 0 */
void updater_task_on_complete(UpdaterContext* ctx, Worker* current_worker) {
    // Self-evaluate: should this updater continue to exist?
    if (ctx->last_tick_duration_us > ctx->continuation_threshold) {
        // Previous tick took > 50% of target time
        // Recreate this updater as a new task (may land on different worker)
        Worker* target = find_least_busy_worker_pool(ctx);

        WorkerTask new_updater = {
            .execute = updater_task_execute,
            .context = ctx,
            .weight = UPDATER_TASK_WEIGHT,
            .repeat_count = 1  // Run once, then evaluate again
        };

        append_task(target, &new_updater);
        atomic_fetch_add(&target->num_tasks, new_updater.weight);
    } else {
        // Previous tick took ≤ 50% of target time
        // Load has decreased - this helper is no longer needed
        // Don't recreate - just let it disappear
        free(ctx);  // Clean up context
    }
}
/* }}} */
```

### Task Lifecycle for Updaters

1. Primary updater runs as persistent task (`repeat_count = -1`)
2. When primary detects overload (> 16ms), it creates helper updater task:
   - Helper assigned to least-busy worker
   - `repeat_count = 1` (evaluate after each run)
   - Gets a partition of the pending task queue
3. Helper executes, records timing
4. When `repeat_count` hits 0, helper calls `on_complete`:
   - Checks `last_tick_duration_us`
   - If > 8ms: recreate as new task (possibly different worker)
   - If ≤ 8ms: don't recreate (helper exits)
5. Helpers naturally disappear when load decreases

### Load Balancing

```c
/* {{{ find_least_busy_worker - O(N) scan of worker loads */
Worker* find_least_busy_worker(UpdaterContext* ctx) {
    Worker* best = &ctx->workers[0];
    unsigned int best_load = atomic_load(&best->num_tasks);

    for (int i = 1; i < ctx->worker_count; i++) {
        unsigned int load = atomic_load(&ctx->workers[i].num_tasks);
        if (load < best_load) {
            best = &ctx->workers[i];
            best_load = load;
        }
    }
    return best;
}
/* }}} */
```

### Why This Design

1. **No special thread type:** Updaters are just tasks - same machinery as everything else
2. **Self-regulating:** Helpers appear/disappear based on measured load
3. **Distributed:** Recreated helpers may land on different workers (implicit load balancing)
4. **50% threshold:** Conservative - helpers stick around until load clearly subsides
5. **Memory cleanup:** Context freed when helper exits, no leaks

---

## Sync Thread Parallel Operation

The sync thread does **not** wait for all workers to complete a frame.
It continuously monitors a watch list of memory locations:

```c
/* {{{ WatchEntry - memory location to monitor */
typedef struct watch_entry {
    atomic_bool* ready_flag;         // Worker sets this when output is ready
    void** target_ptr;               // Where to swap the new pointer
    void* source_ptr;                // The new pointer value
} WatchEntry;
/* }}} */

/* {{{ SyncContext - sync thread state */
typedef struct sync_context {
    WatchEntry* watch_list;
    size_t watch_capacity;
    size_t watch_count;

    atomic_bool running;

    // Stats
    uint64_t swaps_performed;
} SyncContext;
/* }}} */

/* {{{ sync_loop - parallel watch and swap */
void* sync_loop(void* arg) {
    SyncContext* ctx = (SyncContext*)arg;

    while (atomic_load(&ctx->running)) {
        // Iterate watch list (no waiting)
        for (size_t i = 0; i < ctx->watch_count; /* manual increment */) {
            WatchEntry* entry = &ctx->watch_list[i];

            if (atomic_load(entry->ready_flag)) {
                // Swap the pointer atomically
                *entry->target_ptr = entry->source_ptr;

                // Clear ready flag
                atomic_store(entry->ready_flag, false);

                // Remove from watch list (swap with last, decrement count)
                ctx->watch_list[i] = ctx->watch_list[--ctx->watch_count];
                ctx->swaps_performed++;

                // Don't increment i - we need to check the swapped-in entry
            } else {
                i++;
            }
        }

        // Brief yield if no work (not a full sleep)
        if (ctx->watch_count == 0) {
            usleep(100);  // 0.1ms
        }
    }
    return NULL;
}
/* }}} */

/* {{{ sync_add_watch - worker calls this when output is ready */
void sync_add_watch(SyncContext* ctx, atomic_bool* ready, void** target, void* source) {
    // Atomically add to watch list
    // (In practice, this needs a lock or lock-free queue)
    size_t idx = ctx->watch_count++;
    ctx->watch_list[idx].ready_flag = ready;
    ctx->watch_list[idx].target_ptr = target;
    ctx->watch_list[idx].source_ptr = source;
}
/* }}} */
```

The watch list is populated by workers when they complete tasks that produce
render-visible output. The sync thread picks them up as they become ready,
independent of frame boundaries.

---

## Draw Thread Independence

The draw thread (main thread) is completely decoupled from the update pipeline:

```c
/* {{{ draw_frame - render whatever pointers point at */
void draw_frame(PrimaryBuffer* buffer) {
    // No synchronization needed - just read current pointer values
    // If sync thread updates a pointer mid-frame, we get the new data
    // This is fine - we're not reading partial data, just different frames

    for (int i = 0; i < buffer->slot_count; i++) {
        RenderSlot* slot = buffer->slots[i];
        if (slot && slot->visible) {
            draw_slot(slot);
        }
    }
}
/* }}} */
```

**Key insight:** The draw thread does not need notification of changes.
It runs at vsync, rendering whatever the pointers currently point to.
Pointer swaps by the sync thread are atomic and invisible to draw.

---

## Comparison: Prototype vs Target

| Aspect | Prototype (Current) | Target (This Document) |
|--------|---------------------|------------------------|
| Worker count | Fixed (2-4) | Dynamic (N = CPU cores) |
| Worker assignment | Fixed slot ranges | Least-busy load balancing |
| Task model | Input/output buffers | Ring buffer of function pointers |
| Sync behavior | Wait for all workers | Parallel continuous scan |
| Draw notification | Receives signals | Never notified |
| Updater spawning | Single thread | Adaptive (spawn helpers if > 16ms) |
| Sleep behavior | Fixed times | Tick-aligned (16ms target) |
| Task types | Render-specific | General-purpose (any game system) |

---

## Implementation Notes

### Phase 1: Worker Ring Buffer
- Replace fixed input/output buffers with task ring buffer
- Implement no-conditional worker loop
- Test with sleep_task as only task

### Phase 2: Updater Load Balancing
- Add `num_tasks` atomic counter to workers
- Implement `find_least_busy_worker()`
- Test task distribution under load

### Phase 3: Adaptive Updater Spawning
- Add timing to updater pass
- Implement helper spawning when > 16ms
- Test with artificially heavy workloads

### Phase 4: Sync Parallel Scan
- Replace blocking sync with watch list
- Implement `sync_add_watch()` for workers
- Test pointer swap correctness

### Phase 5: Integration
- Wire render tasks to worker pool
- Wire physics/AI tasks to same pool
- Verify 62.5Hz target under realistic load

---

## Related Documents

- `docs/render-architecture.md` - Contains prototype model being replaced
- `issues/511-render-profiler.md` - Profiler for task weight determination
- `issues/508-vertical-slice-testing-room.md` - Integration target

---

## Changelog

| Date | Change |
|------|--------|
| 2025-12-31 | Initial creation from user architectural requirements |
