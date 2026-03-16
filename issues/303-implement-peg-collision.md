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

- [ ] Pending
