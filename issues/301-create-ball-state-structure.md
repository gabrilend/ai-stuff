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

- [ ] Pending
