# Issue 805 - Adversary Spawning AI

## Status
Pending

## Current Behavior
No adversary exists. Only player can spawn balls.

## Intended Behavior
- Adversary has spawn reticle at bottom of their board
- Reticle moves back and forth at constant speed
- Adversary spawns balls at similar rate to player
- Spawn rate calculated independently from player
- Adversary balls have distinct visual appearance

## Suggested Implementation Steps

1. **Create Adversary structure**
   - spawn_x position (horizontal)
   - spawn_direction (+1 or -1, for movement)
   - spawn_speed (pixels per second)
   - spawn_credits (like player's credit system)
   - spawn_rate (balls per second)

2. **Implement reticle movement**
   - adversary_update() called each frame
   - Move spawn_x by spawn_speed * dt * direction
   - Reverse direction at table bounds
   - Smooth, predictable oscillation

3. **Implement spawning logic**
   - Accumulate spawn_credits over time
   - When credits >= 1.0, attempt spawn
   - Check spawn blocking (same as player)
   - Spawn ball at adversary spawn position

4. **Create adversary BallManager**
   - Separate ball array for adversary balls
   - Or: add "owner" field to Ball struct (PLAYER/ADVERSARY)
   - Adversary balls rendered with different color (red?)

5. **Render adversary reticle**
   - Draw reticle at adversary spawn position
   - Different color from player (red vs cyan)
   - Same cooldown indicator style

6. **Tune AI parameters**
   - Movement speed: ~100 pixels/sec (slower than player)
   - Spawn rate: 4-5 balls/sec (similar to player)
   - No intelligence needed yet (just oscillation)

## Dependencies
- Issue 804 (Adversary Board Layout) must be complete

## Related Documents
- src/007-ball.c (spawn system reference)
- main.c (player spawn handling)

## Notes
- Keep AI simple: predictable movement is fair and learnable
- Future enhancement: AI could target high-value zones
- Future enhancement: AI spawn rate could scale with game time
- Adversary balls need reversed gravity (handled in Issue 807)
