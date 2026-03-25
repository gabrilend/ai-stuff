# Issue 901: Fix Info Box Positioning on Window Resize

## Current Behavior

When the window is resized, the info boxes (score panel, controls panel) are
not repositioned correctly. The controls panel on the right side stays at its
original position because it uses `screen_width` which is not updated on resize.

The resize handler updates `screen_height` but uses a local `new_screen_width`
variable instead of updating the persistent `screen_width` value.

## Intended Behavior

Info boxes should be anchored to the viewport (screen), not fixed world positions:
1. Score panel (top-left): Should stay at (5, 40) - already correct
2. Controls panel (top-right): Should use current screen width for positioning
3. Both panels should reposition instantly on window resize

## Suggested Implementation Steps

1. Change `screen_width` from `const int` to `int` (mutable)
2. In resize handler, update `screen_width = GetScreenWidth()`
3. UI rendering already uses `screen_width`, so it will auto-correct

Alternative approach:
- Use GetScreenWidth() directly in UI rendering code for dynamic positioning

## Root Cause

In main.c:
```c
const int screen_width = 800;  // Never updated
...
if (IsWindowResized()) {
    screen_height = GetScreenHeight();
    int new_screen_width = GetScreenWidth();  // Local, not persisted
    ...
}
```

The controls panel uses `screen_width - 205` for positioning, but `screen_width`
still equals 800 after resize.

## Success Criteria

- Controls panel repositions correctly on window resize
- Both panels anchored to viewport corners
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Fixed screen_width persistence (src/001-main.c).

Changes:
1. Changed `const int screen_width` to `int screen_width` (line 29)
2. In resize handler, changed `int new_screen_width` to direct assignment
   to `screen_width` (line 218)
3. Updated all references from `new_screen_width` to `screen_width` in
   resize handler (world dims, camera offset/target, printf)

Now UI rendering uses the updated screen_width for controls panel positioning,
so the right panel correctly repositions on window resize.
