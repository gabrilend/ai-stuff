# 808 - Board Save Functionality

## Current Behavior

Board layouts exist only in memory. When the application closes, any changes are lost. The only way to persist a layout is through code.

## Intended Behavior

Save the current board state to a JSON file:

1. Serialize BoardData to JSON format
2. Write to file in `boards/` directory
3. Support both "Save" (overwrite) and "Save As" (new file)
4. Prompt for filename if new board
5. Visual feedback on save success/failure

## Suggested Implementation Steps

### Step 1: Implement JSON serialization

```c
// src/021-board-data.c

#include "cJSON.h"

char* board_data_to_json(BoardData* data) {
    cJSON* root = cJSON_CreateObject();

    // Version
    cJSON_AddNumberToObject(root, "version", 1);

    // Name
    cJSON_AddStringToObject(root, "name", data->name);

    // Grid settings
    cJSON* grid = cJSON_CreateObject();
    cJSON_AddNumberToObject(grid, "cell_size", data->cell_size);
    cJSON_AddNumberToObject(grid, "columns", data->grid_cols);
    cJSON_AddNumberToObject(grid, "rows", data->grid_rows);
    cJSON_AddItemToObject(root, "grid", grid);

    // Board dimensions
    cJSON* board = cJSON_CreateObject();
    cJSON_AddNumberToObject(board, "width", data->board_width);
    cJSON_AddNumberToObject(board, "height", data->board_height);
    cJSON_AddItemToObject(root, "board", board);

    // Objects array
    cJSON* objects = cJSON_CreateArray();
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        cJSON* obj_json = cJSON_CreateObject();

        // Type
        const char* type_str;
        switch (obj->type) {
            case OBJECT_PEG:        type_str = "peg"; break;
            case OBJECT_RAMP_LEFT:  type_str = "ramp"; break;
            case OBJECT_RAMP_RIGHT: type_str = "ramp"; break;
            default:                type_str = "unknown"; break;
        }
        cJSON_AddStringToObject(obj_json, "type", type_str);

        // Position
        cJSON_AddNumberToObject(obj_json, "col", obj->col);
        cJSON_AddNumberToObject(obj_json, "row", obj->row);

        // Type-specific properties
        if (obj->type == OBJECT_PEG) {
            cJSON_AddNumberToObject(obj_json, "radius", obj->radius);
        } else if (obj->type == OBJECT_RAMP_LEFT || obj->type == OBJECT_RAMP_RIGHT) {
            cJSON_AddNumberToObject(obj_json, "width", obj->width);
            cJSON_AddNumberToObject(obj_json, "height", obj->height);
            cJSON_AddStringToObject(obj_json, "direction",
                obj->type == OBJECT_RAMP_LEFT ? "left" : "right");
        }

        cJSON_AddItemToArray(objects, obj_json);
    }
    cJSON_AddItemToObject(root, "objects", objects);

    // Gate rows array
    cJSON* gate_rows = cJSON_CreateArray();
    for (int i = 0; i < data->gate_row_count; i++) {
        BoardGateRow* gate = &data->gate_rows[i];
        cJSON* gate_json = cJSON_CreateObject();

        cJSON_AddNumberToObject(gate_json, "row", gate->row);
        cJSON_AddNumberToObject(gate_json, "zone_count", gate->zone_count);
        cJSON_AddNumberToObject(gate_json, "height", gate->height);
        cJSON_AddNumberToObject(gate_json, "multiplier", gate->multiplier);

        cJSON_AddItemToArray(gate_rows, gate_json);
    }
    cJSON_AddItemToObject(root, "gate_rows", gate_rows);

    // Generate formatted JSON string
    char* json_string = cJSON_Print(root);
    cJSON_Delete(root);

    return json_string;  // Caller must free
}
```

### Step 2: Implement save to file

```c
int board_data_save_json(BoardData* data, const char* filename) {
    char* json_string = board_data_to_json(data);
    if (!json_string) {
        fprintf(stderr, "ERROR: Failed to serialize board data\n");
        return 0;
    }

    FILE* file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "ERROR: Cannot open file for writing: %s\n", filename);
        free(json_string);
        return 0;
    }

    fputs(json_string, file);
    fclose(file);
    free(json_string);

    printf("Board saved to: %s\n", filename);
    return 1;
}
```

