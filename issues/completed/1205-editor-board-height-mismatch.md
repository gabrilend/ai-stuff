# 1205 - Editor Board Height Mismatch

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

The editor had its own grid constants that differed from the game:
- **Editor:** EDITOR_GRID_COLS=12, EDITOR_GRID_ROWS=20, EDITOR_CELL_SIZE=50
- **Game:** DEFAULT_GRID_COLS=14, DEFAULT_GRID_ROWS=12, DEFAULT_GRID_CELL_SIZE=60

Boards created in the editor had completely different dimensions than what the game expected.

## Implementation

Modified `src/032-editor-app.c`:

1. Removed local EDITOR_GRID_COLS, EDITOR_GRID_ROWS, EDITOR_CELL_SIZE constants
2. Now uses DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS, DEFAULT_GRID_CELL_SIZE from `022-grid.h`
3. Updated `editor_app_create()` and `editor_app_new_board()` to use shared constants

The editor already includes `022-grid.h` via `031-editor-app.h`, so no new includes were needed.

## Result

Editor now creates boards with the same dimensions as the game (14×12 grid, 60px cells).
Boards are hot-swappable between editor and game.

## Status

**Completed** - Editor uses shared grid dimensions.
