# Issue 401: Create Ball Task Data Structure

## Current Behavior

Ball physics updates happen sequentially in ball_manager_update(). Each
ball is processed one at a time on the main thread. The threadpool exists
but is not connected to the ball physics system.

## Intended Behavior

A BallTaskData structure that encapsulates all information needed for a
worker thread to process a single ball:
- Ball index for accessing the correct buffer slots
- Pointers to read and write buffers
- World reference for collision detection
- Delta time for physics integration

Pre-allocated array of BallTaskData to avoid malloc during gameplay.

## Suggested Implementation Steps

1. Define BallTaskData structure in src/006-ball.h:
   ```c
   typedef struct BallTaskData {
       int ball_index;        // Index into ball arrays
       Ball* read_buffer;     // Current state (read-only)
       Ball* write_buffer;    // Next state (write target)
       World* world;          // World for collision detection
       float dt;              // Delta time in seconds
   } BallTaskData;
   ```

2. Add task data array to BallManager struct:
   ```c
   typedef struct BallManager {
       // ... existing fields ...
       BallTaskData* task_data;  // Pre-allocated task data array
   } BallManager;
   ```

3. Update ball_manager_create():
   - Allocate task_data array with size = capacity
   - Initialize each task_data entry with ball_index

4. Update ball_manager_destroy():
   - Free task_data array

5. Create ball_manager_prepare_tasks() function:
   ```c
   void ball_manager_prepare_tasks(BallManager* manager, World* world, float dt);
   ```
   - Sets read_buffer, write_buffer, world, dt for all task data entries
   - Called once per frame before submitting tasks

6. Update src/006-ball.info.md with new structures and functions

7. Test compilation with no warnings

## Design Notes

Pre-allocation rationale:
- Task data is allocated once at startup
- ball_index is immutable (set once at creation)
- Other fields updated each frame via prepare_tasks()
- Avoids per-frame memory allocation overhead

Thread safety considerations:
- Each task data entry is independent
- Multiple threads can read task_data array concurrently
- Each thread writes only to its assigned ball in write_buffer
- Read buffer is truly read-only during parallel phase

## Success Criteria

- BallTaskData struct defined with all required fields
- Task data array allocated in ball_manager_create()
- Task data array freed in ball_manager_destroy()
- ball_manager_prepare_tasks() sets up all task data
- No memory leaks detected
- Compiles with no warnings

## Related Documents

- [002-threadpool-design.md](../docs/002-threadpool-design.md)
- [006-ball.h](../src/006-ball.h)
- [003-threadpool.h](../src/003-threadpool.h)

## Dependencies

- Issue 301-305 (Phase 3 ball physics) - Completed

## Status

- [ ] Pending
