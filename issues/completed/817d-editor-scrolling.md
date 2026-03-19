# 817d - Editor Scrolling/Panning

## Current Behavior

Canvas is fixed and cannot scroll. Boards larger than the window are not fully visible or editable.

## Intended Behavior

User can scroll up/down to pan the view, similar to the game. This enables editing of larger boards that exceed window height.

## Suggested Implementation Steps

1. Add scroll wheel handling in `handle_input()`
2. Track viewport offset (similar to game's `viewport_offset_y`)
3. Apply Camera2D offset in rendering
4. Update mouse-to-grid conversion to account for scroll offset
5. Clamp scroll to valid range based on grid bounds

## Files to Modify

- `src/032-editor-app.c` - Input handling and rendering
- `src/031-editor-app.h` - Add scroll offset to EditorApp struct

## Testing

1. Run editor: `./edit`
2. Use scroll wheel - canvas should pan up/down
3. Place objects while scrolled - should snap correctly
4. Hover position should update correctly while scrolled

## Related Issues

- 1203-editor-improvements.md (parent issue)
