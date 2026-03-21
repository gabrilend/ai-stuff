# 1001b - Coordinate System Unification

## Status: Open

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Multiple systems calculate grid-to-pixel coordinates differently:

1. **Board objects in main.c**: `grid_to_pixel_x(&grid, obj->col, obj->row)`
2. **Polygon manager**: `obj->col * cell_size + cell_size / 2.0f`
3. **Object rendering**: `grid_to_pixel_x(grid, obj->col, obj->row)`

This causes visual rendering to not match collision positions.

## Intended Behavior

All systems should use a single, consistent method for converting grid coordinates to pixel coordinates.

## Grid-to-Pixel Formula

The canonical formula should be:
```c
pixel_x = grid->origin_x + col * grid->cell_size
pixel_y = grid->origin_y + row * grid->cell_size
```

Objects are centered on grid intersections, not cell centers.

## Files Requiring Changes

| File | Current Method | Required Change |
|------|----------------|-----------------|
| `src/043-polygon.c` | `col * cell_size + cell_size / 2.0f` | Use `grid_to_pixel_x/y` |
| `src/035-object-render.c` | Uses `grid_to_pixel_x/y` | Verify consistency |
| `src/001-main.c` | Uses `grid_to_pixel_x/y` | Verify all usages |
| `src/044-rotor.c` | Unknown | Verify |
| `src/053-track-mover.c` | Unknown | Verify |

## Implementation Steps

1. Audit all grid-to-pixel conversions in codebase
2. Create constants for any offsets needed
3. Update polygon manager to use `grid_to_pixel_x/y`
4. Ensure all systems use the same grid instance or equivalent params
5. Test that collision positions match render positions

## Testing

- Place a single peg at grid (7, 7)
- Verify rendered peg center matches collision detection center
- Drop ball onto peg, verify collision happens at visual position
