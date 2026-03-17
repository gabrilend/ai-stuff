# Phase 6 Progress

## Phase Goal

Viewport and window management. This phase adds scrolling capability,
dynamic window resizing, and proper viewport handling.

## Issues

| ID  | Description                        | Status   |
|-----|------------------------------------|----------|
| 601 | Add scrolling viewport             | Complete |
| 602 | Dynamic window resize handling     | Complete |
| 603 | Scroll limits to keep table visible| Complete |
| 604 | Fix info box positioning on resize | Complete |

## Progress Summary

**Completed:** 4/4 issues (100%)
**Phase 6:** Complete

## Notes

Phase 6 focuses on viewport and window management. Success is measured by:
- Smooth scrolling through game world
- Window resizes handled gracefully
- UI elements stay properly positioned
- Table remains visible at scroll limits

## Dependencies

Phase 5 must be complete (scoring and polish).

## Implementation Log

### Issue 601 - Scrolling Viewport (Complete)

Implemented scrollable world view using raylib's Camera2D system:
- Camera2D centers view and tracks scroll position
- World elements rendered in camera space (scrollable)
- UI elements rendered outside camera (screen-fixed)
- Mouse wheel controls viewport offset (SCROLL_SPEED = 40 pixels per notch)
- World height expanded to enable scrolling
- All world elements (pegs, balls, zones, particles) scroll automatically

### Issue 602 - Dynamic Window Resize Handling (Complete)

Implemented `IsWindowResized()` handler in main loop:
- Updates world dimensions on resize
- Recalculates table bounds (centers table horizontally)
- Regenerates pegs dynamically based on new height
- Regenerates zones using table bounds
- Updates camera offset and clamps viewport
- Balls preserved during resize, continuing physics with new bounds

### Issue 603 - Scroll Limits to Keep Table Visible (Complete)

Updated scroll clamping to use table-relative bounds:
- min_offset = table_top - screen_height (allows scrolling above table)
- max_offset = table_bottom (allows scrolling to see table bottom)
- Ensures table is always partially visible
- Allows user to see empty space above/below table

### Issue 604 - Fix Info Box Positioning on Resize (Complete)

Fixed bug where controls panel didn't reposition on window resize:
- Root cause: `screen_width` was declared const and never updated
- Fix: Made `screen_width` mutable and update it directly in resize handler
- UI now correctly anchors to viewport corners on resize

## Phase 6 Summary

**PHASE 6 COMPLETE** - Viewport and window management fully functional:

✓ Scrolling viewport with Camera2D
✓ Dynamic window resize handling
✓ Scroll limits keep table visible
✓ UI elements properly repositioned on resize
