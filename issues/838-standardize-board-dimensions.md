# 838 - Standardize Board Dimensions

## Status: Open

## Parent Phase: See phase progress file

## Problem

Board JSON files currently contain explicit dimension data (cell_size, columns, rows, width, height) that duplicates constants defined in source code. This creates maintenance burden and potential inconsistencies when dimensions change.

## Current Behavior

Each board file contains:
```json
"grid": {
    "cell_size": 43,
    "columns": 14,
    "rows": 22
},
"board": {
    "width": 602,
    "height": 946
}
```

Source code defines the same values:
- `src/022-grid.h`: DEFAULT_GRID_CELL_SIZE, DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS
- `src/038-slot-manager.h`: SLOT_BOARD_HEIGHT

When dimensions change (as in issue 1308), every board file must be manually updated.

## Intended Behavior

Single source of truth for board dimensions. Options:

### Option A: Remove from JSON, Use Code Constants
- Board files only contain objects and zones
- Grid/board dimensions come from code constants
- Simplest approach, all boards identical size

### Option B: Optional Override in JSON
- Code constants provide defaults
- Board files can optionally override (for special boards)
- More flexible but adds complexity

### Option C: Separate Dimensions Config
- Create `boards/dimensions.json` with shared settings
- Board files reference it or inherit automatically
- Good separation but adds indirection

**Recommendation:** Option A for simplicity. All boards should use the same dimensions for consistent gameplay.

## Suggested Implementation

1. Update `board_data_load()` in `src/021-board-data.c`:
   - Ignore grid/board fields in JSON if present
   - Use DEFAULT_GRID_* constants from grid.h
   - Calculate board dimensions from grid constants

2. Update `board_data_save()` (if exists):
   - Don't write grid/board dimensions to JSON
   - Or write them as comments for reference only

3. Remove dimension fields from all board JSON files:
   - `boards/stage1-default.json`
   - `boards/in-and-out.json`
   - `boards/stage1-variant.json`
   - `boards/stage1-variant-2.json`

4. Update `scripts/compile` default board generator:
   - Remove hardcoded dimensions from generated JSON

## Files to Modify

- `src/021-board-data.c` - Load function to use constants
- `src/020-board-data.h` - Remove dimension fields from BoardData struct (if stored)
- `boards/*.json` - Remove grid/board sections
- `scripts/compile` - Update default board generator

## Benefits

- Single source of truth for dimensions
- No manual updates to boards when dimensions change
- Smaller, cleaner board JSON files
- Eliminates inconsistency bugs

## Notes

- This is a breaking change for existing board files
- Editor may need updates if it writes dimension data
- Consider migration path for user-created boards
