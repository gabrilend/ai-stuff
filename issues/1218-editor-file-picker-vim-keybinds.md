# 1218 - Editor File Picker Vim Keybinds

## Status: Open

## Current Behavior

The editor file picker only supports arrow key navigation for selecting files. Users familiar with vim keybinds cannot use their preferred navigation keys.

## Intended Behavior

The file picker should support vim-style navigation keybinds:
- `j` - Move selection down
- `k` - Move selection up
- `h` - Navigate to parent directory (if applicable)
- `l` - Open/select file or enter directory

These should work alongside the existing arrow key navigation.

## Suggested Implementation Steps

1. Locate the file picker input handling code in the editor
2. Add key detection for `j`, `k`, `h`, `l` keys
3. Map these keys to the corresponding navigation actions
4. Ensure the keybinds don't conflict with filename input (if applicable)
5. Test navigation with vim keybinds

## Files to Investigate

- `src/032-editor-app.c` - Editor application and input handling
- `src/031-editor-app.h` - Editor state structures

## Related Issues

- 1208 - Editor file browser delete button (file picker enhancements)

## Notes

This is a quality-of-life improvement for users who prefer vim-style navigation. The existing arrow key navigation should continue to work.
