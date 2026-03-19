# 1220 - Pegs Not Anchored to Guard Rails

## Status: Complete

## Current Behavior

1. **Pegs move on window resize**: When the window is resized, the guard rails correctly maintain their width and re-center, but pegs/lines stay at their original absolute pixel positions. This makes them appear to "slide" relative to the rails.

2. **Board doesn't fill guard rails**: The table width (800px) is larger than the board width (600px = 12 cols × 50px), leaving 100px gaps on each side. Pegs placed at the far left in the editor don't appear at the left guard rail.

## Intended Behavior

1. Pegs and lines should remain stationary relative to the guard rails when the window resizes.

2. Pegs placed at the far left/right edge of the board in the editor should appear directly at the guard rails in the game.

3. The guard rail width should match the board width from JSON.

## Root Cause

1. **Resize issue**: `world_set_table_bounds()` recalculates `table_x` to center the table, but peg/line positions are stored as absolute pixel coordinates that don't update.

2. **Width mismatch**: `table_width` is hardcoded to 800px, but the JSON board uses 12×50 = 600px. The board is centered within the table, creating gaps.

## Suggested Implementation Steps

1. Calculate `table_width` from the board dimensions instead of hardcoding 800px
2. On window resize, calculate the delta of `table_x` and shift all peg/line positions by that delta
3. Test that pegs stay anchored to guard rails during resize

## Files Modified

- `src/001-main.c` - Initial setup and resize handler

## Implementation

1. **Reordered initialization**: Load the board BEFORE setting table bounds, so table_width can be calculated from board dimensions instead of hardcoded.

2. **Table width from board**: Changed `table_width = 800.0f` to `table_width = initial_board->grid_cols * initial_board->cell_size` (600px for 12×50).

3. **Board fills table**: Removed centering offset - board now starts at `world->table_x` instead of being centered within a larger table.

4. **Resize shift**: On window resize, calculate `dx = new_table_x - old_table_x` and shift all peg/line x-coordinates by that delta.

## Related Issues

- 1216 - JSON board overwritten on resize
- 1205 - Editor board height mismatch
