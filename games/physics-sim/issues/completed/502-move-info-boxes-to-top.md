# Issue 702: Move Info Boxes to Top of Screen

## Current Behavior

The score panel (left) and controls panel (right) are anchored to the bottom
of the screen. This obscures the score zones/gates area, which is the most
visually important part of the game - where balls fall into gates and score.

## Intended Behavior

Move both info boxes to the top of the screen:
1. Score panel moves to top-left corner
2. Controls panel moves to top-right corner
3. Bottom of screen is now unobstructed for viewing gates
4. Maintain same panel sizes and styling

## Suggested Implementation Steps

1. Update score panel y-position from `screen_height - 120` to a fixed top position (e.g., 40)
2. Update controls panel y-position similarly
3. Verify panels don't overlap with title bar
4. Test with various window heights to ensure panels stay visible

## Design Notes

Current positions:
- Score panel: (5, screen_height - 120)
- Controls panel: (screen_width - 205, screen_height - 110)

New positions:
- Score panel: (5, 40) - below title
- Controls panel: (screen_width - 205, 40) - below title

## Success Criteria

- Score panel at top-left
- Controls panel at top-right
- Gates/zones area is unobstructed
- Panels don't overlap title text
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Repositioned both UI panels from bottom to top of screen (src/001-main.c:344-382).

Score panel (top-left):
- Old position: (5, screen_height - 120)
- New position: (5, 40) - directly below title bar
- All text elements repositioned with fixed y coordinates

Controls panel (top-right):
- Old position: (screen_width - 205, screen_height - 125)
- New position: (screen_width - 205, 40) - directly below title bar
- All text elements repositioned with fixed y coordinates

Gates/zones area at bottom of screen is now fully unobstructed.
