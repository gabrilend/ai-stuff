# 817e - Editor Filename Prompt on Save

## Current Behavior

Save generates an automatic timestamp filename (e.g., `board-20260318-001234.json`) without user input. User has no control over the filename.

## Intended Behavior

Editor prompts user to enter a filename before saving. Should show a text input dialog where user can type the desired filename.

## Suggested Implementation Steps

1. Create save dialog state in EditorApp (similar to LoadDialogState)
2. Add text input buffer for filename entry
3. Show dialog when S is pressed
4. Handle character input for filename
5. Validate filename (no invalid characters)
6. Call `board_data_save_json()` with user-provided name
7. ESC cancels, Enter confirms

## Files to Modify

- `src/031-editor-app.h` - Add SaveDialogState struct
- `src/032-editor-app.c` - Save dialog logic and rendering

## Testing

1. Run editor: `./edit`
2. Place some objects
3. Press S to save
4. Dialog appears with text input
5. Type filename, press Enter
6. File saves with user-provided name in `boards/`

## Related Issues

- 1203-editor-improvements.md (parent issue)
