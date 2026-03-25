# 840 - Editor Grid Scaling

## Status: completed

## Depends on

None - independent editor feature.

## Implementation Notes

Added grid settings UI to the editor sidebar with +/- buttons for columns and rows:

- **Grid dimension limits**: 8-24 columns, 12-36 rows
- **UI location**: Right sidebar below Board Stats, in "Grid Settings" section
- **Controls**: +/- buttons for columns and rows, calculated cell size display
- **Resize logic**: `change_grid_dimensions()` function handles:
  - Grid dimension validation and clamping
  - Cell size recalculation from fixed board dimensions (602x946)
  - Object repositioning (clamped to new bounds)
  - Zone size clamping
  - Rotor position clamping
  - Polygon manager rebuild
- **Input handling**: `handle_grid_settings_input()` detects button clicks

The grid maintains the fixed board size (602x946 pixels) while allowing variable cell counts. Cell size is calculated as the minimum of width/cols and height/rows to ensure cells fit.

## Related Issues

- 838 (Standardize pixel dimensions) - complementary
  - 838: Removes redundant pixel data from JSON (cell_size, board width/height)
  - 840: Adds UI to edit grid density (columns, rows)
  - Both assume: fixed board size, calculated cell size

## Problem

Users cannot adjust the grid dimensions for a specific board in the editor. All boards use the same default column/row count.

## Current Behavior

- Grid dimensions fixed at DEFAULT_GRID_COLS = 14, DEFAULT_GRID_ROWS = 22
- No UI to adjust grid density per-board
- Cell size is hardcoded rather than calculated

## Intended Behavior

Board size is FIXED. Grid density (columns/rows) is ADJUSTABLE. Cell size is CALCULATED.

```
cell_width  = BOARD_WIDTH  / columns
cell_height = BOARD_HEIGHT / rows
```

1. Add columns and rows sliders to editor UI
2. Sliders snap to integer increments
3. Grid visuals update dynamically (cells get smaller/larger)
4. Objects reposition proportionally when grid density changes
5. Save columns/rows to board JSON

## Suggested Implementation Steps

1. Add grid dimension sliders to editor property panel:
   - Columns slider: range 8-20 (reasonable bounds)
   - Rows slider: range 12-30 (reasonable bounds)
   - Both snap to integer values
   - Show calculated cell size as read-only info

2. Implement dynamic grid resize in editor:
   - Update grid.columns and grid.rows when sliders change
   - Recalculate cell_width and cell_height
   - Redraw grid lines immediately (same board size, different cell count)

3. Implement object repositioning on resize:
   - Objects are stored in grid coordinates (column, row)
   - When grid density changes, objects stay at same grid position
   - If object at column 15 and new max is 12, clamp or warn user

4. Update board save/load:
   - Write columns and rows to JSON
   - Read and calculate cell size on load

5. Update editor grid rendering:
   - Handle variable column/row counts
   - Cell size = board_size / grid_count

## Files to Modify

- `src/032-editor-app.c` - Add sliders and resize logic
- `src/022-grid.h` / `src/023-grid.c` - Calculate cell size from board/grid
- `src/021-board-data.c` - Save/load columns and rows only

## UI Design

```
[Grid Settings]
Columns: [====|======] 14
Rows:    [========|==] 22
Cell:    43 x 43 px (calculated)
```

Sliders update grid in real-time. Cell dimensions shown as info only.

Note: Cells may be rectangular if column/row ratio differs from board aspect ratio.

## Edge Cases

- Objects outside new grid bounds: warn user before shrinking
- Minimum grid: ensure spawn area and essential zones fit
- Maximum grid: very small cells may be impractical
- Non-square cells: if columns/rows ratio differs from board ratio

## Notes

- Board canvas size NEVER changes (fixed in code)
- Only grid density changes (more/fewer cells)
- Cell size adapts automatically
