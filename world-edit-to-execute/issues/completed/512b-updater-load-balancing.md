# Issue 512b: Updater Load Balancing

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 512a (worker ring buffer)
**Parent:** 512-threading-architecture-rewrite.md

---

## Current Behavior

Workers are assigned fixed slot ranges at pool creation time:
- `slot_start` and `slot_end` fields in WorkerContext
- Updater distributes identical input to all workers
- No awareness of actual worker load

```c
// Current: Fixed slot assignment
typedef struct worker_context {
    int slot_start;
    int slot_end;
    // ...
} WorkerContext;
```

---

## Intended Behavior

Updater assigns tasks to the least-busy worker:
- Each worker has an atomic `num_tasks` counter (weighted sum)
- Updater scans workers, finds one with lowest load
- Tasks assigned to that worker's ring buffer
- Load counter updated atomically on add/complete

```c
// Target: Dynamic load balancing
Worker* find_least_busy_worker(WorkerPool* pool) {
    Worker* best = &pool->workers[0];
    unsigned int best_load = atomic_load(&best->num_tasks);

    for (int i = 1; i < pool->count; i++) {
        unsigned int load = atomic_load(&pool->workers[i].num_tasks);
        if (load < best_load) {
            best = &pool->workers[i];
            best_load = load;
        }
    }
    return best;
}
```

---

## Suggested Implementation Steps

1. **Ensure num_tasks is in Worker struct (from 512a)**
   ```c
   typedef struct worker {
       // ...
       atomic_uint num_tasks;  // Weighted task count
       // ...
   } Worker;
   ```

2. **Implement find_least_busy_worker**
   - O(N) scan of all workers
   - Return pointer to worker with lowest num_tasks
   - Handle tie-breaking (first match is fine)

3. **Update task_append to increment num_tasks**
   ```c
   bool task_append(Worker* w, WorkerTask* task) {
       // ... append logic ...
       atomic_fetch_add(&w->num_tasks, task->weight);
       return true;
   }
   ```

4. **Update worker_loop to decrement on completion**
   ```c
   // In worker_loop, when repeat_count reaches 0:
   if (task->repeat_count == 0) {
       task->execute = sleep_task;
       atomic_fetch_sub(&w->num_tasks, task->weight);
   }
   ```

5. **Rewrite distribute_input_to_workers**
   ```c
   void distribute_tasks(WorkerPool* pool, WorkerTask* tasks, int count) {
       for (int i = 0; i < count; i++) {
           Worker* target = find_least_busy_worker(pool);
           task_append(target, &tasks[i]);
       }
   }
   ```

6. **Add default task weights**
   ```c
   #define WEIGHT_LIGHT   1    // Simple operations
   #define WEIGHT_MEDIUM  5    // Standard render slot
   #define WEIGHT_HEAVY   20   // Complex physics/AI
   ```

7. **Add load query function**
   ```c
   unsigned int pool_get_total_load(WorkerPool* pool) {
       unsigned int total = 0;
       for (int i = 0; i < pool->count; i++) {
           total += atomic_load(&pool->workers[i].num_tasks);
       }
       return total;
   }
   ```

8. **Unit test for load balancing**
   - Submit tasks with varying weights
   - Verify distribution across workers
   - Check num_tasks updates correctly

---

## Acceptance Criteria

- [x] find_least_busy_worker implemented and tested
- [x] num_tasks incremented on task_append
- [x] num_tasks decremented on task completion
- [x] distribute_tasks uses least-busy selection (test_distribute_to_least_busy)
- [x] Task weight constants defined (WEIGHT_SLEEP, LIGHT, MEDIUM, HEAVY, UPDATER)
- [x] pool_get_total_load returns aggregate load
- [x] Unit test verifies balanced distribution

---

## Files to Modify

```
src/render/
├── threading.h    (add weight constants, function declarations)
├── threading.c    (implement load balancing)
└── test_threading.c    (add load balancing tests)
```

---

## Notes

Task weights are initially developer-estimated. Issue 511 (render profiler) will
eventually measure actual execution times to tune weights automatically.

The O(N) scan for least-busy worker is acceptable because N = CPU core count
(typically 4-16). For larger worker pools, a min-heap could be considered,
but YAGNI applies here.

This load balancing enables 512c (self-evaluating updaters) to spawn helpers
that naturally distribute across workers.

---

## Implementation Notes

**Completed:** 2026-01-01

Implemented as part of 512a. All load balancing infrastructure is in place:

| Function | Location | Description |
|----------|----------|-------------|
| find_least_busy_worker | threading.c:147 | O(N) scan of worker loads |
| task_append | threading.c:101 | Increments num_tasks on append |
| worker_loop | threading.c:215 | Decrements num_tasks on completion |
| pool_get_total_load | threading.c:324 | Aggregate load query |

Weight constants defined in threading.h:
- WEIGHT_SLEEP = 0
- WEIGHT_LIGHT = 1
- WEIGHT_MEDIUM = 5
- WEIGHT_HEAVY = 20
- WEIGHT_UPDATER = 10

Test `test_distribute_to_least_busy` verifies 100 tasks are distributed evenly across 4 workers.
