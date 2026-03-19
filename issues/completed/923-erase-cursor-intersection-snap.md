# 1204 - Erase Cursor Intersection Snap

## Current Behavior (Fixed)

The erase mode cursor now correctly highlights intersection points instead of cell centers.

## Previous Behavior

The `render_grid_cursor` function was drawing a full cell rectangle starting from the cell corner:
- Drew `DrawRectangle` from (col * cell_size, row * cell_size)
- This created a cell-sized highlight that didn't align with intersection-based object placement

## Changes Made

Updated `render_grid_cursor` in `src/035-object-render.c`:

1. Changed bounds check to allow col == cols and row == rows (valid edge intersections)
2. Changed from drawing a full cell rectangle to drawing a circle centered on the intersection point
3. Circle radius is 0.4 * cell_size for clear visibility while matching intersection-based placement

## Files Modified

- `src/035-object-render.c` - render_grid_cursor function

## Related Issues

- Part of 1203c - Grid Intersection Snap (the erase mode aspect)

## Notes

The snap-to-grid behavior means the cursor snaps to the nearest intersection, which may not be exactly at the mouse pointer position. This is expected behavior - the highlight shows where an erase action would occur, not the exact mouse position.
