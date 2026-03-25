# Issue 511: Dynamic Window Resize Handling

## Current Behavior

Window is resizable but the world/pegs are not regenerated when the user
resizes the window. The game content stays at its initial size.

## Intended Behavior

When the user resizes the window:
1. Detect resize event each frame
2. Regenerate world with new dimensions
3. Regenerate pegs to fill new vertical space
4. Regenerate zones at new bottom position
5. Keep existing balls (or reset them if positions would be invalid)
6. Update camera/viewport accordingly

## Suggested Implementation Steps

1. In main loop, check `IsWindowResized()` each frame
2. If resized, get new dimensions with `GetScreenWidth()`/`GetScreenHeight()`
3. Recreate world with new dimensions
4. Regenerate pegs dynamically
5. Regenerate zones
6. Update camera offset
7. Handle balls that would be out of bounds

## Success Criteria

- Window can be resized smoothly
- Game content adapts to new window size
- No crashes or visual glitches on resize
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Added `IsWindowResized()` check in main loop (src/001-main.c:171-213).

When resize detected:
1. Gets new dimensions via `GetScreenWidth()`/`GetScreenHeight()`
2. Updates world dimensions
3. Recalculates table bounds via `world_set_table_bounds()`
4. Dynamically recalculates peg row count based on available height
5. Regenerates pegs centered in table
6. Regenerates zones using table bounds
7. Updates camera offset to new screen center
8. Clamps viewport offset to new valid range
9. Logs resize event with new dimensions and table_x offset

Existing balls are preserved during resize - they continue physics simulation
with new table bounds. Balls out of bounds will collide with new rail positions.

---

## Post-Implementation Bug Fixes

### Issue 1001h - Window Resize Affects Ball Physics (Phase 10)

**Problem:** Resizing window caused unexpected ball physics changes:
- Balls jumped to different positions
- Balls collided with objects at wrong positions
- Balls phased through obstacles they shouldn't

**Root Cause:** The resize handler shifted pegs and lines by `dx` (horizontal offset change), but balls were NOT shifted. This meant:
- Ball positions stayed at old X coordinates
- Peg/line collision targets moved to new X coordinates
- Collision detection failed or produced wrong results

**Fix:** Added ball and particle shifting in resize handler after peg/line shifting:
```c
// Shift all active balls to maintain relative position
for (int i = 0; i < ball_manager->capacity; i++) {
    if (ball_manager->balls_current[i].active) {
        ball_manager->balls_current[i].x += dx;
        ball_manager->balls_next[i].x += dx;
    }
}

// Shift active particles for visual continuity
for (int i = 0; i < particle_system->capacity; i++) {
    if (particle_system->particles_current[i].life > 0) {
        particle_system->particles_current[i].x += dx;
        particle_system->particles_next[i].x += dx;
    }
}
```

**Files Modified:** src/001-main.c
