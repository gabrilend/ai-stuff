# 836 - Editor Scroll and Board Sizing Refactor

## Status: Complete

## Problem

1. Editor scrolling doesn't match game scrolling behavior
2. Board shrinks when window is resized (should maintain fixed size)
3. Editor uses separate grid/rendering code instead of sharing with game

## Current Behavior

- Scrolling uses custom calculation that breaks when canvas > grid
- Board dimensions change dynamically based on window size
- Editor has its own grid setup and rendering separate from game
- Grid cell size recalculated to "fit" canvas on resize

## Intended Behavior

1. **Scrolling** - Match game behavior:
   - Scroll all the way UP → top of board is the lowest visible point
   - Scroll all the way DOWN → bottom of board is the highest visible point
   - Smooth scrolling throughout the board

2. **Board sizing** - Fixed dimensions:
   - Board maintains constant pixel dimensions regardless of window size
   - Cell size stays fixed (e.g., 50px)
   - If window is smaller than board, scrolling reveals hidden areas
   - If window is larger than board, board is centered with margins

3. **Code sharing** - Refactor to use game primitives:
   - Share grid rendering code with game
   - Share coordinate conversion code
   - Share scroll/camera handling where applicable

## Implementation Steps

1. Study game's scroll/camera implementation in main.c
2. Refactor editor to use fixed board dimensions (not canvas-fit)
3. Implement game-style scrolling bounds:
   - min_scroll: board top aligns with canvas bottom
   - max_scroll: board bottom aligns with canvas top
4. Extract shared grid/rendering code if not already shared
5. Test scrolling at various window sizes
6. Test board maintains size on window resize

## Related Issues

- 1212 - Editor scroll breaks line placement (Complete)

## Files Modified

- `src/032-editor-app.c` - Scroll handling, grid setup

## Implementation

1. **Fixed `setup_grid`** - Changed from dynamic cell sizing to fixed:
   - Uses `board->cell_size` instead of calculating to fit canvas
   - Board maintains constant dimensions on window resize
   - Grid centered horizontally, starts at canvas top

2. **Fixed scroll bounds**:
   - `max_scroll = canvas_height - one_row` (board top near canvas bottom)
   - `min_scroll = -grid.height + one_row` (board bottom near canvas top)
   - Allows full board traversal with scroll
