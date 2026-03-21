# 1003 - Rectangular Grid Cells

## Status: Completed

## Current Behavior

Grid cells now support rectangular dimensions:
- `Grid` struct has `cell_width` and `cell_height` fields
- `ZoneGrid` struct has `cell_width` and `cell_height` fields
- `BoardData` struct has `cell_width` and `cell_height` fields
- `DEFAULT_GRID_CELL_WIDTH` and `DEFAULT_GRID_CELL_HEIGHT` constants used for calculations
- X calculations use `cell_width`, Y calculations use `cell_height`

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

### Files Modified

- src/022-grid.h - Grid struct and constants
- src/023-grid.c - Grid functions
- src/045-zone-dispatch.h - ZoneGrid struct
- src/046-zone-dispatch.c - Zone dispatch functions
- src/020-board-data.h - BoardData struct
- src/021-board-data.c - Board data functions
- src/001-main.c - Main game loop
- src/005-world.c - Zone generation
- src/029-portal.c - Portal rendering
- src/035-object-render.c - Object rendering
- src/025-editor.c - Old editor
- src/032-editor-app.c - New editor app

### TODO: Follow-up Work

The following systems still use a single `cell_size` parameter and should be updated
for full rectangular cell support in a future issue:

1. **Polygon Manager** (src/043-polygon.c)
   - `polygon_manager_rebuild()` takes single cell_size
   - Currently passes `cell_width` for compatibility

2. **Rotor Manager** (src/044-rotor.c)
   - `rotor_manager_add_from_board()` takes single cell_size
   - Currently passes `cell_width` for compatibility

3. **Track Mover Manager** (src/053-track-mover.c)
   - `track_mover_manager_add_from_board()` takes single cell_size
   - Currently passes `cell_width` for compatibility

## Notes

The default 14x22 grid happens to have square cells (43x43) because 602/14 = 946/22 = 43.
Other grid sizes will have rectangular cells.

## Related Issues

- Issue 840: Grid dimension editing
- Issue 1002: Gate position mismatch (fixed using grid-aligned positioning)
