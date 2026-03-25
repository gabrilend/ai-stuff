# 817a - Editor Loading Feature Broken

## Current Behavior

File is selected in the load dialog, but the board display doesn't change after loading. The file selection works, but the loaded data doesn't appear in the canvas.

## Intended Behavior

When a board file is selected and confirmed in the load dialog:
1. Board data loads from JSON file
2. Canvas updates to display the loaded objects
3. Grid reconfigures to match loaded board dimensions
4. Notification confirms successful load

## Root Cause Analysis

Likely causes:
1. `editor_app_load()` doesn't refresh the grid after loading
2. Loaded board data isn't being rendered (render loop not seeing new data)
3. Grid coordinates not recalculated after board dimensions change

## Suggested Implementation Steps

1. Add debug output to `editor_app_load()` to verify data loads
2. Check if `setup_grid()` is called after loading
3. Verify `render_board_objects()` receives the loaded board
4. Test with known-good JSON file from `boards/`

## Files to Modify

- `src/032-editor-app.c` - `editor_app_load()` function

## Testing

1. Run editor: `./edit`
2. Press L to open load dialog
3. Select `stage1-default.json`
4. Press Enter to load
5. Verify pegs/objects appear on canvas

## Related Issues

- 1203-editor-improvements.md (parent issue)
- 1201-standalone-editor-application.md (original implementation)
