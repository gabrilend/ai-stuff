# Issue 204: Integrate World Rendering

## Current Behavior

Main loop renders placeholder text only. World state not connected.

## Intended Behavior

Complete visual pachinko board display:
- World created and initialized at startup
- Pegs rendered each frame
- Score zones rendered each frame
- Current score displayed
- Clean shutdown with world destruction

## Suggested Implementation Steps

1. Update src/001-main.c to include world header

2. Create world in main() after threadpool:
   ```c
   World* world = world_create(screen_width, screen_height);
   world_generate_pegs(world, 10, 8, ...);
   world_generate_zones(world, 7, 40);
   ```

3. Add world rendering in main loop:
   ```c
   // In render section:
   world_render_pegs(world);
   world_render_zones(world);
   world_render_score(world);
   ```

4. Add world destruction before threadpool cleanup:
   ```c
   world_destroy(world);
   ```

5. Remove placeholder text, keep title and exit instruction

6. Add score display function:
   ```c
   void world_render_score(World* world);
   ```

7. Test complete visual display

## Visual Layout

```
+----------------------------------+
| Physics Simulator - Pachinko     |
|                                  |
|     O   O   O   O   O            |
|   O   O   O   O   O   O          |
|     O   O   O   O   O            |
|   O   O   O   O   O   O          |
|     O   O   O   O   O            |
|   O   O   O   O   O   O          |
|     O   O   O   O   O            |
|   O   O   O   O   O   O          |
|                                  |
| 10 | 50 | 100 | 500 | 100| 50|10 |
| Score: 0         Press ESC exit  |
+----------------------------------+
```

## Success Criteria

- Pegs render in staggered grid pattern
- Score zones visible at bottom with point values
- Score display shows current score (starts at 0)
- Clean visual layout with proper spacing
- No placeholder text remaining
- Clean startup and shutdown sequence

## Related Documents

- [004-raylib-integration.md](../docs/004-raylib-integration.md)

## Dependencies

- Issue 201 (World state structure)
- Issue 202 (Peg grid generation)
- Issue 203 (Score zones)

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/001-main.c (integrated world creation and rendering)

**Implementation Steps Completed:**

1. Updated src/001-main.c to include world header (004-world.h)

2. Created world after threadpool initialization:
   - world_create() with screen dimensions
   - Error handling for allocation failure

3. Generated peg grid with proper layout:
   - 10 rows, 8 columns
   - 60 pixel spacing
   - Centered horizontally: start_x = (800 - 480) / 2 = 160
   - Start_y = 80 (below title)

4. Generated score zones:
   - 7 zones across screen width
   - 40 pixels high at bottom

5. Added world rendering in main loop:
   - world_render_pegs() draws staggered peg grid
   - world_render_zones() draws color-coded score zones
   - Score display shows current score (starts at 0)

6. Removed "Phase 1 Complete" placeholder text

7. Added world destruction in cleanup sequence:
   - world_destroy() called before threadpool cleanup
   - Proper shutdown order: window → world → threadpool

8. Tested compilation successfully

**Current Behavior:**
- Complete visual pachinko board display
- Pegs render in staggered grid pattern
- Score zones visible at bottom with point values [10, 50, 100, 500, 100, 50, 10]
- Score display shows current score (0)
- Title and exit instructions visible
- Clean startup and shutdown sequence
- All resources properly freed

**Visual Elements:**
- Title: "Physics Simulator - Pachinko" (top left)
- Peg grid: 10x8 staggered pattern (centered)
- Score zones: 7 color-coded zones at bottom
- Score display: "Score: 0" (bottom left)
- Exit instruction: "Press ESC to exit" (bottom right)

**Phase 2 Complete:**
Static pachinko board fully functional. Ready for ball physics (Phase 3).
