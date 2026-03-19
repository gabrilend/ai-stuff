# 216 - Unify Line and Ramp Abstraction

## Status: COMPLETE

## Problem

The codebase had two separate representations for line obstacles:
- **BoardObject (OBJECT_LINE)** - Editor/JSON representation with grid coordinates
- **Ramp struct** - Game/physics representation with pre-calculated collision geometry

The Ramp struct had redundant direction enum and pre-calculated fields.

## Solution

Created a unified **Line** struct for initial board data that:
- Stores pixel coordinates (x1, y1, x2, y2)
- Stores thickness
- Has editable physics properties (restitution, friction, point_bonus) like pegs
- Calculates collision geometry on-the-fly
- No pre-calculated/cached geometry
- No direction enum

Note: Stage system still uses old Ramp for dynamically purchased stages (can be refactored later).

## Implementation

### Created Line struct in `src/004-world.h`

```c
typedef struct Line {
    float x1, y1;         // Start point in pixels
    float x2, y2;         // End point in pixels
    float thickness;      // Line thickness

    float restitution;    // Bounciness (0.0-1.0)
    float friction;       // Surface grip (0.0-1.0)
    int point_bonus;      // Points awarded on hit

    Color color;          // Visual color
} Line;
```

### Updated World struct

- Changed `Ramp* ramps` to `Line* lines`
- Changed `Ramp* adversary_ramps` to `Line* adversary_lines`
- Removed Ramp forward declaration

### Added line collision code in `src/007-ball.c`

- `line_closest_point()` - geometry helper
- `ball_collide_with_line()` - collision detection and response
- `ball_collide_with_lines()` - iterates world lines

### Updated `src/001-main.c`

- `apply_initial_board_data()` now creates Line objects with physics properties
- `apply_adversary_board_data()` similarly updated
- Render calls changed to `world_render_lines()`

### Updated `src/005-world.c`

- `line_render()` - renders line with rounded caps and highlight
- `world_render_lines()` and `world_render_adversary_lines()`
- Initialize/destroy line arrays in world_create/destroy

## Files Modified

- `src/004-world.h` - Added Line struct, updated World
- `src/005-world.c` - Line rendering and initialization
- `src/001-main.c` - Board loading with Line objects
- `src/007-ball.c` - Line collision code

## Notes

- The old Ramp code (016-ramp.h/c) is still used by the stage system for dynamically purchased stages
- Initial board lines now use the new Line struct with editable physics properties
- Line color is derived from RGB properties like pegs

## Related Issues

- 1216 - JSON board overwritten on resize
