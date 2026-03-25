# Issue 305: Implement Ball Spawning with Input

## Current Behavior

No way to spawn balls. The simulation runs but no balls exist to
demonstrate the physics.

## Intended Behavior

Player can spawn balls using keyboard input:
- Space key spawns a new ball
- Ball appears at top center of screen
- Initial velocity: slight random horizontal, small downward
- Rate limiting prevents spam spawning
- Visual feedback when spawning

## Suggested Implementation Steps

1. Add spawning constants to 006-ball.h:
   ```c
   #define SPAWN_X 400.0f            // Default spawn x (center)
   #define SPAWN_Y 50.0f             // Default spawn y (top)
   #define SPAWN_VX_RANGE 100.0f     // Random horizontal range
   #define SPAWN_VY_INITIAL 50.0f    // Initial downward velocity
   #define SPAWN_COOLDOWN 0.1f       // Minimum time between spawns
   ```

2. Add spawn tracking to BallManager:
   ```c
   typedef struct BallManager {
       Ball* balls_current;
       Ball* balls_next;
       int capacity;
       int active_count;
       float spawn_cooldown;  // Time until next spawn allowed
   } BallManager;
   ```

3. Implement ball_manager_spawn():
   ```c
   int ball_manager_spawn(BallManager* manager, float x, float y) {
       // Find inactive slot
       for (int i = 0; i < manager->capacity; i++) {
           if (!manager->balls_current[i].active) {
               Ball* ball = &manager->balls_current[i];
               ball->x = x;
               ball->y = y;
               ball->vx = (rand() / (float)RAND_MAX - 0.5f) *
                          SPAWN_VX_RANGE * 2;
               ball->vy = SPAWN_VY_INITIAL;
               ball->radius = BALL_RADIUS;
               ball->active = 1;
               manager->active_count++;
               return 1;  // Success
           }
       }
       return 0;  // No slots available
   }
   ```

4. Implement cooldown update:
   ```c
   void ball_manager_update_cooldown(BallManager* manager, float dt) {
       if (manager->spawn_cooldown > 0) {
           manager->spawn_cooldown -= dt;
       }
   }

   int ball_manager_can_spawn(BallManager* manager) {
       return manager->spawn_cooldown <= 0 &&
              manager->active_count < manager->capacity;
   }

   void ball_manager_reset_cooldown(BallManager* manager) {
       manager->spawn_cooldown = SPAWN_COOLDOWN;
   }
   ```

5. Add input handling in main loop:
   ```c
   // In main loop, before physics update:
   ball_manager_update_cooldown(ball_manager, dt);

   if (IsKeyDown(KEY_SPACE) && ball_manager_can_spawn(ball_manager)) {
       ball_manager_spawn(ball_manager, SPAWN_X, SPAWN_Y);
       ball_manager_reset_cooldown(ball_manager);
   }
   ```

6. Add ball count display:
   ```c
   // In render section:
   char ball_text[32];
   sprintf(ball_text, "Balls: %d", ball_manager->active_count);
   DrawText(ball_text, 10, screen_height - 50, 16, WHITE);
   ```

7. Seed random number generator in main():
   ```c
   srand((unsigned int)time(NULL));
   ```

8. Update includes for stdlib.h and time.h

9. Integrate BallManager into main():
   - Create after world
   - Update and render in loop
   - Destroy before world

10. Update 006-ball.info.md documentation

11. Test spawning with space key

## Input Notes

Why IsKeyDown vs IsKeyPressed:
- IsKeyDown: Can hold to spawn continuously
- Rate limited by cooldown
- More fun for pachinko gameplay

Random velocity:
- Adds variety to ball paths
- Each ball takes different route through pegs
- Makes gameplay interesting

## Success Criteria

- Space key spawns balls
- Balls appear at top center
- Each ball has slightly different trajectory
- Cannot spawn faster than cooldown allows
- Ball count display accurate
- Works up to capacity limit (256 balls)

## Related Documents

- [004-raylib-integration.md](../docs/004-raylib-integration.md)

## Dependencies

- Issue 301 (Ball state structure)
- Issue 302 (Ball physics)
- Issue 303 (Peg collision)
- Issue 304 (Boundary collision)

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/006-ball.h (added spawning constants, spawn_cooldown field, function declarations)
- src/007-ball.c (updated spawn function, added cooldown management)
- src/006-ball.info.md (updated documentation)
- src/001-main.c (added RNG seeding, input handling, ball count display)

**Implementation Steps Completed:**

1. Added spawning constants to 006-ball.h:
   - SPAWN_X: 400.0 (screen center)
   - SPAWN_Y: 50.0 (top of screen)
   - SPAWN_VX_RANGE: 100.0 (random horizontal velocity range)
   - SPAWN_VY_INITIAL: 50.0 (initial downward velocity)
   - SPAWN_COOLDOWN: 0.1 (minimum time between spawns)

2. Added spawn_cooldown field to BallManager struct:
   - Tracks time until next spawn allowed
   - Initialized to 0.0 in ball_manager_create()

3. Updated ball_manager_spawn():
   - Sets random horizontal velocity: (rand() / RAND_MAX - 0.5) * SPAWN_VX_RANGE * 2
   - Sets initial downward velocity: SPAWN_VY_INITIAL
   - Creates variety in ball trajectories
   - Each ball takes different path through pegs

4. Implemented ball_manager_update_cooldown():
   - Decrements spawn_cooldown by delta time
   - Called each frame before input handling

5. Implemented ball_manager_can_spawn():
   - Checks if spawn_cooldown <= 0 (cooldown expired)
   - Checks if active_count < capacity (slots available)
   - Returns 1 if both conditions met, 0 otherwise

6. Implemented ball_manager_reset_cooldown():
   - Sets spawn_cooldown to SPAWN_COOLDOWN (0.1 seconds)
   - Called after successful spawn

7. Added input handling in main loop:
   - Uses IsKeyDown(KEY_SPACE) for continuous spawning
   - Checks ball_manager_can_spawn() before spawning
   - Calls ball_manager_spawn(manager, SPAWN_X, SPAWN_Y)
   - Resets cooldown after successful spawn
   - Rate limited to prevent spam (10 balls/sec max)

8. Added ball count display:
   - Shows "Balls: N" where N is active_count
   - Displayed at bottom left above score
   - Updates in real-time as balls spawn/deactivate

9. Seeded random number generator:
   - srand((unsigned int)time(NULL)) in main()
   - Added stdlib.h and time.h includes
   - Ensures different ball trajectories each run

10. Removed test ball spawn:
    - Replaced with player-controlled spawning
    - Added "Press SPACE to spawn balls" instruction

11. Updated API documentation in 006-ball.info.md:
    - Added spawn_cooldown field to BallManager documentation
    - Added ball_manager_update_cooldown documentation
    - Added ball_manager_can_spawn documentation
    - Added ball_manager_reset_cooldown documentation
    - Added spawning constants documentation

12. Compiled successfully with no new warnings

**Current Behavior:**
- Press and hold SPACE to spawn balls continuously
- Balls spawn at top center (400, 50)
- Each ball has random horizontal velocity
- Spawn rate limited to 0.1 second cooldown
- Ball count display shows active ball count
- Up to 256 balls can be active simultaneously
- Each ball takes unique path through peg grid
- Visual variety makes pachinko gameplay engaging

**Input Notes:**
- IsKeyDown allows continuous spawning (hold SPACE)
- Cooldown prevents excessive spawn rate
- Random velocity creates interesting gameplay
- Player can experiment with different timing

**Phase 3 Progress:**
Issue 305 complete (5/5 issues, 100%). PHASE 3 COMPLETE!
