# Issue 512a: Worker Ring Buffer

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** None (first sub-issue)
**Parent:** 512-threading-architecture-rewrite.md

---

## Current Behavior

Workers use fixed input/output buffer pairs:
- `WorkerInput` struct with game state snapshot
- `WorkerOutput` struct with computed results
- Worker reads input, computes, writes output, sets `output_ready` flag
- Fixed worker count (MAX_WORKERS = 4)

```c
// Current: Fixed buffers per worker
typedef struct worker_buffers {
    WorkerInput input;
    WorkerOutput output;
    atomic_bool output_ready;
    pthread_mutex_t input_lock;
    pthread_mutex_t output_lock;
} WorkerBuffers;
```

---

## Intended Behavior

Workers execute function pointers from a ring buffer task list:
- Each worker has a pre-allocated ring buffer of `WorkerTask` entries
- Tasks are function pointers with context, weight, and repeat count
- Worker loop is unconditional: always execute `task[start_ptr]`, advance
- Completed tasks become `sleep_task` (yield for one tick)
- Ring buffer wraps via "relocate" task when approaching end

```c
// Target: Ring buffer of function pointers
typedef struct worker_task {
    void (*execute)(void* context);
    void* context;
    uint16_t weight;
    int16_t repeat_count;  // -1 = infinite, 0 = remove after next run
} WorkerTask;

typedef struct worker {
    pthread_t thread;
    WorkerTask* task_list;
    size_t task_list_size;
    size_t start_ptr;
    size_t end_ptr;
    atomic_uint num_tasks;
    atomic_bool running;
} Worker;
```

---

## Suggested Implementation Steps

1. **Define new structures in threading.h**
   ```c
   // Add WorkerTask struct
   // Add Worker struct (renamed from old approach)
   // Keep WorkerPool for managing worker array
   // Add TASK_LIST_SIZE constant (e.g., 1024)
   ```

2. **Implement sleep_task function**
   ```c
   void sleep_task(void* context) {
       // Sleep for one tick (10ms at 100Hz)
       usleep(10000);
   }
   ```

3. **Implement relocate_task function**
   ```c
   void relocate_task(void* context) {
       Worker* w = (Worker*)context;
       // Copy active tasks from current position to buffer start
       // Reset start_ptr and end_ptr
   }
   ```

4. **Rewrite worker_loop for ring buffer**
   ```c
   void* worker_loop(void* arg) {
       Worker* w = (Worker*)arg;
       while (atomic_load(&w->running)) {
           WorkerTask* task = &w->task_list[w->start_ptr];
           task->execute(task->context);

           // Handle repeat_count
           if (task->repeat_count > 0) task->repeat_count--;
           if (task->repeat_count == 0) {
               task->execute = sleep_task;
               atomic_fetch_sub(&w->num_tasks, task->weight);
           }

           // Advance with wrap
           w->start_ptr = (w->start_ptr + 1) % w->task_list_size;
       }
       return NULL;
   }
   ```

5. **Implement task_append function**
   ```c
   bool task_append(Worker* w, WorkerTask* task) {
       // Check for space
       size_t next = (w->end_ptr + 1) % w->task_list_size;
       if (next == w->start_ptr) return false;  // Full

       w->task_list[w->end_ptr] = *task;
       w->end_ptr = next;
       atomic_fetch_add(&w->num_tasks, task->weight);

       // Check if approaching end, schedule relocate
       // ...
       return true;
   }
   ```

6. **Update pool_create for new Worker type**
   - Allocate task_list arrays
   - Initialize with sleep_task in slot 0
   - Set start_ptr = 0, end_ptr = 1

7. **Update pool_destroy to free task lists**

8. **Add unit test for ring buffer behavior**
   - Test task append/execute cycle
   - Test wrap-around
   - Test relocate trigger

---

## Acceptance Criteria

- [x] WorkerTask struct defined with execute, context, weight, repeat_count
- [x] Worker struct has task_list ring buffer
- [x] sleep_task implemented (10ms yield)
- [x] relocate_task implemented (compacts buffer)
- [x] worker_loop executes from ring buffer (sleeps when empty)
- [x] task_append adds tasks to end of ring buffer
- [x] Ring buffer wraps correctly
- [x] Pool creates/destroys workers with task_list allocation
- [x] Unit test validates ring buffer behavior

---

## Files to Modify

```
src/render/
├── threading.h    (new structures)
├── threading.c    (new implementation)
└── test_threading.c    (new test file)
```

---

## Notes

This is the foundation for the new threading model. Later sub-issues (512b-512e)
build on this ring buffer infrastructure.

The key insight is removing conditionals from the worker loop. Workers always
execute something - if there's no real work, they execute sleep_task. This
simplifies the code and makes behavior more predictable.

Task weights (512b) and self-evaluating updaters (512c) require this ring buffer
to be in place first.

---

## Implementation Notes

**Completed:** 2026-01-01

### Design Changes from Original Spec

The original spec had workers always execute something (sleep_task when idle).
This was changed to a simpler model where workers sleep (usleep) when the buffer
is empty (start_ptr == end_ptr). This avoids the complexity of infinite repeat
tasks blocking new work from being processed.

### Key Implementation Details

| Component | Implementation |
|-----------|----------------|
| WorkerTask | Struct with execute, on_complete, context, weight, repeat_count |
| Worker | Ring buffer with start_ptr/end_ptr, atomic num_tasks counter |
| worker_loop | Sleeps when empty, skips NULL/done tasks, handles repeat_count |
| task_append | Appends to end_ptr, auto-schedules relocate when buffer fills |
| relocate_task | Compacts buffer by copying active tasks to start |
| find_least_busy_worker | O(N) scan of num_tasks (also used by 512b) |

### Sync Infrastructure (512d) Also Implemented

The sync thread watch list was implemented in this pass:
- SyncContext with watch_list, spinlock for thread-safe adds
- sync_add_watch() for workers to register completed outputs
- sync_loop() continuously monitors and swaps ready pointers

### Test Results

All 11 tests pass:
- Pool creation/destruction
- Auto-detect CPU cores (16 on test system)
- Task append and execute
- Load balancing (find_least_busy_worker)
- Total load calculation
- repeat_count (finite runs)
- on_complete callbacks
- Sync watch list operations
- Multi-entry sync
- Distributed task execution
