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
