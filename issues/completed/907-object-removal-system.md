# 1107 - Object Removal System

## Current Behavior

Objects cannot be removed interactively. Once placed (programmatically or via editor), objects persist until the application closes.

## Intended Behavior

In editor erase mode, clicking on an object removes it:

1. Mouse position is converted to grid coordinates
2. Find object at that grid cell
3. Remove object from BoardData
4. Update visual immediately
5. Support both single-click removal and click-drag for mass removal

## Suggested Implementation Steps

### Step 1: Add erase mode visual indicator

```c
// src/025-editor.c

void editor_render_erase_cursor(EditorState* editor) {
    if (editor->mode != EDITOR_MODE_ERASE) return;
    if (!editor->hover_valid) return;

    float x = grid_to_pixel_x(&editor->grid, editor->hover_col, editor->hover_row);
    float y = grid_to_pixel_y(&editor->grid, editor->hover_col, editor->hover_row);

    // Check if there's an object to erase
    int has_object = board_data_has_object_at(editor->board_data,
                                               editor->hover_col, editor->hover_row);

    if (has_object) {
        // Draw red X over the object
        float size = editor->grid.cell_size / 3;
        DrawLineEx((Vector2){x - size, y - size}, (Vector2){x + size, y + size},
                   3, RED);
        DrawLineEx((Vector2){x + size, y - size}, (Vector2){x - size, y + size},
                   3, RED);

        // Highlight cell in red
        float cell = editor->grid.cell_size;
        DrawRectangleLines((int)(x - cell/2), (int)(y - cell/2),
                          (int)cell, (int)cell, RED);
    } else {
        // Gray indicator for empty cell
        DrawCircleLines((int)x, (int)y, 5, GRAY);
    }
}
```

### Step 2: Implement single-click removal

```c
void editor_handle_removal(EditorState* editor) {
    if (editor->mode != EDITOR_MODE_ERASE) return;
    if (!editor->hover_valid) return;
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return;

    // Check if clicking on UI elements (ignore)
    if (editor_is_over_palette(GetMousePosition())) return;

    int col = editor->hover_col;
    int row = editor->hover_row;

    // Try to remove object at this position
    int removed = board_data_remove_object(editor->board_data, col, row);

    if (removed) {
        printf("Removed object at (%d, %d)\n", col, row);
        editor->board_modified = 1;
    }
}
```

### Step 3: Implement board_data_remove_object

```c
// src/021-board-data.c

int board_data_remove_object(BoardData* data, int col, int row) {
    // First, try to remove from objects array
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];

        // Check if this object occupies the given cell
        int occupies = 0;

        if (obj->type == OBJECT_PEG) {
            occupies = (obj->col == col && obj->row == row);
        } else if (obj->type == OBJECT_RAMP_LEFT || obj->type == OBJECT_RAMP_RIGHT) {
            // Check all cells the ramp occupies
            for (int dc = 0; dc < obj->width && !occupies; dc++) {
                for (int dr = 0; dr < obj->height && !occupies; dr++) {
                    if (obj->col + dc == col && obj->row + dr == row) {
                        occupies = 1;
                    }
                }
            }
        }

        if (occupies) {
            // Remove by shifting remaining objects
            for (int j = i; j < data->object_count - 1; j++) {
                data->objects[j] = data->objects[j + 1];
            }
            data->object_count--;
            return 1;
        }
    }

    // Try to remove from gate rows
    for (int i = 0; i < data->gate_row_count; i++) {
        if (data->gate_rows[i].row == row) {
            // Remove by shifting
            for (int j = i; j < data->gate_row_count - 1; j++) {
                data->gate_rows[j] = data->gate_rows[j + 1];
            }
            data->gate_row_count--;
            return 1;
        }
    }

    return 0;  // Nothing found to remove
}
```

### Step 4: Implement click-drag mass removal

```c
void editor_handle_drag_removal(EditorState* editor) {
    if (editor->mode != EDITOR_MODE_ERASE) return;
    if (!editor->hover_valid) return;
    if (!IsMouseButtonDown(MOUSE_LEFT_BUTTON)) return;

    // Check if clicking on UI elements
    if (editor_is_over_palette(GetMousePosition())) return;

    // Track last removed position to avoid repeated removals
    static int last_col = -1;
    static int last_row = -1;

    int col = editor->hover_col;
    int row = editor->hover_row;

    // Only remove if we've moved to a new cell
    if (col != last_col || row != last_row) {
        int removed = board_data_remove_object(editor->board_data, col, row);
        if (removed) {
            printf("Drag-removed object at (%d, %d)\n", col, row);
            editor->board_modified = 1;
        }
        last_col = col;
        last_row = row;
    }

    // Reset tracking when mouse released
    if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON)) {
        last_col = -1;
        last_row = -1;
    }
}
```

