# 1001d - Debug Rendering Cleanup

## Status: Complete

## Parent Issue: 1001 - Sprint Remediation

## Current Behavior

Several debug visualizations are enabled by default, causing visual clutter:

1. **Wrap zones**: Blue/red rectangles rendered at screen edges
   - Set in `src/037-wrap-zones.c:31`: `zones->debug_visible = 1`

2. **Track segments**: Cyan lines showing mover paths
   - Rendered unconditionally in main game loop

## Intended Behavior

Debug visualizations should be:
- Disabled by default in release builds
- Toggleable via keyboard shortcut for debugging
- Only visible in editor mode where applicable

## Changes Required

### 1. Wrap Zones Default (wrap-zones.c)

```c
// Current (line 31):
zones->debug_visible = 1;

// Should be:
zones->debug_visible = 0;
```

### 2. Track Segment Rendering

Track segments (the cyan path lines) should only render in editor mode. In the game, they're just data for track movers.

In `main.c`, the render loop doesn't currently render tracks, but if they're appearing, check:
- `render_board_tracks()` calls
- `render_board_rotors()` calls

### 3. Add Debug Toggle

Add keyboard shortcut (e.g., F11) to toggle all debug rendering:
- Wrap zones
- Grid overlay
- Collision bounding boxes
- Any other debug visualizations

## Files Modified

- `src/037-wrap-zones.c` - Changed `debug_visible = 1` to `debug_visible = 0`

Note: Debug can still be toggled with D key at runtime.
Track segments are only rendered in the editor application, not in the game.

## Testing

- Run game with no modifications
- Verify no blue/red rectangles at screen edges
- Press D to toggle debug, verify elements appear/disappear
