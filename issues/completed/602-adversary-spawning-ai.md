# Issue 805 - Adversary Spawning AI

## Status
Completed

## Current Behavior
Adversary AI spawns balls from an oscillating reticle at the bottom of the adversary board. Reticle moves back and forth at ADVERSARY_MOVE_SPEED (120 px/sec), bouncing off table edges. Spawn credits accumulate at ADVERSARY_SPAWN_RATE (4 balls/sec). Adversary balls are spawned with gravity_dir=-1.0 (upward) and owner=OWNER_ADVERSARY. Red-tinted reticle with cooldown arc indicator.

## Previous Behavior
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

## Implementation Notes
- Created src/012-adversary.h with Adversary struct
- Created src/013-adversary.c with adversary_create/destroy/update/render/reset
- Adversary struct holds: spawn_x, spawn_y, spawn_direction, spawn_credits, spawn_rate, move_speed
- adversary_update() called each frame in main loop
- adversary_render() draws reticle and cooldown arc
- adversary_reset() called on R key press and window resize
- Uses ball_manager_spawn() with OWNER_ADVERSARY and gravity_dir=-1.0

---

## Post-Implementation Bug Fixes

### Issue 1001c - Adversary Board Vertical Flip Formula (Phase 10)

**Problem:** Adversary board objects positioned incorrectly due to off-by-one error in vertical flip formula.

Original code: `int flipped_row = data->grid_rows - obj->row;`

For a 22-row grid (rows 0-21):
- Row 0 became row 22 (beyond grid bounds)
- Row 21 became row 1
- Row 10 became row 12

**Intended Behavior:** Proper vertical mirroring:
- Row 0 → Row 21 (top becomes bottom)
- Row 21 → Row 0 (bottom becomes top)
- Row 10 → Row 11 (center stays near center)

**Fix:** Changed formula to `flipped_row = data->grid_rows - 1 - obj->row`

**Files Modified:** src/001-main.c
- Line 111: `apply_board_data_to_stage()` peg flipping
- Line 137-138: `apply_board_data_to_stage()` line endpoint flipping
- Line 311: `apply_adversary_board_data()` peg flipping
- Line 349-350: `apply_adversary_board_data()` line endpoint flipping
