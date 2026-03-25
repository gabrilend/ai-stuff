# 608 - Adversary Board Flip Axis Correction

## Status: Open

## Problem

The adversary board is currently mirrored over the Y-axis (left-right flip), but it should be mirrored over the X-axis (top-bottom flip) to create the intended "opponent on the other side" effect.

## Current Behavior

- Adversary board is mirrored horizontally (Y-axis reflection)
- Objects that were on the left appear on the right
- Board orientation feels wrong for a versus layout

## Intended Behavior

1. Adversary board should be mirrored over the X-axis (top-bottom flip)
2. Objects at the top of the player's board appear at the bottom of adversary's board
3. This creates a "facing opponent" layout where both players effectively see their boards upright from their perspective

## Implementation Steps

1. Find adversary board loading/rendering code
2. Change coordinate transformation from Y-axis mirror to X-axis mirror
3. For objects: keep X coordinate, invert Y coordinate (row = max_rows - row)
4. Test with asymmetric boards to verify correct flip
5. Verify ball spawning and physics work correctly with flipped board

## Files to Modify

- `src/013-adversary.c` - Board loading and transformation
- `src/001-main.c` - If board setup happens in main

## Notes

- Current: `new_x = board_width - x` (horizontal flip)
- Intended: `new_y = board_height - y` (vertical flip)
- Line endpoints also need to be transformed
- Portal zones may need special handling
