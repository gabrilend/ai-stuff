# 1218 - Editor File Picker Vim Keybinds

## Status: Complete

## Current Behavior

The editor file picker supports both arrow key and vim-style navigation:
- `j` or `DOWN` - Move selection down
- `k` or `UP` - Move selection up
- `h` or `ESC` - Cancel/close dialog
- `l` or `ENTER` - Load selected file

The help text at the bottom of the dialog displays all available keybinds.

## Previous Behavior

The editor file picker only supported arrow key navigation for selecting files. Users familiar with vim keybinds could not use their preferred navigation keys.

## Intended Behavior

The file picker should support vim-style navigation keybinds:
- `j` - Move selection down
- `k` - Move selection up
- `h` - Navigate to parent directory (if applicable)
- `l` - Open/select file or enter directory

These should work alongside the existing arrow key navigation.

## Implementation

Modified `src/032-editor-app.c` in the `handle_input` function:

1. Added `KEY_K` alongside `KEY_UP` for moving selection up (line 351)
2. Added `KEY_J` alongside `KEY_DOWN` for moving selection down (line 355)
3. Added `KEY_H` handler to close the dialog (lines 361-364)
4. Added `KEY_L` alongside `KEY_ENTER` for loading files (line 375)
5. Updated help text in `render_load_dialog` to show all keybinds (line 1146)

## Files Modified

- `src/032-editor-app.c` - Added vim keybind support to file picker input handling

## Related Issues

- 1208 - Editor file browser delete button (file picker enhancements)

## Notes

The vim keybinds work alongside existing controls without conflict. The file picker is read-only (no text input), so there's no conflict with typing filenames.
