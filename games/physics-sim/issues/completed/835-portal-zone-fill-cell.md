# 835 - Portal Zones Fill Grid Cell

## Status: Complete

## Problem

Portal zones are positioned centered on grid intersection points like pegs and lines. This is inconsistent with their behavior as area-based triggers - they should fill the grid cell instead.

## Current Behavior

- Portal zones centered on intersection point (col, row)
- Zone extends beyond cell boundaries
- Visual doesn't align with grid cells
- Inconsistent with score gates which fill cells

## Intended Behavior

1. Portal zones positioned to fill grid cell, not centered on intersection
2. Zone top-left corner at cell origin, not centered on intersection
3. Visual rendering fills entire cell cleanly
4. Consistent behavior with other zone types (score gates)

## Implementation

### Editor Portal Preview (`src/032-editor-app.c`)

Changed portal preview placement to use grid intersection as top-left, not center:

```c
case APP_TOOL_PORTAL_ENTRY:
case APP_TOOL_PORTAL_EXIT: {
    // Portal fills cell starting at intersection point (issue 1227)
    float w = DEFAULT_PORTAL_SIZE * app->grid.cell_size;
    float h = DEFAULT_PORTAL_SIZE * app->grid.cell_size;
    PortalDirection dir = (app->tool == APP_TOOL_PORTAL_ENTRY) ? PORTAL_ENTRY : PORTAL_EXIT;
    render_portal_preview(x, y, w, h, dir, app->portal_channel);  // Removed x-w/2, y-h/2
    break;
}
```

### Zone Rendering (`src/035-object-render.c`)

Removed centering offset from `render_board_zones()`:

```c
// Convert grid coords to pixel coords (issue 1227)
// Zone starts at cell top-left, not centered on intersection
float x = grid_to_pixel_x(grid, zone->col, zone->row);
float y = grid_to_pixel_y(grid, zone->col, zone->row);

// Calculate size from grid
float width = zone->width * grid->cell_size;
float height = zone->height * grid->cell_size;

// No longer subtracting width/2, height/2 for centering
if (zone->type == ZONE_PORTAL) {
    render_portal_zone(x, y, width, height, zone->direction, zone->channel);
}
```

### Game-Side Code

The game-side code in `src/029-portal.c` was already correct:
- `portal_manager_load_from_board` converts zone grid coords to pixel coords (top-left)
- Then calculates center for internal storage in Portal struct
- `render_portal` correctly subtracts half width/height when drawing
- Ball collision detection uses center +/- half dimensions

## Files Modified

- `src/032-editor-app.c` - Portal preview positioning
- `src/035-object-render.c` - Zone rendering positioning

## Notes

- Game-side portal rendering in `src/029-portal.c` uses its own `render_portal()` function which stores center coords internally but draws correctly
- Editor uses `render_board_zones()` from `src/035-object-render.c` which now positions zones at cell top-left
- Both systems now produce visually consistent results with zones filling grid cells
