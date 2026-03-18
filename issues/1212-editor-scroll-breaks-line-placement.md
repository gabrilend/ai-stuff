# 1212 - Editor Scroll Breaks Line Placement

## Current Behavior

After scrolling (panning) the editor view, line placement no longer aligns with grid intersections. The line endpoints appear at incorrect positions relative to where the user clicks.

Additionally, scrolling on a blank board causes visual glitches or broken behavior.

## Intended Behavior

Line placement should work correctly regardless of camera/scroll position:
1. Click positions should be converted from screen space to world space
2. Grid snapping should use world coordinates, not screen coordinates
3. Line preview and final placement should match the snapped intersection

Scrolling on a blank board should not cause any issues.

## Likely Cause

The line tool likely converts mouse position to grid coordinates without accounting for the camera offset. When the camera has been panned:
- `GetMousePosition()` returns screen coordinates
- These need to be converted via `GetScreenToWorld2D()` before grid snapping
- If this conversion is missing or incorrect, placements will be offset by the scroll amount

## Files to Investigate

- `src/032-editor-app.c` - Line tool input handling and grid coordinate conversion
- Look for `GetMousePosition()` calls in line tool code
- Check if `GetScreenToWorld2D()` is being used consistently

## Suggested Implementation Steps

1. Find line tool mouse handling in `handle_input()` or related functions
2. Verify mouse position is converted to world space before grid snapping
3. Check `LINE_STATE_IDLE`, `LINE_STATE_END`, and `LINE_STATE_THICKNESS` states
4. Test with camera at various scroll positions
5. Investigate blank board scrolling issue separately

## Related Issues

- 1205 - Editor board height mismatch (grid dimension issues)
- 1203c - Grid intersection snap (intersection-based placement)

## Notes

The property panel (issue 1211) correctly uses `GetScreenToWorld2D()` for object selection - this pattern should be applied to line tool placement as well.
