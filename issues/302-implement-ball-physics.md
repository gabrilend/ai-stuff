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

- [ ] Pending
