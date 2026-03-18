# 1208 - Editor File Browser Delete Button

## Current Behavior

The editor's file browser allows loading and saving boards, but there is no
way to delete unwanted board files from within the editor. Users must exit
the editor and manually delete files from the filesystem.

## Intended Behavior

The file browser should have a delete button or option that allows users to
remove board files directly from the editor interface. This enables a
complete board management workflow without leaving the application.

## Suggested Implementation Steps

1. Add a delete button/icon next to each file entry in the browser list
2. Show confirmation dialog before deletion ("Delete board-name.json?")
3. On confirm, call filesystem delete and refresh the file list
4. Handle errors gracefully (file in use, permissions, etc.)

## UI Considerations

- Delete button should be visually distinct (red X or trash icon)
- Confirmation dialog prevents accidental deletion
- Consider keyboard shortcut (Del key when file selected)
- Show success/error feedback after operation

## Files to Modify

- `src/032-editor-app.c` - File browser rendering and input handling
- `src/031-editor-app.h` - Add delete confirmation state if needed

## Related Issues

- 1207 - Generate default board on compile (board regenerates if deleted)

## Notes

Deleting stage1-default.json should be allowed - the compile script will
regenerate it on next build. This gives users a way to reset to defaults.
