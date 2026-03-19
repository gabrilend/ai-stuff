# 1211 - Standalone Editor Property Panel

## Current Behavior

The standalone editor (`bin/board-editor`) has no way to edit object
properties. Right-clicking does nothing except cancel line drawing.

The data fields exist in EditorApp (`selected_object_index`,
`show_property_panel`) but the implementation is missing.

## Intended Behavior

Right-click on any peg or line should:
1. Select the object (highlight it)
2. Open a property panel with RGB sliders
3. Allow editing restitution, friction, and point bonus
4. Show live color preview
5. Close panel on ESC or right-click elsewhere

This matches the behavior that existed in the old integrated editor
(`025-editor.c`) before it was modularized in Phase 12.

## Root Cause

When the editor was extracted into a standalone application (issues 1201,
1202), the property panel code from `025-editor.c` was not ported to
`032-editor-app.c`.

## Reference Implementation

The old integrated editor has complete implementations that can be adapted:

- `editor_handle_object_selection()` - Right-click detection, object finding
- `editor_render_property_panel()` - Panel UI with sliders
- `editor_handle_property_panel_input()` - Slider dragging

Located in `src/025-editor.c` starting around line 1663.

## Suggested Implementation Steps

1. Add right-click handler in `editor_app_update()`:
   - Detect MOUSE_RIGHT_BUTTON press
   - Find object at mouse position
   - Set `app->selected_object_index` and `app->show_property_panel`

2. Add property panel rendering in `editor_app_render()`:
   - Draw panel on right side of screen
   - Show RGB sliders for selected object
   - Show color preview swatch
   - Show "ESC to close" hint

3. Add slider interaction in update:
   - Detect mouse drag on slider areas
   - Update object RGB values
   - Mark board as modified

4. Add selection highlight:
   - Draw pulsing ring around selected object in canvas

5. Update help text to show "RClick=Props"

## Files to Modify

- `src/032-editor-app.c` - Add property panel implementation

## Files for Reference

- `src/025-editor.c` - Has working implementation to port

## Related Issues

- 1113 - Object property editor (original implementation)
- 1201 - Standalone editor application
- 1202 - Remove editor from game

## Notes

The BoardData already stores RGB properties correctly. This is purely a UI
feature that needs to be added to the standalone editor.

## Implementation Notes

Implemented in `src/032-editor-app.c`:

1. Added property panel constants at top of file:
   - `PROP_PANEL_WIDTH` (220), `PROP_PANEL_HEIGHT` (200), etc.

2. Added four new functions:
   - `render_slider()` - Draws labeled slider with value display
   - `handle_object_selection()` - Right-click detection using distance calculations
   - `render_property_panel()` - Panel with title, color swatch, and RGB sliders
   - `handle_property_panel_input()` - Slider dragging with mouse position tracking

3. Modified `handle_input()`:
   - ESC closes property panel before quitting
   - Property panel input handled before canvas interactions
   - Right-click selects objects or cancels line tool

4. Modified `editor_app_render()`:
   - Added `render_property_panel()` call

5. Added `#include <math.h>` for `sqrtf()` in distance calculations

The implementation uses `GetScreenToWorld2D()` for proper coordinate conversion
when detecting object clicks on the canvas.

## Status

**Completed** - Property panel fully functional with RGB slider editing.
