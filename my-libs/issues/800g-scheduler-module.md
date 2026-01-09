# Issue 800g: Scheduler Module

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 800a (Core threadpool module)

---

## Current Behavior

The updater uses a callback-based system to get tasks:
```c
bool (*get_pending_tasks)(UpdaterContext* ctx, TpTask** out, size_t* count);
```

This requires the user to implement "what tasks are ready RIGHT NOW?" logic. There's no built-in mechanism for:
- Scheduling tasks to be assigned at future times
- Preventing updater from spinning when no work is ready
- Waking updater when new tasks arrive

## Intended Behavior

A scheduler module that manages tasks with deferred assignment times:

```c
// User submits tasks with "assign in N ticks"
scheduler_add(sched, task, 0);      // Assign ASAP (next tick)
scheduler_add(sched, task, 100);    // Assign in 100 ticks
scheduler_add(sched, task, 5000);   // Assign in 5000 ticks

// Updater integrates with scheduler:
UpdaterContext* updater = updater_create(pool, scheduler_get_ready, sched);
updater_start(updater);
```

### Key Features

1. **Flat array storage** - Updater scans all scheduled tasks each tick
2. **Absolute time-based readiness** - Tasks store `ready_at_tick` (absolute tick number), compared against global tick counter
3. **Sleep optimization** - If no tasks ready, sleep until earliest task
4. **Wake on new task** - Adding task wakes sleeping updater
5. **assigned_any flag** - Tracks whether any work was done this iteration
6. **Independent tick counter** - Global `g_current_tick` increments via game loop or timer thread, decoupled from updater

### Updater Loop Behavior

```c
// Updater pseudocode:
while (running) {
    uint32_t assigned_any = 0;
    uint64_t current_tick = atomic_load(&g_current_tick);

    // Scan all scheduled tasks
    for (each task in scheduler) {
        if (current_tick >= task.ready_at_tick) {
            assign_to_worker(task);
            assigned_any = 1;
            remove_from_scheduler(task);
        }
    }

    // If nothing was ready, sleep until earliest task
    if (assigned_any == 0) {
        uint64_t earliest_tick = find_earliest_ready_tick(sched);
        uint64_t ticks_to_sleep = earliest_tick - current_tick;
        sleep_interruptible(ticks_to_sleep);  // Wake if new task added
    }
    // Otherwise, loop immediately to check for more work
}
```

**Note:** Global tick counter `g_current_tick` is incremented by the game loop or a dedicated timer thread, independent of the updater. This prevents deadlock when the updater sleeps - time continues advancing without the updater needing to call `scheduler_tick()`.

### API Design

```c
/* {{{ Global tick counter
 * Incremented by game loop or timer thread (independent of scheduler/updater).
 * Scheduler compares task ready times against this value. */
extern atomic_uint64_t g_current_tick;
/* }}} */

/* {{{ Scheduler types */
typedef struct scheduled_task {
    TpTask task;                   // The task to execute
    uint64_t ready_at_tick;        // Absolute tick number when task becomes ready
} ScheduledTask;

typedef struct scheduler {
    ScheduledTask* tasks;          // Flat array of scheduled tasks
    size_t capacity;               // Max tasks
    size_t count;                  // Current task count

    pthread_mutex_t lock;          // Protects task array
    pthread_cond_t wake_signal;    // Signal for new task arrivals

    atomic_bool running;           // Shutdown flag
} Scheduler;
/* }}} */

/* {{{ Scheduler lifecycle */
// Create scheduler with specified capacity
Scheduler* scheduler_create(size_t capacity);

// Destroy scheduler (does not cancel pending tasks)
void scheduler_destroy(Scheduler* sched);
/* }}} */

/* {{{ Task management */
// Add task to scheduler
// ticks_delay: 0 = ASAP (ready at g_current_tick), N = ready in N ticks from now
// Internally: ready_at_tick = g_current_tick + ticks_delay
// Returns false if scheduler is full
bool scheduler_add(Scheduler* sched, TpTask* task, uint32_t ticks_delay);

// Remove all tasks matching predicate (for cancellation)
// predicate returns true to remove, false to keep
void scheduler_remove_if(Scheduler* sched,
                         bool (*predicate)(TpTask* task, void* user_data),
                         void* user_data);

// Get count of scheduled tasks
size_t scheduler_count(Scheduler* sched);
/* }}} */

/* {{{ Updater integration */
// Callback for updater's get_pending_tasks
// Returns tasks where g_current_tick >= ready_at_tick
bool scheduler_get_ready(void* context, TpTask** out, size_t* count);

// Find earliest ready tick (for sleep optimization)
// Returns UINT64_MAX if no tasks scheduled
uint64_t scheduler_earliest_ready_tick(Scheduler* sched);

// Sleep until earliest task or new task arrival (interruptible)
// Takes number of ticks to sleep (calculated externally: earliest_tick - g_current_tick)
void scheduler_sleep_ticks(Scheduler* sched, uint64_t ticks_to_sleep);
/* }}} */
```

