# 1003 - Rectangular Grid Cells

## Status: Completed

## Current Behavior

Grid cells now support rectangular dimensions throughout the codebase:
- `Grid` struct has `cell_width` and `cell_height` fields
- `ZoneGrid` struct has `cell_width` and `cell_height` fields
- `BoardData` struct has `cell_width` and `cell_height` fields
- `DEFAULT_GRID_CELL_WIDTH` and `DEFAULT_GRID_CELL_HEIGHT` constants used for calculations
- X calculations use `cell_width`, Y calculations use `cell_height`
- All physics systems (polygon, rotor, track mover) updated for rectangular cells

## Previous Behavior

Grid cells were assumed to be square throughout the codebase:
- `Grid` struct had single `cell_size` field
- `ZoneGrid` struct had single `cell_size` field
- `BoardData` struct had single `cell_size` field
- `DEFAULT_GRID_CELL_SIZE` constant used for both X and Y calculations

## Implementation Summary

### Structures Updated

1. **Grid** (src/022-grid.h)
   - `float cell_size` changed to `float cell_width; float cell_height`
   - `grid_create()` signature updated: `(cols, rows, cell_width, cell_height, origin_x, origin_y)`

2. **ZoneGrid** (src/045-zone-dispatch.h)
   - `float cell_size` changed to `float cell_width; float cell_height`
   - `zone_grid_create()` signature updated to accept both dimensions

3. **BoardData** (src/020-board-data.h)
   - `int cell_size` changed to `float cell_width; float cell_height`
   - `board_data_create()` signature updated: `(cols, rows, cell_width, cell_height)`

4. **TrackMoverManager** (src/052-track-mover.h)
   - `float cell_size` changed to `float cell_width; float cell_height`

### Physics Systems Updated

1. **Polygon Manager** (src/042-polygon.h, src/043-polygon.c)
   - `polygon_manager_rebuild()` now takes `cell_width, cell_height`
   - `polygon_manager_rebuild_offset()` now takes `cell_width, cell_height`
   - Line coordinate conversion uses appropriate dimension for X/Y

2. **Rotor Manager** (src/044-rotor.h, src/044-rotor.c)
   - `rotor_manager_add_from_board()` now takes `cell_width, cell_height`
   - Rotor center and connected object positions use correct dimensions

3. **Track Mover Manager** (src/052-track-mover.h, src/053-track-mover.c)
   - `track_mover_manager_add_from_board()` now takes `cell_width, cell_height`
   - Segment endpoint calculations, payload detection, and physics updates
     all use appropriate dimensions for X/Y coordinates
   - Speed conversion uses average cell dimension

### Files Modified

- src/020-board-data.h - BoardData struct
- src/021-board-data.c - Board data functions
- src/022-grid.h - Grid struct and constants
- src/023-grid.c - Grid functions
- src/025-editor.c - Old editor
- src/029-portal.c - Portal rendering
- src/032-editor-app.c - New editor app
- src/035-object-render.c - Object rendering
- src/042-polygon.h - Polygon manager header
- src/043-polygon.c - Polygon manager implementation
- src/044-rotor.h - Rotor manager header
- src/044-rotor.c - Rotor manager implementation
- src/045-zone-dispatch.h - ZoneGrid struct
- src/046-zone-dispatch.c - Zone dispatch functions
- src/052-track-mover.h - Track mover manager header
- src/053-track-mover.c - Track mover manager implementation
- src/001-main.c - Main game loop
- src/005-world.c - Zone generation

## Notes

The default 14x22 grid happens to have square cells (43x43) because 602/14 = 946/22 = 43.
Other grid sizes will have rectangular cells.

## Related Issues

- Issue 840: Grid dimension editing
- Issue 1002: Gate position mismatch (fixed using grid-aligned positioning)
