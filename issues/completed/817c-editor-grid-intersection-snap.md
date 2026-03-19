# 1203c - Editor Grid Intersection Snap

## Current Behavior

Objects are placed at grid cell centers. When clicking near a grid line intersection, the object snaps to the center of the nearest cell instead.

## Intended Behavior

Objects should snap to grid line intersections (vertices) for more precise placement. This matches how pegs are typically positioned in pachinko layouts - at intersection points rather than cell centers.

## Suggested Implementation Steps

1. Modify `grid_to_pixel_x/y` usage in editor to return intersection points
2. Alternative: offset placement by `cell_size/2` to shift from center to corner
3. Update hover preview to show intersection snapping
4. May need to adjust grid dimensions (cols+1, rows+1 intersections vs cells)

## Files to Modify

- `src/032-editor-app.c` - Object placement and hover logic
- `src/022-grid.h` - May need intersection-specific conversion functions

## Testing

1. Run editor: `./edit`
2. Hover over grid - cursor should highlight intersection points
3. Click to place peg - peg should appear at intersection, not cell center
4. Verify visual alignment with grid lines

## Related Issues

- 1203-editor-improvements.md (parent issue)