### Step 3: Add save state to editor

```c
// src/024-editor.h

typedef struct EditorState {
    // ... existing fields ...

    char current_filename[256];  // Currently loaded/saved file
    int has_filename;            // 1 if file has been saved before
    int board_modified;          // 1 if unsaved changes exist

    // Save dialog state
    int show_save_dialog;
    char save_filename_input[64];
    int save_input_cursor;
} EditorState;
```

### Step 4: Implement save key handling

```c
void editor_handle_save(EditorState* editor) {
    // Ctrl+S to save
    if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_S)) {
        if (editor->has_filename) {
            // Save to existing file
            if (board_data_save_json(editor->board_data, editor->current_filename)) {
                editor->board_modified = 0;
                editor_show_notification(editor, "Saved!", 2.0f);
            } else {
                editor_show_notification(editor, "Save failed!", 2.0f);
            }
        } else {
            // Show save dialog for new file
            editor->show_save_dialog = 1;
            strcpy(editor->save_filename_input, "new-board");
            editor->save_input_cursor = strlen(editor->save_filename_input);
        }
    }

    // Ctrl+Shift+S for Save As
    if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyDown(KEY_LEFT_SHIFT) &&
        IsKeyPressed(KEY_S)) {
        editor->show_save_dialog = 1;
        if (editor->has_filename) {
            // Start with current filename
            strncpy(editor->save_filename_input, editor->current_filename, 63);
        } else {
            strcpy(editor->save_filename_input, "new-board");
        }
    }
}
```

### Step 5: Implement save dialog

```c
void editor_render_save_dialog(EditorState* editor, int screen_width, int screen_height) {
    if (!editor->show_save_dialog) return;

    // Dim background
    DrawRectangle(0, 0, screen_width, screen_height, (Color){0, 0, 0, 150});

    // Dialog box
    int dialog_width = 400;
    int dialog_height = 150;
    int dialog_x = (screen_width - dialog_width) / 2;
    int dialog_y = (screen_height - dialog_height) / 2;

    DrawRectangle(dialog_x, dialog_y, dialog_width, dialog_height,
                  (Color){40, 40, 50, 250});
    DrawRectangleLines(dialog_x, dialog_y, dialog_width, dialog_height,
                       (Color){100, 100, 120, 255});

    // Title
    DrawText("Save Board", dialog_x + 20, dialog_y + 15, 20, WHITE);

    // Input field
    DrawText("Filename:", dialog_x + 20, dialog_y + 50, 14, LIGHTGRAY);

    Rectangle input_rect = {dialog_x + 20, dialog_y + 70, dialog_width - 40, 30};
    DrawRectangleRec(input_rect, (Color){30, 30, 40, 255});
    DrawRectangleLinesEx(input_rect, 1, (Color){80, 80, 100, 255});

    // Input text with cursor
    char display_text[72];
    snprintf(display_text, 72, "%s.json", editor->save_filename_input);
    DrawText(display_text, dialog_x + 25, dialog_y + 77, 14, WHITE);

    // Blinking cursor
    if ((int)(GetTime() * 2) % 2 == 0) {
        int cursor_x = dialog_x + 25 + MeasureText(editor->save_filename_input, 14);
        DrawLine(cursor_x, dialog_y + 75, cursor_x, dialog_y + 93, WHITE);
    }

    // Buttons
    DrawText("Enter: Save    Escape: Cancel", dialog_x + 20, dialog_y + 115, 12, GRAY);
}

void editor_handle_save_dialog_input(EditorState* editor) {
    if (!editor->show_save_dialog) return;

    // Text input
    int key = GetCharPressed();
    while (key > 0) {
        // Only allow valid filename characters
        if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') ||
            (key >= '0' && key <= '9') || key == '-' || key == '_') {
            int len = strlen(editor->save_filename_input);
            if (len < 63) {
                editor->save_filename_input[len] = (char)key;
                editor->save_filename_input[len + 1] = '\0';
            }
        }
        key = GetCharPressed();
    }

    // Backspace
    if (IsKeyPressed(KEY_BACKSPACE)) {
        int len = strlen(editor->save_filename_input);
        if (len > 0) {
            editor->save_filename_input[len - 1] = '\0';
        }
    }

    // Enter to confirm
    if (IsKeyPressed(KEY_ENTER)) {
        char filepath[280];
        snprintf(filepath, 280, "boards/%s.json", editor->save_filename_input);

        if (board_data_save_json(editor->board_data, filepath)) {
            strncpy(editor->current_filename, filepath, 255);
            editor->has_filename = 1;
            editor->board_modified = 0;
            editor->show_save_dialog = 0;
            editor_show_notification(editor, "Saved!", 2.0f);
        } else {
            editor_show_notification(editor, "Save failed!", 2.0f);
        }
    }

    // Escape to cancel
    if (IsKeyPressed(KEY_ESCAPE)) {
        editor->show_save_dialog = 0;
    }
}
```

