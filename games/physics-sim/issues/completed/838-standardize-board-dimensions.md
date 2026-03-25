# 838 - Standardize Pixel Dimensions

## Status: completed

## Depends on

None - cleanup/refactor task.

## Related Issues

- 840 (Editor grid scaling) - complementary, not conflicting
  - 838: Removes redundant pixel data from JSON
  - 840: Allows custom grid dimensions (columns, rows per-board)

## Problem

Board JSON files currently contain explicit pixel dimension data (cell_size, board width, board height) that is redundant. Board size is fixed in code, and cell size is calculated from board size and grid dimensions.

## Current Behavior

Each board file contains:
```json
"grid": {
    "cell_size": 43,      // Redundant - calculated from board/grid
    "columns": 14,        // Per-board, keep in JSON
    "rows": 22            // Per-board, keep in JSON
},
"board": {
    "width": 602,         // Redundant - fixed in code
    "height": 946         // Redundant - fixed in code
}
```

## Intended Behavior

Board dimensions are FIXED (same for all boards). Cell size is CALCULATED.

```
cell_width  = BOARD_WIDTH  / columns
cell_height = BOARD_HEIGHT / rows
```

- More columns/rows = smaller cells
- Fewer columns/rows = larger cells
- Board canvas size never changes

JSON only needs to store:
```json
"grid": {
    "columns": 14,
    "rows": 22
}
```

## Suggested Implementation

1. Update `board_data_load()` in `src/021-board-data.c`:
   - Read `columns` and `rows` from JSON (required fields)
   - Use fixed BOARD_WIDTH and BOARD_HEIGHT from code
   - Calculate `cell_width = BOARD_WIDTH / columns`
   - Calculate `cell_height = BOARD_HEIGHT / rows`
   - Note: cells may be rectangular if column/row ratio differs from board aspect ratio

2. Update `board_data_save()`:
   - Write only `columns` and `rows` to grid section
   - Don't write `cell_size`, `board.width`, or `board.height`

3. Clean up existing board JSON files:
   - Remove `cell_size` from grid section
   - Remove entire `board` section (width/height)
   - Keep only `columns` and `rows`

4. Update `scripts/compile` default board generator:
   - Only generate `columns` and `rows`

## Files to Modify

- `src/021-board-data.c` - Load/save with calculated cell size
- `src/022-grid.h` - Ensure BOARD_WIDTH/HEIGHT constants exist
- `boards/*.json` - Remove redundant pixel dimension fields
- `scripts/compile` - Update default board generator

## Benefits

- Board size is single source of truth (code constant)
- Cell size adapts to grid density automatically
- Cleaner, smaller board JSON files
- Enables variable grid densities (see 840)

## Notes

- No backwards compatibility needed - clean up all existing board files
- Cell dimensions may be non-integer if board doesn't divide evenly by grid count
- Cells may be rectangular (cell_width != cell_height) depending on column/row ratio
- Grid struct should store cell_width and cell_height separately, not a single cell_size

## Completion

**Implemented:**
1. Added `BOARD_WIDTH` (602.0f) and `BOARD_HEIGHT` (946.0f) constants to `src/022-grid.h`
2. Updated `board_data_load_json()` in `src/021-board-data.c` to:
   - Ignore `cell_size` from JSON (calculate instead)
   - Calculate cell_size from board dimensions / grid counts
   - Use minimum of width/cols and height/rows for square cells
3. Updated `board_data_to_json_string()` to not write:
   - `cell_size` in grid section
   - Entire `board` section (width/height)
4. Updated `scripts/compile` default board generator
5. Cleaned all existing board JSON files in `boards/` directory

**Result:**
- Board JSON files now only store `columns` and `rows` in grid section
- All boards use fixed 602x946 canvas dimensions
- Cell size is calculated at load time based on grid density