### Step 5: Add undo support (optional but recommended)

```c
// Simple undo: store last removed object
typedef struct UndoEntry {
    int type;  // 0 = object removed, 1 = object added
    BoardObject object;
    BoardGateRow gate_row;
} UndoEntry;

#define MAX_UNDO_ENTRIES 50

typedef struct UndoStack {
    UndoEntry entries[MAX_UNDO_ENTRIES];
    int count;
    int index;
} UndoStack;

void editor_undo(EditorState* editor) {
    if (editor->undo_stack.index <= 0) return;

    editor->undo_stack.index--;
    UndoEntry* entry = &editor->undo_stack.entries[editor->undo_stack.index];

    if (entry->type == 0) {  // Was removed, restore it
        // Re-add the object
        if (entry->object.type == OBJECT_GATE) {
            board_data_add_gate_row(editor->board_data,
                                    entry->gate_row.row,
                                    entry->gate_row.zone_count,
                                    entry->gate_row.multiplier);
        } else {
            // Copy object back
            data->objects[data->object_count++] = entry->object;
        }
    }

    editor->board_modified = 1;
}
```

### Step 6: Handle keyboard shortcut

```c
void editor_handle_input(EditorState* editor) {
    // ... existing input handling ...

    // Undo (Ctrl+Z)
    if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_Z)) {
        editor_undo(editor);
    }

    // Delete key as alternative to erase mode
    if (IsKeyPressed(KEY_DELETE) || IsKeyPressed(KEY_BACKSPACE)) {
        if (editor->hover_valid) {
            int removed = board_data_remove_object(editor->board_data,
                                                    editor->hover_col,
                                                    editor->hover_row);
            if (removed) {
                editor->board_modified = 1;
            }
        }
    }
}
```

## Visual Feedback

| State | Visual |
|-------|--------|
| Hovering object (erase mode) | Red X over object, red cell border |
| Hovering empty cell (erase mode) | Gray circle indicator |
| After removal | Object disappears immediately |
| Drag removal | Objects removed as cursor passes |

## Controls

| Input | Action |
|-------|--------|
| Left Click | Remove object at cursor |
| Left Drag | Remove objects continuously |
| Delete/Backspace | Remove object at cursor (any mode) |
| Ctrl+Z | Undo last removal |

## Files to Modify

- `src/024-editor.h` - Add undo stack if implementing undo
- `src/025-editor.c` - Implement removal logic and visuals
- `src/021-board-data.c` - Implement board_data_remove_object

## Testing

1. Place several pegs, switch to erase mode
2. Hover over peg - should show red X
3. Click peg - should disappear
4. Hover over empty cell - should show gray indicator
5. Click empty cell - nothing happens
6. Click and drag - objects removed as cursor passes
7. Place ramp, click any cell it occupies - entire ramp removed
8. Test undo restores removed object

## Related Issues

- 1106-object-placement.md (opposite operation)
- 1105-object-palette.md (mode indication)

## Implementation Notes (Completed)

### Changes Made

**src/025-editor.c:**
- Added static tracking variables `last_erase_col` and `last_erase_row` for drag removal
- Updated `editor_handle_erase()` to support both single click and drag removal
  - Tracks last erased position to prevent repeated removal at same cell
  - Uses `IsMouseButtonDown()` for continuous drag detection
  - Resets tracking on mouse release
- Added Delete/Backspace keyboard shortcut in `editor_handle_input()`
  - Works in any editor mode (PLACE or ERASE)
  - Directly calls `board_data_remove_object_at()` and syncs to world
- Updated help text to show DEL shortcut

**src/021-board-data.c (previously implemented):**
- `board_data_remove_object_at()` - Finds and removes object at grid position
  - Handles both PEG and LINE object types
  - Uses array shifting for removal

### Design Decisions

1. **Drag removal tracking**: Uses static variables to track last erased position, preventing repeated removals when cursor stays in same cell during drag
2. **Delete key works in any mode**: Quality-of-life feature - user doesn't need to switch to ERASE mode for quick deletions
3. **Undo not implemented**: Deferred as optional feature - could be added later if needed

### Testing Verified

- Enter editor mode with E
- Place several pegs
- Press TAB to switch to ERASE mode
- Single click removes peg under cursor
- Click and drag continuously removes pegs as cursor passes
- Press Delete or Backspace in PLACE mode removes object under cursor
- All removals sync to world immediately

### Status: Complete
