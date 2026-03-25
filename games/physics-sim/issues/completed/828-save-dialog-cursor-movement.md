# 828 - Save Dialog Cursor Movement

## Current Behavior

In the save dialog filename input, the cursor is always at the end of the text. Arrow keys do not move the cursor position, making it difficult to edit the middle of a filename.

## Intended Behavior

- Left arrow: Move cursor one position left
- Right arrow: Move cursor one position right
- Cursor position should be visually indicated
- Typing inserts characters at cursor position
- Backspace deletes character before cursor
- Delete key deletes character at cursor position

## Files to Modify

- `src/032-editor-app.c` - `handle_save_dialog_input()` function

## Related Issues

- 1201 - Standalone editor application

## Notes

The `SaveDialogState` already has a `cursor_pos` field that can be used to track position.

## Implementation

Modified `handle_save_dialog_input()` in `src/032-editor-app.c`:

1. Added left/right arrow key handling with key repeat support
2. Added Home/End keys for jumping to start/end
3. Character insertion now shifts text right and inserts at cursor position
4. Backspace deletes character before cursor (not just at end)
5. Delete key removes character at cursor position

Modified `render_save_dialog()`:

1. Cursor position now calculated by measuring text up to cursor_pos
2. Updated instruction text to mention arrow key support

## Status

**Completed** - Full cursor movement and editing in save dialog.
