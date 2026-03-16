# Issue 303: Implement Peg Collision

## Current Behavior

Balls fall through pegs without interaction. No collision detection
or response exists.

## Intended Behavior

Balls detect collision with pegs and bounce off:
- Circle-circle collision detection
- Velocity reflection on collision
- Energy loss (restitution coefficient)
- Balls deflect realistically through peg grid

## Suggested Implementation Steps

1. Add collision constants to 006-ball.h:
   ```c
   #define RESTITUTION 0.7f      // Bounce energy retention (0-1)
   #define COLLISION_BIAS 0.1f   // Separation push to prevent sticking
   ```

2. Implement circle-circle collision check:
   ```c
   int ball_check_peg_collision(Ball* ball, Peg* peg,
                                 float* nx, float* ny, float* depth) {
       float dx = ball->x - peg->x;
       float dy = ball->y - peg->y;
       float dist_sq = dx * dx + dy * dy;
       float min_dist = ball->radius + peg->radius;

       if (dist_sq >= min_dist * min_dist) return 0;

       float dist = sqrtf(dist_sq);
       if (dist < 0.001f) dist = 0.001f;  // Avoid division by zero

       *nx = dx / dist;  // Normal x
       *ny = dy / dist;  // Normal y
       *depth = min_dist - dist;

       return 1;  // Collision detected
   }
   ```

3. Implement collision response:
   ```c
   void ball_resolve_peg_collision(Ball* ball, float nx, float ny,
                                    float depth) {
       // Separate ball from peg
       ball->x += nx * (depth + COLLISION_BIAS);
       ball->y += ny * (depth + COLLISION_BIAS);

       // Calculate velocity dot normal
       float vn = ball->vx * nx + ball->vy * ny;

       // Only respond if moving into peg
       if (vn < 0) {
           // Reflect velocity with restitution
           ball->vx -= (1.0f + RESTITUTION) * vn * nx;
           ball->vy -= (1.0f + RESTITUTION) * vn * ny;
       }
   }
   ```

4. Add function to check all pegs:
   ```c
   void ball_collide_with_pegs(Ball* ball, World* world) {
       float nx, ny, depth;
       for (int i = 0; i < world->peg_count; i++) {
           if (ball_check_peg_collision(ball, &world->pegs[i],
                                         &nx, &ny, &depth)) {
               ball_resolve_peg_collision(ball, nx, ny, depth);
           }
       }
   }
   ```

5. Integrate collision into ball_manager_update():
   - After physics update, before buffer swap
   - Pass World pointer to update function
   ```c
   void ball_manager_update(BallManager* manager, World* world,
                            float dt);
   ```

6. Handle multiple collisions per frame:
   - A ball might hit multiple pegs in one frame
   - Process all collisions, response accumulates

7. Update 006-ball.info.md documentation

8. Test with ball dropping through peg grid

## Collision Notes

Why circle-circle:
- Both balls and pegs are circles
- Simple distance check
- Fast and accurate

Penetration resolution:
- Push ball out of peg along collision normal
- Prevents balls getting stuck inside pegs
- Small bias prevents repeated collision detection

Restitution:
- 0.7 means ball retains 70% of impact energy
- Creates realistic bouncy behavior
- Adjust for desired feel

## Success Criteria

- Balls bounce off pegs
- No balls pass through pegs
- Balls do not get stuck in pegs
- Bounce direction looks natural
- Multiple peg collisions work correctly

## Related Documents

- [003-physics-system.md](../docs/003-physics-system.md)

## Dependencies

- Issue 301 (Ball state structure)
- Issue 302 (Ball physics)

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/006-ball.h (added collision constants, World forward declaration, updated ball_manager_update signature)
- src/007-ball.c (added collision detection and response implementation)
- src/006-ball.info.md (updated documentation)
- src/001-main.c (passed world to ball_manager_update)

**Implementation Steps Completed:**

1. Added collision constants to 006-ball.h:
   - RESTITUTION: 0.7 (70% energy retention on bounce)
   - COLLISION_BIAS: 0.1 (small separation to prevent sticking)

2. Added World forward declaration to 006-ball.h:
   - Allows use of World* in function signatures
   - Avoids circular include dependencies

3. Implemented ball_check_peg_collision():
   - Circle-circle collision detection
   - Distance-squared optimization (avoids sqrt when no collision)
   - Returns collision normal and penetration depth
   - Handles zero-distance edge case (division by zero protection)
   - Returns 1 if collision, 0 otherwise

4. Implemented ball_resolve_peg_collision():
   - Separates ball from peg along collision normal
   - Adds COLLISION_BIAS to prevent repeated detection
   - Calculates velocity dot product with normal
   - Only responds if ball moving into peg (vn < 0)
   - Reflects velocity using formula: v' = v - (1 + e)(v·n)n
   - Restitution coefficient scales bounce energy

5. Implemented ball_collide_with_pegs():
   - Iterates through all pegs in world
   - Checks collision with each peg
   - Resolves collisions immediately
   - Handles multiple collisions per frame (accumulating response)

6. Updated ball_manager_update() signature:
   - Now takes World* parameter for peg access
   - Calls ball_collide_with_pegs() on next buffer after physics
   - Only checks collisions for active balls

7. Updated main.c integration:
   - Passes world to ball_manager_update(ball_manager, world, dt)
   - No other changes needed

8. Updated API documentation in 006-ball.info.md:
   - Updated ball_manager_update signature and description
   - Added collision constants documentation

9. Compiled successfully with no new warnings

**Current Behavior:**
- Ball bounces off pegs when colliding
- Collision detection accurate (circle-circle)
- Ball separates from pegs properly (no sticking)
- Velocity reflects realistically with 70% energy retention
- Multiple peg collisions handled correctly
- Ball deflects through peg grid creating zigzag paths
- No balls pass through pegs
- Bounce direction looks natural

**Physics Notes:**
- Circle-circle collision: simple distance check
- Penetration resolution prevents tunneling
- Restitution creates bouncy pachinko feel
- Multiple collisions per frame handled by iterating all pegs
- Collision response applied to next buffer (double-buffering preserved)

**Phase 3 Progress:**
Issue 303 complete (3/5 issues, 60%). Ready for Issue 304 (boundary collision).
