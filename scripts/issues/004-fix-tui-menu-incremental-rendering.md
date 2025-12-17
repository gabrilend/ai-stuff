# Issue 004: Fix TUI Menu Incremental Rendering

## Current Behavior

When navigating the menu with UP/DOWN keys, the incremental update renders menu items one row below their intended position. The bug manifests as:

- Item meant for row N appears at row N+1
- This causes visual corruption where items overwrite each other
- Full redraws work correctly; only incremental updates are affected

Debug observations:
- Row calculations in `menu_compute_item_row()` appear correct
- Test scripts (`test-menu-render.sh`, `test-menu-render-v2.sh`) with identical logic work correctly
- The bug is specific to `menu.sh` when sourced into `issue-splitter.sh`
- Writing debug markers to `/dev/tty` positions correctly, but content to stdout appears offset

## Intended Behavior

Incremental updates should:
1. Position cursor at exact row where item was rendered during full render
2. Clear that line and write unhighlighted content
3. Position cursor at new item's row
4. Clear that line and write highlighted content
5. No visual artifacts or off-by-one positioning

## Suggested Implementation Steps

1. [ ] Use frame-by-frame debug logging to capture exact state at each step
2. [ ] Compare full render item row cache vs computed row values
3. [ ] Identify source of off-by-one: calculation, ANSI indexing, or terminal state
4. [ ] Fix the root cause
5. [ ] Remove debug logging (marked deprecated)
6. [ ] Verify with test scripts

## Debug Infrastructure

Frame-by-frame logging added to `libs/menu.sh`:
- Logs stored in: `scripts/debug/menu_frames/`
- `summary.log` - overview of all frames
- `frame_NNNN.txt` - detailed state for each render/update

**IMPORTANT**: Debug logging writes to disk on every navigation. Mark as deprecated and remove once issue is resolved to prevent SSD wear.

## Related Files

- `libs/menu.sh` - Main TUI menu library (contains bug)
- `libs/tui.sh` - Base TUI library
- `test-menu-render.sh` - Simple test (works correctly)
- `test-menu-render-v2.sh` - Complex test with sections (works correctly)
- `issue-splitter.sh` - Script using menu.sh (exhibits bug)

## Notes

- Test scripts work correctly with identical row calculation logic
- Suggests the issue may be environmental or related to how menu.sh integrates with the larger system
- User hypothesis: "the issue is not a matter of technology, but of logic"
