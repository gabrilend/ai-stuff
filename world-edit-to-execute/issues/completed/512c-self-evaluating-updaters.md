# Issue 512c: Self-Evaluating Updaters

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 512a (ring buffer), 512b (load balancing)
**Parent:** 512-threading-architecture-rewrite.md

---

## Current Behavior

Updater is a separate thread with fixed behavior:
- Runs in infinite loop calling `get_input` callback
- Distributes identical input to all workers
- Fixed 5ms sleep when idle
- No awareness of update duration or overload

```c
// Current: Fixed updater thread
void* updater_loop(void* arg) {
    while (running) {
        if (get_input(&new_input)) {
            distribute_input_to_workers(pool, &new_input);
        } else {
            usleep(5000);  // Fixed 5ms sleep
        }
    }
}
```

---

## Intended Behavior

Updaters are worker tasks, not separate threads:
- Primary updater runs with `repeat_count = -1` (infinite)
- Measures its execution time
- If pass > 10ms, spawns helper updater with `repeat_count = 1`
- Helpers self-evaluate on completion:
  - If last tick > 5ms (50% threshold): recreate task
  - If last tick <= 5ms: exit (load has decreased)

```
┌─────────────────────────────────────────────────────────────────┐
│ Primary Updater (repeat_count = -1, runs forever)               │
│   Detects overload (pass > 10ms) → Spawns helper                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Helper Updater Task (repeat_count = 1)                          │
│   1. Execute: distribute partition of tasks, record timing      │
│   2. repeat_count decrements to 0                               │
│   3. Self-evaluate:                                             │
│      ├── If last_tick > 5ms: recreate task (may move workers)   │
│      └── If last_tick ≤ 5ms: don't recreate (exit)              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

1. **Define UpdaterContext for task-based updater**
   ```c
   typedef struct updater_context {
       WorkerPool* pool;

       // Task queue partition
       WorkerTask* pending_queue;
       size_t pending_count;
       size_t partition_start;
       size_t partition_end;

       // Timing
       uint64_t last_tick_duration_us;
       uint64_t target_tick_us;          // 10000 (10ms)
       uint64_t continuation_threshold;  // 5000 (50%)

       // Callback to get pending tasks
       bool (*get_pending_tasks)(WorkerTask** out, size_t* count);
   } UpdaterContext;
   ```

2. **Implement timestamp utility**
   ```c
   uint64_t get_timestamp_us(void) {
       struct timespec ts;
       clock_gettime(CLOCK_MONOTONIC, &ts);
       return ts.tv_sec * 1000000ULL + ts.tv_nsec / 1000ULL;
   }
   ```

3. **Implement updater_task_execute**
   ```c
   void updater_task_execute(void* arg) {
       UpdaterContext* ctx = (UpdaterContext*)arg;
       uint64_t start = get_timestamp_us();

       // Distribute our partition to workers
       for (size_t i = ctx->partition_start; i < ctx->partition_end; i++) {
           Worker* target = find_least_busy_worker(ctx->pool);
           task_append(target, &ctx->pending_queue[i]);
       }

       ctx->last_tick_duration_us = get_timestamp_us() - start;
   }
   ```

4. **Implement helper self-evaluation**
   ```c
   // Called from worker_loop when repeat_count reaches 0
   void updater_on_complete(void* arg) {
       UpdaterContext* ctx = (UpdaterContext*)arg;

       if (ctx->last_tick_duration_us > ctx->continuation_threshold) {
           // Still under load - recreate on least-busy worker
           Worker* target = find_least_busy_worker(ctx->pool);
           WorkerTask new_task = {
               .execute = updater_task_execute,
               .context = ctx,
               .weight = UPDATER_TASK_WEIGHT,
               .repeat_count = 1
           };
           task_append(target, &new_task);
       } else {
           // Load decreased - exit
           free(ctx);
       }
   }
   ```

5. **Modify worker_loop for on_complete callback**
   ```c
   // In WorkerTask struct, add optional completion callback
   typedef struct worker_task {
       void (*execute)(void* context);
       void (*on_complete)(void* context);  // NULL if not needed
       void* context;
       uint16_t weight;
       int16_t repeat_count;
   } WorkerTask;

   // In worker_loop:
   if (task->repeat_count == 0) {
       if (task->on_complete) {
           task->on_complete(task->context);
       }
       task->execute = sleep_task;
       atomic_fetch_sub(&w->num_tasks, task->weight);
   }
   ```

6. **Implement primary updater overload detection**
   ```c
   void primary_updater_execute(void* arg) {
       UpdaterContext* ctx = (UpdaterContext*)arg;
       uint64_t start = get_timestamp_us();

       // Get pending tasks
       WorkerTask* pending;
       size_t count;
       if (!ctx->get_pending_tasks(&pending, &count)) return;

       // Distribute tasks
       for (size_t i = 0; i < count; i++) {
           Worker* target = find_least_busy_worker(ctx->pool);
           task_append(target, &pending[i]);
       }

       uint64_t elapsed = get_timestamp_us() - start;

       // Check for overload
       if (elapsed > ctx->target_tick_us) {
           // Spawn helper for next tick
           spawn_helper_updater(ctx);
       }
   }
   ```

7. **Implement spawn_helper_updater**
   ```c
   void spawn_helper_updater(UpdaterContext* primary) {
       UpdaterContext* helper = malloc(sizeof(UpdaterContext));
       *helper = *primary;  // Copy settings

       // Helper gets half the partition
       size_t mid = (primary->partition_start + primary->partition_end) / 2;
       helper->partition_start = mid;
       helper->partition_end = primary->partition_end;
       primary->partition_end = mid;

       Worker* target = find_least_busy_worker(primary->pool);
       WorkerTask task = {
           .execute = updater_task_execute,
           .on_complete = updater_on_complete,
           .context = helper,
           .weight = UPDATER_TASK_WEIGHT,
           .repeat_count = 1
       };
       task_append(target, &task);
   }
   ```

8. **Add updater weight constant**
   ```c
   #define UPDATER_TASK_WEIGHT 10  // Medium priority
   ```

9. **Unit test for adaptive spawning**
   - Submit artificial load exceeding 10ms
   - Verify helper spawned
   - Reduce load, verify helper exits

---

## Acceptance Criteria

- [x] UpdaterContext has timing fields
- [x] get_timestamp_us implemented
- [x] Primary updater detects overload (> 10ms)
- [x] Helper updaters spawned on overload
- [x] Helpers self-evaluate at 50% threshold (5ms)
- [x] Helpers recreate on least-busy worker when still loaded
- [x] Helpers exit cleanly when load decreases
- [x] on_complete callback in WorkerTask
- [x] Unit test verifies adaptive behavior

---

## Files to Modify

```
src/render/
├── threading.h    (UpdaterContext, on_complete field)
├── threading.c    (updater task functions)
└── test_threading.c    (adaptive spawning tests)
```

---

## Notes

The 50% threshold (5ms of 10ms target) is deliberately conservative. This prevents
oscillation where helpers repeatedly spawn and exit. Helpers stick around until
load clearly subsides.

This design eliminates the updater as a special thread type. Updaters are just
tasks that happen to submit other tasks. The system is now more uniform.

Helper updaters may land on different workers than where they were created.
This provides implicit load balancing as helpers migrate toward less-busy workers.

---

## Implementation Notes

**Completed:** 2026-01-01

### Key Implementation Details

| Function | Location | Description |
|----------|----------|-------------|
| updater_create | threading.c:478 | Creates primary UpdaterContext |
| updater_destroy | threading.c:502 | Frees allocated context |
| updater_start | threading.c:511 | Adds primary as worker task (repeat_count=-1) |
| primary_updater_execute | threading.c:533 | Distributes tasks, detects overload |
| helper_updater_execute | threading.c:574 | Processes partition of tasks |
| helper_updater_on_complete | threading.c:612 | Self-evaluation: continue or exit |
| spawn_helper_updater | threading.c:645 | Spawns helper with partition |

### UpdaterContext Structure

```c
typedef struct updater_context {
    WorkerPool* pool;
    bool (*get_pending_tasks)(UpdaterContext*, WorkerTask**, size_t*);
    void* user_data;
    size_t partition_start, partition_end;
    uint64_t last_tick_duration_us;
    bool is_primary;
    bool is_allocated;
} UpdaterContext;
```

### Tests Added

- test_updater_create_start: Basic creation and startup
- test_helper_spawn_complete: Helper spawns and processes 5 tasks
- test_helper_self_evaluate: Helper exits below 5ms threshold
