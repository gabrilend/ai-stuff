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

- [ ] Not started
