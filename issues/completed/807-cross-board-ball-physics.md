# Issue 807 - Cross-Board Ball Physics

## Status
Completed

## Current Behavior
- Ball struct has gravity_dir field (+1.0 downward, -1.0 upward)
- Ball struct has owner field (OWNER_PLAYER or OWNER_ADVERSARY)
- Physics update multiplies GRAVITY by gravity_dir
- Balls collide with both player and adversary pegs
- Balls collide with both player and adversary bumpers
- Cross-board collisions (different owners) apply 2x impulse multiplier
- Dramatic momentum transfer when player and adversary balls collide

## Previous Behavior
- All balls have same gravity direction (downward)
- Ball-ball collisions use standard elastic physics
- No concept of "opposing" balls

## Intended Behavior
- Adversary balls have reversed gravity (upward)
- Adversary balls bounce off adversary pegs normally
- Cross-board collisions (player vs adversary ball) have double strength
- Momentum transfer: fast ball imparts velocity to slow ball
- Creates chaotic, exciting interactions at gate boundary

## Suggested Implementation Steps

1. **Add gravity direction to Ball struct**
   - gravity_direction field (+1.0 or -1.0)
   - Player balls: +1.0 (downward)
   - Adversary balls: -1.0 (upward)

2. **Modify physics update**
   - ball_update_physics() multiplies GRAVITY by gravity_direction
   - Adversary balls accelerate upward
   - All other physics unchanged

3. **Implement cross-board collision detection**
   - Detect when player ball collides with adversary ball
   - Could use ball owner flag or position-based detection
   - Call special collision handler

4. **Implement enhanced collision response**
   - Calculate normal collision response
   - Apply 2x multiplier to impulse magnitude
   - Proper momentum transfer:
     - Combined momentum = m1*v1 + m2*v2
     - Distribute based on collision angle
     - Fast ball loses more velocity
     - Slow ball gains more velocity

5. **Collision with opposite pegs**
   - Player balls collide with adversary pegs (when passing through)
   - Adversary balls collide with player pegs
   - Use existing peg collision code
   - Check against both peg arrays

6. **Visual feedback for cross-board collision**
   - Brighter particle burst on impact
   - Screen shake or flash (subtle)
   - Different sound effect (if audio added)

## Dependencies
- Issue 804 (Adversary Board Layout) - peg arrays exist
- Issue 805 (Adversary Spawning AI) - adversary balls exist
- Issue 806 (Shared Gates) - balls can reach opposite board

## Physics Notes

**Momentum Transfer Formula:**
```
// Standard elastic collision (equal mass)
v1_final = v1 - (v1 - v2) dot n * n
v2_final = v2 - (v2 - v1) dot n * n

// Enhanced (2x strength)
impulse = (v1 - v2) dot n
v1_final = v1 - 2.0 * impulse * n
v2_final = v2 + 2.0 * impulse * n
```

**Example:**
- Player ball moving at (0, 100) hits stationary adversary ball
- Normal collision: each moves at (0, 50)
- Enhanced collision: player stops, adversary moves at (0, 100) and beyond

## Related Documents
- src/007-ball.c (ball_resolve_ball_collision)
- src/006-ball.h (Ball struct)

## Notes
- Mass is assumed equal for simplicity
- Double-strength creates dramatic interactions
- Players can strategically aim to "spike" enemy balls
- Future: power-ups could modify collision strength

## Implementation Notes
- Added gravity_dir and owner fields to Ball struct in src/006-ball.h
- Added OWNER_PLAYER (0) and OWNER_ADVERSARY (1) constants
- Modified ball_manager_spawn to accept radius, owner, gravity_dir parameters
- Modified ball_update_physics to multiply GRAVITY by gravity_dir:
  `next->vy = current->vy + GRAVITY * current->gravity_dir * dt;`
- Modified ball_collide_with_pegs to check both world->pegs and world->adversary_pegs
- Modified ball_collide_with_bumpers to check both bumper arrays
- Modified ball_resolve_ball_collision:
  - Checks if ball_a->owner != ball_b->owner
  - If cross-board collision, applies strength_multiplier = 2.0
  - Impulse formula: `-(1.0f + RESTITUTION) * vn * strength_multiplier`
