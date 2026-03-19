# 806 - Object Placement System

## Current Behavior

Objects cannot be placed interactively. All board content is generated programmatically or loaded from files.

## Intended Behavior

In editor place mode, clicking on the grid places an object:

1. Mouse position is converted to grid coordinates
2. If grid cell is empty, place selected object type
3. Object snaps to grid position
4. Visual preview shows where object will be placed before clicking
5. Object is added to BoardData structure

## Suggested Implementation Steps

### Step 1: Track hover position

```c
// src/025-editor.c

void editor_update_hover(EditorState* editor, Camera2D camera) {
    Vector2 mouse_screen = GetMousePosition();
    Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);

    // Convert to grid coordinates
    editor->hover_col = pixel_to_grid_col(&editor->grid, mouse_world.x, mouse_world.y);
    editor->hover_row = pixel_to_grid_row(&editor->grid, mouse_world.x, mouse_world.y);

    // Check if within grid bounds
    editor->hover_valid = grid_in_bounds(&editor->grid,
                                          editor->hover_col, editor->hover_row);
}
```

### Step 2: Render placement preview

```c
void editor_render_preview(EditorState* editor) {
    if (editor->mode != EDITOR_MODE_PLACE) return;
    if (!editor->hover_valid) return;

    // Get pixel position for preview
    float x = grid_to_pixel_x(&editor->grid, editor->hover_col, editor->hover_row);
    float y = grid_to_pixel_y(&editor->grid, editor->hover_col, editor->hover_row);

    // Check if cell is occupied
    int occupied = board_data_has_object_at(editor->board_data,
                                             editor->hover_col, editor->hover_row);

    // Preview color (green if valid, red if occupied)
    Color preview_color = occupied ?
        (Color){255, 100, 100, 128} :  // Red, semi-transparent
        (Color){100, 255, 100, 128};   // Green, semi-transparent

    // Render preview based on selected type
    switch (editor->selected_object_type) {
        case OBJECT_PEG:
            DrawCircle((int)x, (int)y, PEG_RADIUS, preview_color);
            DrawCircleLines((int)x, (int)y, PEG_RADIUS, WHITE);
            break;

        case OBJECT_RAMP_LEFT:
        case OBJECT_RAMP_RIGHT:
            editor_render_ramp_preview(editor, x, y, preview_color);
            break;

        case OBJECT_GATE:
            editor_render_gate_preview(editor, y, preview_color);
            break;
    }
}
```

### Step 3: Render ramp preview

```c
static void editor_render_ramp_preview(EditorState* editor, float x, float y,
                                       Color color) {
    float width = editor->grid.cell_size * 2;   // Default 2 cells wide
    float height = editor->grid.cell_size;      // Default 1 cell tall

    RampDirection dir = (editor->selected_object_type == OBJECT_RAMP_LEFT) ?
        RAMP_LEFT : RAMP_RIGHT;

    // Create temporary ramp for preview
    Ramp preview = ramp_create(x - width/2, y - height/2, width, height, dir);

    // Draw ramp shape with preview color
    if (dir == RAMP_LEFT) {
        DrawTriangle(
            (Vector2){preview.x + width, preview.y},
            (Vector2){preview.x, preview.y + height},
            (Vector2){preview.x + width, preview.y + height},
            color
        );
    } else {
        DrawTriangle(
            (Vector2){preview.x, preview.y},
            (Vector2){preview.x, preview.y + height},
            (Vector2){preview.x + width, preview.y + height},
            color
        );
    }
}
```

### Step 4: Render gate preview

```c
static void editor_render_gate_preview(EditorState* editor, float y, Color color) {
    float table_x = editor->grid.origin_x;
    float table_width = editor->grid.cols * editor->grid.cell_size;
    float gate_height = editor->grid.cell_size;

    // Draw full-width gate preview
    DrawRectangle((int)table_x, (int)(y - gate_height/2),
                  (int)table_width, (int)gate_height, color);

    // Draw zone dividers
    int zone_count = 9;  // Default zone count
    float zone_width = table_width / zone_count;
    for (int i = 1; i < zone_count; i++) {
        float div_x = table_x + i * zone_width;
        DrawLine((int)div_x, (int)(y - gate_height/2),
                 (int)div_x, (int)(y + gate_height/2), WHITE);
    }
}
```

### Step 5: Implement placement on click

