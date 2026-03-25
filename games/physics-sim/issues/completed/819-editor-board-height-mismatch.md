# 819 - Editor Board Height Mismatch

## Current Behavior

When loading the default map in the editor, the board height appears misconfigured. Objects may appear at incorrect positions or the grid doesn't align properly with loaded board data.

## Intended Behavior

All boards should use consistent dimensions. Boards should be "hot-swappable" - like playing cards being moved around on a table. The editor and game should share the same board configuration so loaded boards display correctly.

## Analysis

The issue likely stems from:
1. Editor using different grid dimensions (EDITOR_GRID_COLS/ROWS) than the game
2. BoardData storing its own dimensions that may not match the editor's grid
3. When loading a board, the editor grid may not resize to match the loaded board's dimensions

## Suggested Implementation Steps

1. Find where board dimensions are defined in both game and editor
2. Identify the source of truth for board dimensions
3. Ensure BoardData dimensions are respected when loading
4. Consider making board dimensions a shared constant or having the editor adapt to loaded board dimensions
5. Test loading boards created in different contexts

## Files to Investigate

- `src/031-editor-app.h` - EDITOR_GRID_COLS/ROWS constants
- `src/020-board-data.h` - BoardData structure with cols/rows
- `src/032-editor-app.c` - editor_app_load function
- `src/022-grid.h` - Grid structure and DEFAULT_GRID constants

## Related Issues

- 1203a - Loading broken (may be related)

## Notes

The goal is to make boards interchangeable between game and editor with consistent visual results.

## Root Cause Found

The DEFAULT_GRID constants in `022-grid.h` differed from what the editor used:
- **Editor (correct):** 12 cols × 20 rows, 50px cells
- **Game defaults (wrong):** 14 cols × 12 rows, 60px cells

The default board JSON and compile script also used the wrong dimensions.

## Implementation

### Phase 1 (incorrect - reverted)
Initially changed editor to use game's DEFAULT_GRID constants. This was backwards.

### Phase 2 (correct fix)
Updated the source of truth to match the editor's dimensions:

1. Modified `src/022-grid.h`:
   - DEFAULT_GRID_CELL_SIZE: 60.0f → 50.0f
   - DEFAULT_GRID_COLS: 14 → 12
   - DEFAULT_GRID_ROWS: 12 → 20

2. Updated `boards/stage1-default.json`:
   - Grid: 12×20, 50px cells
   - Board size: 600×1000 pixels
   - Regenerated peg layout for 12-column staggered pattern
   - Score zones at row 19

3. Updated `scripts/compile`:
   - Embedded default board JSON matches new dimensions

4. Editor `src/032-editor-app.c`:
   - Still uses DEFAULT_GRID constants (which now have correct values)

## Result

All components now use consistent 12×20 grid with 50px cells.
Boards are hot-swappable between editor and game.

## Status

**Completed** - Unified grid dimensions across editor, game, and default boards.
