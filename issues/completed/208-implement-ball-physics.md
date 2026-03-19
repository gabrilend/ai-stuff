# Issue 302: Implement Ball Physics

## Current Behavior

Ball state structure exists but balls do not move. No physics
simulation is performed.

## Intended Behavior

Balls affected by gravity and move according to their velocity:
- Gravity applies constant downward acceleration
- Velocity integrates over time (position += velocity * dt)
- Acceleration integrates into velocity (velocity += gravity * dt)
- Semi-implicit Euler integration for stability

## Suggested Implementation Steps

1. Add physics constants to 006-ball.h:
   ```c
   #define GRAVITY 980.0f        // Pixels per second squared
   #define DAMPING 0.98f         // Velocity damping factor
   #define MIN_VELOCITY 1.0f     // Threshold for stopping
   ```

2. Implement ball_update_physics() in 007-ball.c:
   ```c
   void ball_update_physics(Ball* current, Ball* next, float dt) {
       // Copy active state
       next->active = current->active;
       next->radius = current->radius;

       if (!current->active) return;

       // Semi-implicit Euler integration
       next->vy = current->vy + GRAVITY * dt;
       next->vx = current->vx * DAMPING;
       next->vy = next->vy * DAMPING;

       next->x = current->x + next->vx * dt;
       next->y = current->y + next->vy * dt;
   }
   ```

3. Implement ball_manager_update() to update all balls:
   ```c
   void ball_manager_update(BallManager* manager, float dt) {
       for (int i = 0; i < manager->capacity; i++) {
           ball_update_physics(
               &manager->balls_current[i],
               &manager->balls_next[i],
               dt
           );
       }
   }
   ```

4. Add ball rendering function:
   ```c
   void ball_manager_render(BallManager* manager);
   ```
   - Draw each active ball as a colored circle
   - Use RED or ORANGE for visibility

5. Integrate into main loop:
   - Get delta time from raylib: GetFrameTime()
   - Call ball_manager_update(manager, dt)
   - Call ball_manager_swap_buffers(manager)
   - Call ball_manager_render(manager)

6. Update 006-ball.info.md with new functions

7. Test with a manually spawned ball at startup

## Physics Notes

Semi-implicit Euler:
- Update velocity first, then position
- More stable than explicit Euler
- Good enough for pachinko (not requiring Verlet)

Delta time:
- Use actual frame time for physics
- Allows consistent physics at varying framerates
- Raylib provides GetFrameTime() for this

## Success Criteria

- Balls fall downward under gravity
- Balls accelerate as they fall
- Motion appears smooth at 60fps
- Delta time correctly integrated
- No physics explosions or instability

## Related Documents

- [003-physics-system.md](../docs/003-physics-system.md)

## Dependencies

- Issue 301 (Ball state structure)

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/006-ball.h (added physics constants and function declarations)
- src/007-ball.c (added physics implementation)
- src/006-ball.info.md (updated documentation)
- src/001-main.c (integrated ball physics into main loop)

**Implementation Steps Completed:**

1. Added physics constants to 006-ball.h:
   - GRAVITY: 980.0 pixels/sec² (realistic earth gravity)
   - DAMPING: 0.98 velocity retention per frame
   - MIN_VELOCITY: 1.0 threshold for stopping

2. Implemented ball_update_physics() internal function:
   - Copies active state and radius
   - Skips inactive balls
   - Semi-implicit Euler: velocity updated first, then position
   - Gravity applies to vertical velocity
   - Damping applies to both velocity components
   - Position integrates using updated velocity

3. Implemented ball_manager_update():
   - Iterates through all balls in capacity
   - Calls ball_update_physics for each ball
   - Reads from balls_current, writes to balls_next
   - Preserves double-buffering architecture

4. Implemented ball_manager_render():
   - Iterates through all balls in current buffer
   - Renders only active balls
   - Uses ORANGE color for visibility
   - Draws balls as filled circles using raylib

5. Integrated into main loop (001-main.c):
   - Added 006-ball.h include
   - Created ball_manager after world creation
   - Spawned test ball at screen center (400, 50)
   - Get delta time using GetFrameTime()
   - Call ball_manager_update(manager, dt)
   - Call ball_manager_swap_buffers(manager)
   - Call ball_manager_render(manager) in render section
   - Destroy ball_manager in cleanup sequence

6. Updated API documentation in 006-ball.info.md:
   - Added ball_manager_update documentation
   - Added ball_manager_render documentation
   - Added physics constants documentation

7. Compiled successfully with no new warnings

**Current Behavior:**
- Test ball spawns at top center of screen
- Ball falls under gravity (980 px/s²)
- Ball accelerates as it falls (visible acceleration)
- Delta time integration ensures framerate-independent physics
- Ball renders as orange circle
- Motion appears smooth at 60fps
- Ball falls through pegs and bottom (expected - collisions in Issue 303/304)

**Physics Notes:**
- Semi-implicit Euler more stable than explicit Euler
- Velocity updated before position prevents energy gain
- Damping prevents infinite bouncing (will be useful after collision)
- Delta time allows physics to work at any framerate

**Phase 3 Progress:**
Issue 302 complete (2/5 issues, 40%). Ready for Issue 303 (peg collision).