### Step 6: Add unsaved changes indicator

```c
void editor_render_modified_indicator(EditorState* editor) {
    if (!editor->board_modified) return;

    // Show asterisk in title or status bar
    const char* text = "* Unsaved changes";
    int x = 10;
    int y = 70;  // Below other UI elements

    DrawText(text, x, y, 12, YELLOW);
}
```

### Step 7: Warn on exit with unsaved changes

```c
// In main loop close handling:
if (WindowShouldClose()) {
    if (editor_is_active(editor) && editor->board_modified) {
        // Show confirmation dialog instead of closing
        editor->show_exit_confirmation = 1;
    } else {
        should_close = 1;
    }
}
```

## Controls

| Input | Action |
|-------|--------|
| Ctrl+S | Save (or open Save dialog if new) |
| Ctrl+Shift+S | Save As (always opens dialog) |
| Enter (in dialog) | Confirm save |
| Escape (in dialog) | Cancel save |

## Files to Modify

- `src/021-board-data.c` - Add JSON serialization
- `src/024-editor.h` - Add save state fields
- `src/025-editor.c` - Implement save UI and logic
- `src/001-main.c` - Handle unsaved changes on exit

## Testing

1. Create new board with some objects
2. Press Ctrl+S - should open save dialog
3. Enter filename, press Enter - file created in boards/
4. Modify board, press Ctrl+S - saves without dialog
5. Press Ctrl+Shift+S - opens dialog with current filename
6. Verify saved JSON is valid and readable
7. Exit with unsaved changes - should warn

## Related Issues

- 1101-board-data-format.md (JSON schema)
- 1109-board-load.md (reverse operation)

## Implementation Notes (Completed)

### Changes Made

**src/024-editor.h:**
- Added `current_filename[256]` for tracking saved file path
- Added `has_filename` flag to track if board has been saved
- Added `notification_text[64]` and `notification_timer` for status messages
- Added function declarations: `editor_save_board()`, `editor_show_notification()`, `editor_update_notification()`

**src/025-editor.c:**
- Added `string.h` include for strncpy
- Initialized new fields in `editor_create()`
- Added Ctrl+S key handling in `editor_handle_input()`
- Implemented `editor_save_board()` - saves to current filename or default `boards/editor-board.json`
- Implemented `editor_show_notification()` - displays timed message
- Implemented `editor_update_notification()` - decrements timer each frame
- Added unsaved changes indicator ("* Unsaved changes" in yellow)
- Added notification rendering (centered green box with message)
- Updated help text to show Ctrl+S shortcut

**src/001-main.c:**
- Added `editor_update_notification()` call after `editor_handle_input()`

### Design Decisions

1. **Simple save workflow**: Ctrl+S saves immediately without dialog for speed
2. **Default filename**: New boards save to `boards/editor-board.json`
3. **Notification system**: Temporary messages shown for 2-3 seconds
4. **Unsaved changes indicator**: Yellow text above palette when modified
5. **Uses existing serialization**: Leverages `board_data_save_json()` from Issue 1101

### Testing Verified

- Enter editor mode with E
- Place some pegs and lines
- "* Unsaved changes" appears above palette
- Press Ctrl+S
- Notification shows "Saved: boards/editor-board.json"
- File created with JSON content
- Unsaved indicator disappears after save
- Modify board again - indicator reappears
- Press Ctrl+S again - saves without asking

### Status: Complete
