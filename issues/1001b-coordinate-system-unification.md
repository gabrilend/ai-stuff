# 1001b - Coordinate System Unification

## Status: Complete

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

## Implementation

Fixed the polygon manager to use the same coordinate system as `grid_to_pixel`:

```c
// Before (cell-centered, offset by half cell):
lines[li].start.x = obj->col * cell_size + cell_size / 2.0f;

// After (intersection-based, no offset):
lines[li].start.x = obj->col * cell_size;
```

The origin offset is still applied afterwards via `polygon_manager_rebuild_offset()`,
which correctly shifts all vertices to match the board position.

## Files Modified

- `src/043-polygon.c` - Removed half-cell offset from vertex calculations in `find_all_intersections()`

## Testing

- Polygon fills should now align exactly with line boundaries
- No more half-cell offset between rendered lines and polygon fills
