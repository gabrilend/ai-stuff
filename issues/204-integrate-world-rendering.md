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

- [ ] Not started
