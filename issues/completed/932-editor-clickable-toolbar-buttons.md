# 1213 - Editor Clickable Toolbar Buttons

## Current Behavior

The toolbar at the top of the editor displays buttons for switching between object types (Peg, Line, Portal Entry, Portal Exit), but they are not clickable. Users must use keyboard shortcuts (1-4) to switch tools.

## Intended Behavior

Clicking on a toolbar button should:
1. Switch to that tool (same as pressing the corresponding number key)
2. Provide visual feedback (highlight/selection indicator)
3. Show which tool is currently selected

## Suggested Implementation Steps

1. Find where toolbar buttons are rendered
2. Add click detection for each button area
3. On click, set `app->tool` to the corresponding tool
4. Ensure visual feedback shows the selected tool

## Files to Modify

- `src/032-editor-app.c` - Toolbar rendering and input handling

## Related Issues

- 1201 - Standalone editor application

## Notes

This improves editor usability by allowing mouse-only interaction for tool selection.

## Implementation

Added `handle_toolbar_click()` function in `src/032-editor-app.c`:

1. Checks for left mouse button press
2. Iterates through button positions (matching render_toolbar layout)
3. If click is within a button's bounds, sets the corresponding tool
4. Returns 1 if click was consumed, 0 otherwise

Called from `handle_input()` before other input processing so toolbar clicks
take priority over canvas interactions.

## Status

**Completed** - Toolbar buttons are now clickable.
