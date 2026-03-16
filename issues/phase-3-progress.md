# Phase 3 Progress

## Phase Goal

Implement ball spawning, movement, and collision detection. This phase
brings the pachinko machine to life with physics simulation.

## Issues

| ID  | Description                        | Status      |
|-----|------------------------------------|-------------|
| 301 | Create ball state structure        | ✓ Completed |
| 302 | Implement ball physics             | ✓ Completed |
| 303 | Implement peg collision            | ✓ Completed |
| 304 | Implement boundary collision       | ✓ Completed |
| 305 | Implement ball spawning with input | Pending     |

## Progress Summary

**Completed:** 4/5 issues (80%)
**Phase 3:** In Progress

## Notes

Phase 3 focuses on single-threaded physics. Parallel processing with
the threadpool will be added in Phase 4. Success is measured by:
- Balls fall under gravity
- Balls bounce off pegs realistically
- Balls bounce off walls
- Space key launches new balls

## Dependencies

Phase 2 must be complete (world state, pegs, score zones).

## Implementation Log

### Issue 301 - Create Ball State Structure (Completed)
Created ball state structures with double-buffering:
- Ball struct (position, velocity, radius, active flag)
- BallManager struct (current/next buffers, capacity, active_count)
- ball_manager_create() allocates manager and both buffers
- ball_manager_destroy() frees all resources
- ball_manager_spawn() creates new ball in inactive slot
- ball_manager_swap_buffers() exchanges buffer pointers
- ball_manager_deactivate() marks ball as inactive
- Compiled successfully with no warnings
- Double-buffering ready for parallel processing in Phase 4

### Issue 302 - Implement Ball Physics (Completed)
Implemented gravity-based physics simulation:
- Added physics constants (GRAVITY, DAMPING, MIN_VELOCITY)
- Implemented ball_update_physics() with semi-implicit Euler integration
- Implemented ball_manager_update() for all-ball physics updates
- Implemented ball_manager_render() with orange circle rendering
- Integrated into main loop with delta time from GetFrameTime()
- Test ball spawns at top center and falls with gravity
- Ball accelerates realistically, motion smooth at 60fps
- Framerate-independent physics using delta time
- Ball currently falls through pegs/walls (collisions next)

### Issue 303 - Implement Peg Collision (Completed)
Implemented circle-circle collision detection and response:
- Added collision constants (RESTITUTION, COLLISION_BIAS)
- Implemented ball_check_peg_collision() with distance-squared optimization
- Implemented ball_resolve_peg_collision() with penetration resolution
- Implemented ball_collide_with_pegs() to check all pegs
- Updated ball_manager_update() to take World* parameter
- Collision response uses velocity reflection formula: v' = v - (1+e)(v·n)n
- Balls bounce off pegs with 70% energy retention
- Multiple collisions per frame handled correctly
- No balls pass through pegs, no sticking issues
- Ball creates zigzag paths through peg grid

### Issue 304 - Implement Boundary Collision (Completed)
Implemented wall collision and bounds checking:
- Added boundary constants (WALL_RESTITUTION, ZONE_TOP_Y)
- Implemented ball_collide_with_walls() for left/right/top walls
- Implemented ball_check_bounds() to deactivate off-screen balls
- Wall collisions use 60% energy retention (less bouncy than pegs)
- Balls bounce off left/right/top walls, no bottom wall
- Balls deactivate when falling below screen
- Updated active_count tracking in ball_manager_update()
- Collision order: physics → pegs → walls → bounds
- No balls escape through walls or corners