## Suggested Implementation Steps

1. Create `src/scheduler.h` with type definitions
2. Declare `extern atomic_uint64_t g_current_tick` (defined by game loop/timer)
3. Implement `scheduler_create()` and `scheduler_destroy()`
4. Implement `scheduler_add()`:
   - Calculate `ready_at_tick = atomic_load(&g_current_tick) + ticks_delay`
   - Add task to array
   - Signal wake condition
5. Implement `scheduler_get_ready()`:
   - Load current tick: `current = atomic_load(&g_current_tick)`
   - Scan for tasks where `current >= ready_at_tick`
6. Implement `scheduler_earliest_ready_tick()` (find min ready_at_tick)
7. Implement `scheduler_sleep_ticks()` with pthread_cond_timedwait
8. Implement `scheduler_remove_if()` for task cancellation
9. Add example usage to test suite (800d)
10. Document tick counter integration requirements

## Acceptance Criteria

- [ ] Scheduler stores tasks with absolute ready times (`ready_at_tick`)
- [ ] `scheduler_add(sched, task, 0)` sets `ready_at_tick = g_current_tick` (ready immediately)
- [ ] `scheduler_add(sched, task, N)` sets `ready_at_tick = g_current_tick + N`
- [ ] `scheduler_get_ready()` returns only tasks where `g_current_tick >= ready_at_tick`
- [ ] Updater can sleep while `g_current_tick` continues advancing (no deadlock)
- [ ] Adding task wakes sleeping updater via `pthread_cond_signal`
- [ ] assigned_any flag works (keeps looping if work was done)
- [ ] Thread-safe: concurrent add/get_ready operations
- [ ] Removal works (by predicate function)
- [ ] No dependency on updater for time advancement (decoupled from scheduler)

## Related Documents

- `800a-core-threadpool-module.md` - Worker pool this integrates with
- `800c-updater-module.md` - Self-evaluating updaters (scheduler consumer)
- `docs/render-threading-v2.md` - Architecture context

## Notes

### Future Optimization: Branchless Readiness Check

Currently uses: `if (current_tick >= ready_at_tick)` to check readiness.

**Future consideration:** Branchless comparison using arithmetic:
```c
uint64_t current = g_current_tick;
uint64_t ready = task.ready_at_tick;
// Check if current >= ready without branching
uint64_t is_ready = 1 - ((ready - current - 1) >> 63);
// Returns 1 if current >= ready, else 0 (unsigned underflow sets high bit)
```

This could enable:
- Vectorized scanning of task array (SIMD parallel comparisons)
- Better CPU pipeline utilization
- Cache-friendly sequential access

**Trade-off:** Bit manipulation may be less readable and harder to verify.
Defer this optimization until profiling shows the branch as a bottleneck.

### Multiplication-Based Time Gates

The `ticks_until_ready` design ensures that 0 is special (ready now) without
needing separate flags. Multiplication by 0 naturally zeros out weights:

```c
// If ticks > 0: effective_weight = 0 (not ready, don't count load)
// If ticks = 0: effective_weight = task.weight (ready, full weight)
uint32_t effective_weight = task.weight * (ticks_until_ready == 0);
```

This pattern may be useful for load estimation in the future.

### Alternative Storage: Priority Queue

Current design uses flat array (O(N) scan per tick).

If task count grows large (>1000s), consider:
- Min-heap sorted by ready time (O(log N) insert, O(1) peek earliest)
- Trade-off: More complex code, allocation overhead

Flat array is simpler and sufficient for typical game loop task counts (<100).

### Integration with Game Systems

Example: WC3 periodic effects (DoTs, HoTs, auras)
```c
// Apply damage-over-time every 16ms (1 tick)
scheduler_add(sched, dot_task, 1);  // Re-add after execution

// Refresh unit vision every 500ms (~31 ticks)
scheduler_add(sched, vision_task, 31);

// Spawn creeps every 30 seconds (~1875 ticks at 62.5Hz)
scheduler_add(sched, spawn_task, 1875);
```

The scheduler provides frame-accurate timing without manual tick counting in
game logic.
