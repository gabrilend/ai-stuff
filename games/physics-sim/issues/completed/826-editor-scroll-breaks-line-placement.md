# 826 - Editor Scroll Breaks Line Placement

## Current Behavior

After scrolling (panning) the editor view, the line **preview** is displaced from the grid intersections. However, when the line placement is confirmed, it snaps to the correct location.

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

## Root Cause

In `render_canvas()`, the grid origin is temporarily modified by the camera offset:
```c
app->grid.origin_y += app->camera.offset.y;
```

The `line_tool.start_x/y` values were calculated at click time (before this modification)
but the preview was rendered after the modification, causing a mismatch.

## Fix

Modified `render_cursor_preview()` in `src/032-editor-app.c`:

Instead of using stored `line_tool.start_x/y` and `end_x/y` pixel values, recalculate
them from the stored grid coordinates (`start_col/row`, `end_col/row`) at render time.

This ensures the preview always uses the current grid origin, which includes the
scroll offset during rendering.

## Status

**Completed** - Line preview now stays aligned with grid after scrolling.
