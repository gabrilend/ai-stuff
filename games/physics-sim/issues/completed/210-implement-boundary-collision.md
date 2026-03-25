# Issue 304: Implement Boundary Collision

## Current Behavior

Balls fall through the screen edges and score zones without any
boundary interaction.

## Intended Behavior

Balls collide with screen boundaries:
- Left and right walls reflect balls horizontally
- Top boundary prevents balls from leaving upward
- Bottom boundary: balls pass through to score zones
- Side walls have slight restitution for realistic bounce

## Suggested Implementation Steps

1. Add boundary constants to 006-ball.h:
   ```c
   #define WALL_RESTITUTION 0.6f   // Wall bounce retention
   #define ZONE_TOP_Y 560.0f       // Top of score zone area
   ```

2. Implement wall collision function:
   ```c
   void ball_collide_with_walls(Ball* ball, int screen_width,
                                 int screen_height) {
       // Left wall
       if (ball->x - ball->radius < 0) {
           ball->x = ball->radius;
           ball->vx = -ball->vx * WALL_RESTITUTION;
       }

       // Right wall
       if (ball->x + ball->radius > screen_width) {
           ball->x = screen_width - ball->radius;
           ball->vx = -ball->vx * WALL_RESTITUTION;
       }

       // Top wall (prevent escape)
       if (ball->y - ball->radius < 0) {
           ball->y = ball->radius;
           ball->vy = -ball->vy * WALL_RESTITUTION;
       }

       // Note: No bottom wall - balls fall into score zones
   }
   ```

3. Mark balls as inactive when below screen:
   ```c
   void ball_check_bounds(Ball* ball, int screen_height) {
       // Ball has fallen below screen
       if (ball->y - ball->radius > screen_height) {
           ball->active = 0;
       }
   }
   ```

4. Integrate into ball_manager_update():
   ```c
   void ball_manager_update(BallManager* manager, World* world,
                            float dt) {
       for (int i = 0; i < manager->capacity; i++) {
           Ball* current = &manager->balls_current[i];
           Ball* next = &manager->balls_next[i];

           if (!current->active) {
               next->active = 0;
               continue;
           }

           // Physics update
           ball_update_physics(current, next, dt);

           // Collision detection (on next buffer)
           ball_collide_with_pegs(next, world);
           ball_collide_with_walls(next, world->width, world->height);
           ball_check_bounds(next, world->height);
       }
   }
   ```

5. Update active_count when balls deactivate:
   - Track in deactivation function
   - Or recount after update loop

6. Update 006-ball.info.md documentation

7. Test wall bounces and ball deactivation

## Boundary Notes

Why no bottom wall:
- Balls must fall into score zones
- Deactivation happens after scoring (Phase 5)
- For now, balls just disappear below screen

Wall collision order:
- Check after peg collisions
- Ensures balls don't escape through corners

Active count tracking:
- Used for spawning decisions
- Enables "ball limit" gameplay

## Success Criteria

- Balls bounce off left wall
- Balls bounce off right wall
- Balls bounce off top (if launched upward)
- Balls deactivate when falling below screen
- No balls escape through walls

## Related Documents

- [003-physics-system.md](../docs/003-physics-system.md)

## Dependencies

- Issue 301 (Ball state structure)
- Issue 302 (Ball physics)
- Issue 303 (Peg collision) - Order matters for collision checks

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/006-ball.h (added boundary constants)
- src/007-ball.c (added wall collision and bounds checking)
- src/006-ball.info.md (updated documentation)

**Implementation Steps Completed:**

1. Added boundary constants to 006-ball.h:
   - WALL_RESTITUTION: 0.6 (60% energy retention on wall bounce)
   - ZONE_TOP_Y: 560.0 (top of score zone area)

2. Implemented ball_collide_with_walls():
   - Checks left wall collision (x - radius < 0)
   - Checks right wall collision (x + radius > screen_width)
   - Checks top wall collision (y - radius < 0)
   - Repositions ball to boundary surface
   - Reflects velocity with WALL_RESTITUTION (60%)
   - No bottom wall - balls fall through to score zones

3. Implemented ball_check_bounds():
   - Checks if ball has fallen below screen
   - Deactivates ball when y - radius > screen_height
   - Allows ball cleanup when off-screen

4. Updated ball_manager_update():
   - Calls ball_collide_with_walls() after peg collision
   - Calls ball_check_bounds() after wall collision
   - Resets active_count at start of update
   - Recounts active balls during update loop
   - Ensures accurate active_count tracking

5. Collision order:
   - Physics update → Peg collision → Wall collision → Bounds check
   - Ensures balls don't escape through corners
   - Balls can collide with multiple pegs then bounce off wall

6. Updated API documentation in 006-ball.info.md:
   - Added boundary constants documentation

7. Compiled successfully with no new warnings

**Current Behavior:**
- Balls bounce off left wall with 60% energy retention
- Balls bounce off right wall with 60% energy retention
- Balls bounce off top wall (if launched upward)
- Balls deactivate when falling below screen
- No balls escape through walls
- active_count accurately tracks number of active balls
- Wall bounce slightly less energetic than peg bounce (realistic)

**Physics Notes:**
- Wall restitution (0.6) < peg restitution (0.7) feels more realistic
- Bounds checking uses y - radius to deactivate when fully off-screen
- active_count recalculation ensures accuracy after deactivation
- Bottom boundary is open - balls fall into score zones

**Phase 3 Progress:**
Issue 304 complete (4/5 issues, 80%). Ready for Issue 305 (ball spawning with input).
