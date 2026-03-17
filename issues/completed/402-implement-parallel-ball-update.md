# Issue 402: Implement Parallel Ball Update Function

## Current Behavior

ball_manager_update() processes all balls sequentially in a single loop:
```c
for (int i = 0; i < manager->capacity; i++) {
    ball_update_physics(current, next, dt);
    ball_collide_with_pegs(next, world);
    ball_collide_with_walls(next, ...);
    ball_check_bounds(next, ...);
}
```

This is single-threaded and does not utilize the threadpool.

## Intended Behavior

A task function that can be executed by worker threads to update a single
ball. The function reads from BallTaskData and performs:
- Physics integration (gravity, velocity, position)
- Peg collision detection and response
- Wall collision detection and response
- Bounds checking (deactivation)

The function must be thread-safe: only writes to its own ball slot in
the write buffer.

## Suggested Implementation Steps

1. Create ball_update_task() function in src/007-ball.c:
   ```c
   // {{{ ball_update_task
   // Task function for parallel ball update.
   // Receives BallTaskData* as data parameter.
   void ball_update_task(void* data);
   // }}}
   ```

2. Implement ball_update_task():
   - Cast data to BallTaskData*
   - Get ball pointers: read_buffer[ball_index], write_buffer[ball_index]
   - Call ball_update_physics() with dt
   - If active: call collision functions
   - If active: call bounds check

3. Refactor existing static functions for reuse:
   - ball_update_physics() - already takes (current, next, dt)
   - ball_collide_with_pegs() - takes (ball, world)
   - ball_collide_with_walls() - takes (ball, width, height)
   - ball_check_bounds() - takes (ball, height)

4. Ensure thread safety:
   - Read buffer: read-only access
   - Write buffer: each thread writes only to its ball_index
   - World: read-only access (pegs don't move)
   - No shared mutable state

5. Add declaration to src/006-ball.h:
   ```c
   void ball_update_task(void* data);
   ```

6. Update src/006-ball.info.md documentation

7. Test compilation with no warnings

## Design Notes

Single ball per task rationale:
- Maximum parallelism (256 balls = 256 potential parallel tasks)
- Simple thread safety (no need to partition)
- Worker threads naturally load-balance via task queue

Static helper functions:
- ball_update_physics, collision functions already exist
- ball_update_task wraps them with task data unpacking
- Reuse existing, tested physics code

Thread safety analysis:
- read_buffer: immutable during frame (no locks needed)
- write_buffer: disjoint access (each thread owns one index)
- world->pegs: immutable during frame
- world->width/height: immutable values
- No cross-ball dependencies in physics

## Success Criteria

- ball_update_task() function implemented
- Function processes single ball based on BallTaskData
- Physics, collision, bounds checking all working
- Thread-safe (no shared writes)
- Compiles with no warnings
- Can be called directly for testing

## Related Documents

- [002-threadpool-design.md](../docs/002-threadpool-design.md)
- [007-ball.c](../src/007-ball.c)
- [003-threadpool.h](../src/003-threadpool.h)

## Dependencies

- Issue 401 (BallTaskData structure) - Required

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/006-ball.h (added ball_update_task declaration)
- src/007-ball.c (implemented ball_update_task function)
- src/006-ball.info.md (documented ball_update_task with thread safety notes)

**Implementation Steps Completed:**

1. Added ball_update_task() declaration to src/006-ball.h:
   - Documented as thread-safe task function
   - Takes void* data parameter (BallTaskData*)

2. Implemented ball_update_task() in src/007-ball.c:
   - Casts void* data to BallTaskData*
   - Gets current and next ball pointers using task->ball_index
   - Calls ball_update_physics(current, next, task->dt)
   - If ball active: calls collision and bounds checking functions
   - Reuses existing static helper functions (no code duplication)

3. Thread safety verified:
   - Reads from read_buffer (immutable during parallel phase)
   - Writes only to write_buffer[ball_index] (disjoint access)
   - Reads from world (pegs immutable during frame)
   - No shared mutable state between tasks

4. Updated src/006-ball.info.md:
   - Documented ball_update_task() function
   - Added thread safety notes
   - Explained parameter casting and buffer access

5. Compiled successfully with no new warnings

**Current Behavior:**
- ball_update_task() ready to be submitted to threadpool
- Function processes single ball with full physics and collisions
- Thread-safe design confirmed: each task owns one write buffer index
- Reuses existing, tested physics code from Phase 3
- Foundation ready for Issue 403 (synchronization barriers)

**Design Decisions:**
- Single ball per task for maximum parallelism
- Wrapped existing static functions (no refactoring needed)
- Disjoint buffer access pattern avoids locks
- Task data provides all needed context (no global state)

**Phase 4 Progress:**
Issue 402 complete. Ready for Issue 403 (synchronization barriers).
