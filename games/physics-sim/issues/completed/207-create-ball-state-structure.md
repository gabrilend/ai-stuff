# Issue 301: Create Ball State Structure

## Current Behavior

No ball representation exists. Only static pegs and score zones are
defined in the world state.

## Intended Behavior

Ball data structure with double-buffering support:
- Position (x, y) in pixels
- Velocity (vx, vy) in pixels per second
- Radius for rendering and collision
- Active flag for lifecycle management
- Double-buffering: read from current state, write to next state

Ball manager to hold array of balls with capacity management.

## Suggested Implementation Steps

1. Create src/006-ball.h with Ball struct:
   ```c
   typedef struct Ball {
       float x, y;        // Position
       float vx, vy;      // Velocity
       float radius;      // Collision/render radius
       int active;        // 1 if in play, 0 if inactive
   } Ball;
   ```

2. Create BallManager struct for managing ball collection:
   ```c
   typedef struct BallManager {
       Ball* balls_current;  // Current frame state (read)
       Ball* balls_next;     // Next frame state (write)
       int capacity;         // Maximum ball count
       int active_count;     // Number of active balls
   } BallManager;
   ```

3. Implement ball manager functions:
   - ball_manager_create(int capacity): Allocate manager and arrays
   - ball_manager_destroy(): Free all resources
   - ball_manager_spawn(manager, x, y): Create new ball at position
   - ball_manager_swap_buffers(): Swap current/next pointers
   - ball_manager_deactivate(manager, index): Mark ball as inactive

4. Add physics constants:
   ```c
   #define BALL_RADIUS 8.0f
   #define MAX_BALLS 256
   ```

5. Create src/007-ball.c with implementations

6. Create src/006-ball.info.md documentation

7. Update Makefile if needed (should auto-detect .c files)

8. Test compilation with no warnings

## Design Notes

Double-buffering rationale:
- Current buffer is read-only during physics update
- Next buffer receives all writes
- Swap at end of frame
- Enables future parallel processing (Phase 4)

Ball lifecycle:
- Spawned as active with initial position/velocity
- Deactivated when scoring or leaving bounds
- Inactive balls can be reused for new spawns

## Success Criteria

- Ball and BallManager structs defined
- Create/destroy functions work without leaks
- Spawn function adds balls to manager
- Buffer swap function exchanges pointers
- Compiles with no warnings

## Related Documents

- [003-physics-system.md](../docs/003-physics-system.md)
- [004-world.h](../src/004-world.h)

## Dependencies

- Issue 201 (World state structure) - Completed

## Status

- [x] Completed

## Implementation Notes

**Files Created:**
- src/006-ball.h (ball state structures and API)
- src/007-ball.c (ball manager implementation)
- src/006-ball.info.md (API documentation)

**Implementation Steps Completed:**

1. Created Ball struct with position, velocity, radius, and active flag
2. Created BallManager struct with double-buffering:
   - balls_current: Read-only during physics update
   - balls_next: Write target during physics update
   - capacity: Maximum ball count (256)
   - active_count: Tracks number of active balls
3. Implemented ball_manager_create():
   - Allocates manager struct
   - Allocates both current and next ball buffers
   - Initializes all balls as inactive with BALL_RADIUS
   - Returns NULL on allocation failure with error messages
4. Implemented ball_manager_destroy():
   - Frees both ball buffers
   - Frees manager struct
   - Null-safe (checks before freeing)
5. Implemented ball_manager_spawn():
   - Finds first inactive slot in current buffer
   - Sets position (x, y)
   - Initializes velocity to zero
   - Marks ball as active
   - Increments active_count
   - Returns 1 on success, 0 if no slots available
6. Implemented ball_manager_swap_buffers():
   - Swaps current and next buffer pointers
   - Single pointer exchange operation
   - Enables double-buffered updates
7. Implemented ball_manager_deactivate():
   - Marks ball at index as inactive
   - Decrements active_count
   - Bounds checking on index
8. Created comprehensive API documentation in .info.md file
9. Compiled successfully with no warnings

**Current Behavior:**
- Ball state structures ready for physics integration
- Double-buffering infrastructure in place
- Memory management working (create/destroy/spawn)
- Foundation ready for Issue 302 (physics implementation)

**Design Decisions:**
- Used calloc() for zero-initialization of ball buffers
- Active flag allows slot reuse without reallocation
- spawn() initializes velocity to zero (will be set by caller)
- Buffer swap is simple pointer exchange (fast, cache-friendly)

**Phase 3 Progress:**
Issue 301 complete. Ready for Issue 302 (ball physics).
