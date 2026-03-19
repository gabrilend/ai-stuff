# 1308 - Expand Grid Dimensions

## Status: Complete

## Parent Phase: Phase 13

## Problem

Current board size (12 columns x 20 rows) feels cramped. Need to expand to 14 columns x 22 rows to provide more space for level design and gameplay.

## Current Behavior

- Default grid: 12 columns x 20 rows
- Cell size: 50 pixels
- Board dimensions: 600 x 1000 pixels
- Window size: 800 x 1000 pixels (game) / 1400 x 1000 pixels (editor)

## Intended Behavior

- Default grid: 14 columns x 22 rows
- Cell size: 50 pixels (unchanged)
- Board dimensions: 700 x 1100 pixels
- Window size may need adjustment to accommodate taller boards

## Files to Modify

### Core Grid Constants
- `src/022-grid.h` - Update DEFAULT_GRID_COLS (12 → 14) and DEFAULT_GRID_ROWS (20 → 22)

### Board Creation
- `src/021-board-data.c` - Check board_data_create() defaults
- `src/032-editor-app.c` - Check new board creation in editor

### Window Sizing
- `src/001-main.c` - Update WINDOW_HEIGHT if needed (1000 → 1100?)
- `src/030-editor.c` - Update editor window sizing

### Board Compatibility
- Existing boards in `boards/` directory have their own grid_cols/grid_rows stored in JSON
- They should continue to work at their original sizes
- Only affects new boards created after this change

## Implementation Steps

1. Update DEFAULT_GRID_COLS and DEFAULT_GRID_ROWS in grid.h
2. Search for hardcoded 12/20 or 600/1000 values throughout codebase
3. Update window sizing constants if needed
4. Test game window renders correctly with taller board
5. Test editor creates new boards with correct dimensions
6. Test existing boards still load and display correctly
7. Test adversary board flipping works with new dimensions

## Considerations

### Window Height
- Current window: 1000 pixels high
- New board: 1100 pixels high (22 rows x 50 pixels)
- May need WINDOW_HEIGHT = 1100 to avoid cropping
- Consider if UI elements need repositioning

### Adversary Board
- Adversary board is flipped/mirrored version
- Verify flip calculation works with 14x22 dimensions
- Both players see full board without cropping

### Spawn Points
- Default spawn point may need Y adjustment
- Currently SPAWN_Y = 50.0f (near top)
- Should still work but verify

### Zone Positioning
- Score zones at bottom may need row adjustment
- Portal zones position by grid coordinates (should be fine)

## Troubleshooting

### "Board cropped at bottom"
- Window height too small for new board height
- Update WINDOW_HEIGHT constant

### "Existing boards look wrong"
- Check if existing boards have hardcoded dimensions
- They should use their stored grid_cols/grid_rows from JSON

### "Editor panel doesn't fit"
- Editor may need width adjustment
- Currently editor is 1400 wide (800 board + 600 panel)
- With 700 board, editor would be 1300 wide (or adjust panel)

### "Spawn point too low/high"
- SPAWN_Y is absolute pixels, should still work
- But may want to adjust for visual centering

## Notes

- This is a forward-compatible change
- Existing boards retain their dimensions from JSON
- Only new boards use the expanded dimensions
- Consider providing a "resize board" editor feature in future
