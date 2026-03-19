# 1208 - Editor File Browser Delete Button

## Status: COMPLETE

## Current Behavior

The editor's file browser (Load Board dialog) now allows deleting board files:
- Press X or DEL key while a file is selected to initiate deletion
- A confirmation dialog appears asking "Delete this file?"
- Press Y or ENTER to confirm, N or ESC to cancel
- File list automatically refreshes after deletion

## Implementation Details

### Header Changes (`src/031-editor-app.h`)

Added confirmation state to LoadDialogState:
```c
int confirm_delete;      // 1 if confirmation dialog visible
int delete_index;        // Index of file to delete
```

### Input Handling (`src/032-editor-app.c`)

1. Added delete confirmation dialog handling:
   - Y/ENTER confirms deletion
   - N/ESC cancels deletion

2. Added delete key detection:
   - DEL or X key initiates deletion with confirmation

3. File deletion uses `remove()` from stdio.h

4. File list refresh after successful deletion with selection adjustment

### Rendering

Added confirmation dialog overlay showing:
- "Delete this file?" prompt
- Filename being deleted (in red)
- Y/N/ESC instruction

Updated instructions text to include delete keys.

## Files Modified

- `src/031-editor-app.h` - Added confirm_delete and delete_index fields
- `src/032-editor-app.c` - Added delete handling and confirmation UI

## Notes

Deleting stage1-default.json is allowed - the compile script regenerates it
on next build, providing a way to reset to defaults.
