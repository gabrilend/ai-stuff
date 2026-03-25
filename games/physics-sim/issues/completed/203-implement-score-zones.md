# Issue 203: Implement Score Zones

## Current Behavior

No score zones exist at the bottom of the screen.

## Intended Behavior

Create scoring slots at the bottom of the pachinko board:
- Multiple zones with different point values
- Higher values in center, lower at edges
- Visual display showing point values
- Zones stored in world state for scoring (Phase 5)

## Score Zone Layout

```
| 10 | 50 | 100 | 500 | 100 | 50 | 10 |
```

Center zone has highest value, decreasing toward edges.

## Suggested Implementation Steps

1. Add score zone generation function to src/005-world.c:
   ```c
   void world_generate_zones(World* world, int zone_count,
                             float zone_height);
   ```

2. Implement zone layout algorithm:
   - Divide bottom area into equal-width slots
   - Assign point values (symmetric, high center)
   - Store x_min, x_max, and points for each zone

3. Add zone rendering function to src/005-world.c:
   ```c
   void world_render_zones(World* world);
   ```

4. Render each zone:
   - Draw colored rectangle for zone background
   - Draw point value text centered in zone
   - Use different colors for different point values

5. Default zone configuration:
   - 7 zones across screen width
   - Zone height: 40 pixels
   - Point values: [10, 50, 100, 500, 100, 50, 10]

6. Test rendering in main loop

## Visual Requirements

- Zones fill bottom of screen
- Clear separation between zones (thin borders or gaps)
- Point values clearly readable
- Color coding by value:
  - 500: Gold/Yellow
  - 100: Green
  - 50: Blue
  - 10: Gray

## Related Documents

- [003-physics-system.md](../docs/003-physics-system.md)

## Dependencies

- Issue 201 (World state structure)

## Status

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/004-world.h (added function declarations)
- src/005-world.c (added zone generation and rendering)
- src/005-world.info.md (added documentation)

**Implementation Steps Completed:**

1. Added world_generate_zones() function to src/005-world.c:
   - Divides screen width into equal-width zones
   - Assigns symmetric point values (high center, low edges)
   - For 7 zones: uses [10, 50, 100, 500, 100, 50, 10] pattern
   - For other counts: calculates center-based values
   - Frees existing zones before allocating new ones

2. Added world_render_zones() function to src/005-world.c:
   - Renders zones at bottom of screen (40 pixels high)
   - Color codes by point value:
     - 500+: GOLD
     - 100-499: GREEN
     - 50-99: BLUE
     - <50: GRAY
   - Draws rectangles with borders
   - Centers point value text in each zone

3. Updated src/004-world.h with function declarations

4. Updated src/005-world.info.md with complete documentation

5. Tested compilation successfully (minor unused parameter warning)

**Current Behavior:**
- Score zones can be generated at bottom of screen
- Zones support configurable count
- Symmetric point value distribution
- Color-coded visual display
- Point values clearly readable
- Safe to call with NULL world pointer

**Design Notes:**
- Zone height hardcoded to 40 pixels in render function
- Zones will be used for ball scoring in Phase 5
- Default 7-zone layout matches classic pachinko pattern
