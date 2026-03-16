# Issue 202: Implement Peg Grid Generation

## Current Behavior

No pegs exist in the world.

## Intended Behavior

Generate a staggered peg grid typical of pachinko machines:
- Alternating row offsets create zigzag ball paths
- Configurable grid dimensions and spacing
- Pegs stored in world state for collision detection (Phase 3)

## Peg Layout Pattern

```
    O   O   O   O   O      <- Row 0 (no offset)
  O   O   O   O   O   O    <- Row 1 (half-spacing offset)
    O   O   O   O   O      <- Row 2 (no offset)
  O   O   O   O   O   O    <- Row 3 (half-spacing offset)
```

## Suggested Implementation Steps

1. Add peg generation function to src/005-world.c:
   ```c
   void world_generate_pegs(World* world, int rows, int cols,
                            float start_x, float start_y,
                            float spacing);
   ```

2. Implement staggered grid algorithm:
   - Calculate total peg count
   - Allocate peg array
   - Loop through rows and columns
   - Apply half-spacing offset for odd rows
   - Set peg position and radius

3. Add peg rendering function to src/005-world.c:
   ```c
   void world_render_pegs(World* world);
   ```

4. Use raylib DrawCircle for each peg

5. Choose appropriate default values:
   - 10-12 rows of pegs
   - 8-10 columns per row
   - 50-60 pixel spacing
   - Start position centered in window

6. Test rendering in main loop

## Visual Requirements

- Pegs should be light gray (LIGHTGRAY)
- Peg radius: 12 pixels
- Grid should be centered horizontally
- Grid should start below title text
- Grid should end above score zones

## Related Documents

- [003-physics-system.md](../docs/003-physics-system.md)

## Dependencies

- Issue 201 (World state structure)

## Status

- [ ] Not started
