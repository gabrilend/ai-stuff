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

- [x] Completed

## Implementation Notes

**Files Modified:**
- src/004-world.h (added function declarations)
- src/005-world.c (added peg generation and rendering)
- src/005-world.info.md (added documentation)

**Implementation Steps Completed:**

1. Added world_generate_pegs() function to src/005-world.c:
   - Takes rows, cols, start position, and spacing parameters
   - Frees existing pegs before allocating new ones
   - Generates staggered grid with alternating row offsets
   - Odd rows offset by half-spacing for zigzag pattern
   - Sets PEG_RADIUS for each peg

2. Added world_render_pegs() function to src/005-world.c:
   - Renders each peg using raylib DrawCircle
   - Uses LIGHTGRAY color
   - Draws circles at peg position with peg radius

3. Updated src/004-world.h with function declarations

4. Updated src/005-world.info.md with complete documentation

5. Tested compilation successfully with no warnings

**Current Behavior:**
- Pegs can be generated in a staggered grid pattern
- Grid supports configurable dimensions and spacing
- Pegs render as light gray circles
- Safe to call with NULL world pointer
- Memory managed properly (frees old pegs before allocating)

**Design Notes:**
- Staggered pattern creates zigzag paths for ball movement (Phase 3)
- Peg grid is immutable after generation (read-only for collision)
- Rendering function separate from generation for flexibility
