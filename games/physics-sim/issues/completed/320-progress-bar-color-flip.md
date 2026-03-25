# 320 - Progress Bar Color Flip on Ball Spawn

## Status: Open

## Problem

The progress bar fills up, then immediately empties and restarts, creating a jarring visual. The intended behavior is that the colors flip when a ball spawns, so the "full" state becomes the "empty" state visually.

## Current Behavior

- Progress bar fills from empty to full
- When ball spawns, progress bar instantly resets to empty
- Creates a visual "pop" that feels wrong
- Exception: When reticle is blocked and saving credits, the color flip behavior IS present and works correctly

## Intended Behavior

1. Progress bar fills from empty (background color) to full (progress color)
2. When ball spawns, flip the colors:
   - Previous "progress" color becomes new "background" color
   - Previous "background" color becomes new "progress" color
3. Progress bar then fills again with the swapped colors
4. This creates seamless visual continuity - the bar appears to stay full while starting a new cycle
5. Apply this behavior to BOTH player and adversary progress bars

## Implementation Steps

1. Locate progress bar rendering code
2. Add state to track current color phase (normal vs flipped)
3. On ball spawn, toggle the color phase
4. When rendering, swap foreground/background colors based on phase
5. Test with both player and adversary spawning
6. Verify the "credit saving" mode still works correctly

## Files to Modify

- `src/001-main.c` - Progress bar state and rendering
- `src/013-adversary.c` - Adversary progress bar if separate

## Notes

- The behavior already exists in credit-saving mode, so the rendering logic is partially implemented
- May just need to trigger the color flip on every spawn, not just during credit-saving
- Consider if colors need to animate the transition or can snap instantly
