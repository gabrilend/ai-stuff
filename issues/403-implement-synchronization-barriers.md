# Issue 403: Implement Synchronization Barriers

## Current Behavior

Ball physics updates and buffer swaps happen sequentially:
```c
ball_manager_update(ball_manager, world, dt);  // All balls updated
ball_manager_swap_buffers(ball_manager);        // Swap immediately after
```

No synchronization needed because everything is single-threaded.

## Intended Behavior

Proper synchronization between parallel ball updates and buffer swap:
1. Main thread submits all ball tasks to threadpool
2. Main thread waits for all tasks to complete
3. Main thread swaps buffers (safe because no tasks running)
4. Main thread renders from current buffer

The active_count must be recalculated after all parallel tasks complete,
requiring a reduction operation or post-processing step.

## Suggested Implementation Steps

1. Create ball_manager_submit_tasks() function:
   ```c
   // {{{ ball_manager_submit_tasks
   // Submits all active ball updates to threadpool.
   // Call prepare_tasks() first to set up task data.
   void ball_manager_submit_tasks(BallManager* manager, ThreadPool* pool);
   // }}}
   ```

2. Implement ball_manager_submit_tasks():
   - Loop through all balls (0 to capacity)
   - If balls_current[i].active, submit ball_update_task with &task_data[i]
   - Use threadpool_submit() for each active ball

3. Create ball_manager_finalize_update() function:
   ```c
   // {{{ ball_manager_finalize_update
   // Called after threadpool_wait_all() to finalize ball states.
   // Counts active balls in write buffer and updates active_count.
   void ball_manager_finalize_update(BallManager* manager);
   // }}}
   ```

4. Implement ball_manager_finalize_update():
   - Reset active_count to 0
   - Loop through balls_next buffer
   - Count balls where active == 1
   - Set manager->active_count to final count

5. Document synchronization pattern in code:
   ```c
   // Frame update sequence:
   // 1. ball_manager_prepare_tasks()  - Set up task data
   // 2. ball_manager_submit_tasks()   - Submit to threadpool
   // 3. threadpool_wait_all()         - Wait for completion
   // 4. ball_manager_finalize_update() - Count active balls
   // 5. ball_manager_swap_buffers()   - Swap for rendering
   ```

6. Add declarations to src/006-ball.h

7. Update src/006-ball.info.md documentation

8. Test compilation with no warnings

## Design Notes

Why separate finalize step:
- active_count reduction requires reading all balls
- Cannot atomically update from multiple threads
- Single-threaded post-process is clean and simple
- Runs after wait_all, so all writes are visible

Synchronization guarantees:
- threadpool_wait_all() ensures all tasks complete
- Memory barrier implied by mutex unlock in worker threads
- Safe to read balls_next after wait returns

Alternative considered:
- Atomic increment for active_count in each task
- Rejected: adds contention, complicates ball deactivation logic
- Sequential count after parallel phase is simpler

## Success Criteria

- ball_manager_submit_tasks() submits all active balls
- ball_manager_finalize_update() correctly counts active balls
- No tasks running when buffer swap occurs
- active_count accurate after parallel update
- Compiles with no warnings

## Related Documents

- [002-threadpool-design.md](../docs/002-threadpool-design.md)
- [003-threadpool.h](../src/003-threadpool.h)

## Dependencies

- Issue 401 (BallTaskData structure) - Required
- Issue 402 (ball_update_task function) - Required

## Status

- [ ] Pending
