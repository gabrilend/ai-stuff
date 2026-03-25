# 1001g - Polygon Fill Alignment

## Status: Complete (Consolidated into Issue 802 via 1001b)

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Strange textures/fills appear across the game board, not aligned with actual line geometry. The polygon fill system (issue 837) is rendering closed regions, but the polygons don't match the visible line positions.

## Intended Behavior

Polygon fills should:
1. Exactly fill regions enclosed by visible lines
2. Use consistent coordinate system with line rendering
3. Only appear where closed cycles of lines exist

## Investigation Areas

### 1. Polygon Vertex Calculation (polygon.c:299-314)

```c
lines[li].start.x = obj->col * cell_size + cell_size / 2.0f;
lines[li].start.y = obj->row * cell_size + cell_size / 2.0f;
```

This adds `cell_size / 2.0f` offset, centering objects in cells.

### 2. Board Object Rendering

Board objects use `grid_to_pixel_x/y()` which may NOT add the half-cell offset:
```c
float x = grid->origin_x + col * grid->cell_size;
```

**Mismatch**: Polygon vertices are offset by half cell, rendered objects are not.

### 3. Guard Rail Positioning

Guard rails added in polygon.c:316-333:
```c
lines[li].start = (Vector2){0, 0};
lines[li].end = (Vector2){0, board_height};
```

These use (0,0) as origin, but actual board may be offset by `world->table_x`.

## Fix Strategy

### Option A: Update polygon manager to use grid_to_pixel

Pass grid instance to `find_all_intersections()` and use same conversion:
```c
lines[li].start.x = grid_to_pixel_x(grid, obj->col, obj->row);
lines[li].start.y = grid_to_pixel_y(grid, obj->col, obj->row);
```

### Option B: Remove half-cell offset from polygon manager

Change polygon manager to match grid_to_pixel behavior:
```c
lines[li].start.x = obj->col * cell_size;
lines[li].start.y = obj->row * cell_size;
```

Then update guard rail positions to use actual board offset.

## Resolution

Fixed as part of 1001b - removed `cell_size / 2.0f` offset from polygon vertex calculations
in `find_all_intersections()`. Now uses same coordinate system as `grid_to_pixel()`.

## Files Modified

- `src/043-polygon.c` - Vertex calculation in `find_all_intersections()`

## Testing

1. Create board with simple closed triangle of lines
2. Verify polygon fill exactly matches visual line boundaries
3. Verify guard rail intersections create correct boundary polygons