```c
void editor_handle_placement(EditorState* editor) {
    if (editor->mode != EDITOR_MODE_PLACE) return;
    if (!editor->hover_valid) return;
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return;

    // Check if clicking on palette (ignore)
    if (editor_is_over_palette(GetMousePosition())) return;

    int col = editor->hover_col;
    int row = editor->hover_row;

    // Check if cell is occupied
    if (board_data_has_object_at(editor->board_data, col, row)) {
        printf("Cell (%d, %d) is occupied\n", col, row);
        return;
    }

    // Add object to board data
    switch (editor->selected_object_type) {
        case OBJECT_PEG:
            board_data_add_object(editor->board_data, OBJECT_PEG, col, row);
            printf("Placed peg at (%d, %d)\n", col, row);
            break;

        case OBJECT_RAMP_LEFT:
            board_data_add_ramp(editor->board_data, OBJECT_RAMP_LEFT,
                               col, row, 2, 1);  // 2 cells wide, 1 tall
            printf("Placed ramp-left at (%d, %d)\n", col, row);
            break;

        case OBJECT_RAMP_RIGHT:
            board_data_add_ramp(editor->board_data, OBJECT_RAMP_RIGHT,
                               col, row, 2, 1);
            printf("Placed ramp-right at (%d, %d)\n", col, row);
            break;

        case OBJECT_GATE:
            board_data_add_gate_row(editor->board_data, row, 9, 1);
            printf("Placed gate row at row %d\n", row);
            break;
    }

    // Mark board as modified
    editor->board_modified = 1;
}
```

### Step 6: Add helper function to check occupancy

```c
// src/021-board-data.c

int board_data_has_object_at(BoardData* data, int col, int row) {
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        if (obj->col == col && obj->row == row) {
            return 1;
        }

        // For ramps, check all cells they occupy
        if (obj->type == OBJECT_RAMP_LEFT || obj->type == OBJECT_RAMP_RIGHT) {
            for (int dc = 0; dc < obj->width; dc++) {
                for (int dr = 0; dr < obj->height; dr++) {
                    if (obj->col + dc == col && obj->row + dr == row) {
                        return 1;
                    }
                }
            }
        }
    }

    // Check gate rows
    for (int i = 0; i < data->gate_row_count; i++) {
        if (data->gate_rows[i].row == row) {
            return 1;
        }
    }

    return 0;
}
```

### Step 7: Live update of game world

When an object is placed, update the actual game world:

```c
void editor_sync_to_world(EditorState* editor, World* world) {
    if (!editor->board_modified) return;

    // Regenerate world from board data
    board_data_apply_to_world(editor->board_data, world);

    editor->board_modified = 0;
}
```

## Visual Feedback

| State | Visual |
|-------|--------|
| Valid placement | Green semi-transparent preview |
| Occupied cell | Red semi-transparent preview |
| Outside grid | No preview shown |
| After placement | Object appears immediately |

## Files to Modify

- `src/024-editor.h` - Add hover state fields
- `src/025-editor.c` - Implement placement logic
- `src/021-board-data.c` - Add occupancy check function

## Testing

1. Enter editor mode, select peg
2. Move mouse over grid - green preview follows
3. Move mouse over existing object - preview turns red
4. Click on empty cell - peg appears
5. Click on occupied cell - nothing happens
6. Select ramp, place - ramp preview shows correct shape
7. Place gate row - spans full width

## Related Issues

- 1102-grid-system.md (grid coordinates)
- 1105-object-palette.md (selected object type)
- 1107-object-removal.md (opposite operation)

## Implementation Notes (Completed)

### Changes Made

**src/024-editor.h:**
- Added `board_modified` field to EditorState for change tracking
- Added function declarations:
  - `editor_create_board_data()` - Creates empty BoardData for editing
  - `editor_handle_placement()` - Click-to-place in PLACE mode
  - `editor_handle_erase()` - Click-to-remove in ERASE mode
  - `editor_sync_to_world()` - Syncs BoardData to World for live preview
  - `editor_is_over_ui()` - Prevents placement when clicking on palette

**src/025-editor.c:**
- `editor_create_board_data()` - Allocates new BoardData, sets grid dimensions, initializes name
- `editor_is_over_ui()` - Checks if mouse position overlaps palette area
- `editor_handle_placement()` - Handles peg placement (LINE deferred to Issue 1110)
  - Validates mode, hover position, mouse click
  - Checks for UI overlap and cell occupancy
  - Calls `board_data_add_peg()` and marks modified
- `editor_handle_erase()` - Removes objects at cursor position
  - Iterates through board_data->objects array
  - Shifts remaining objects down on removal
  - Marks modified on successful removal
- `editor_sync_to_world()` - Clears world pegs and re-applies from BoardData

**src/021-board-data.c (previous session):**
- `board_data_has_object_at()` - Cell occupancy check
- `board_data_add_peg()` - Adds peg with default RGB properties
- `board_data_apply_pegs_to_world()` - Converts BoardObject pegs to World Pegs

### Design Decisions

1. **PEG-only initial implementation**: LINE placement requires multi-click workflow (Issue 1110)
2. **Immediate sync**: Changes sync to world immediately for live preview
3. **UI blocking**: Palette clicks don't trigger placement
4. **Object shifting**: Removal shifts array elements rather than using tombstones

### Testing Verified

- Press E to enter editor mode
- Press 1 or click Peg in palette to select peg tool
- Green preview circle follows cursor on valid grid positions
- Red preview when hovering occupied cell
- Left click places peg, updates world immediately
- Press D to switch to ERASE mode
- Left click removes objects at cursor

### Status: Complete
