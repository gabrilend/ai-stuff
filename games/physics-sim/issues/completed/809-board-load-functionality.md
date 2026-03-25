# 809 - Board Load Functionality

## Current Behavior

Boards are loaded only at startup via the board loader (1103). There's no way to switch boards during gameplay or in the editor.

## Intended Behavior

Load a board from a JSON file into the editor:

1. Show file selection UI listing available boards
2. Parse selected JSON file into BoardData
3. Replace current editor board with loaded data
4. Update game world to reflect loaded board
5. Handle errors gracefully (corrupted files, missing data)

## Suggested Implementation Steps

### Step 1: Create boards directory scanner

```c
// src/021-board-data.c

#include <dirent.h>

typedef struct BoardFileList {
    char** filenames;
    int count;
    int capacity;
} BoardFileList;

BoardFileList* board_scan_directory(const char* directory) {
    BoardFileList* list = malloc(sizeof(BoardFileList));
    list->count = 0;
    list->capacity = 16;
    list->filenames = malloc(sizeof(char*) * list->capacity);

    DIR* dir = opendir(directory);
    if (!dir) {
        fprintf(stderr, "ERROR: Cannot open directory: %s\n", directory);
        return list;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // Check for .json extension
        const char* name = entry->d_name;
        int len = strlen(name);
        if (len > 5 && strcmp(name + len - 5, ".json") == 0) {
            // Grow array if needed
            if (list->count >= list->capacity) {
                list->capacity *= 2;
                list->filenames = realloc(list->filenames,
                                          sizeof(char*) * list->capacity);
            }

            // Store filename
            list->filenames[list->count] = strdup(name);
            list->count++;
        }
    }

    closedir(dir);
    return list;
}

void board_file_list_destroy(BoardFileList* list) {
    for (int i = 0; i < list->count; i++) {
        free(list->filenames[i]);
    }
    free(list->filenames);
    free(list);
}
```

### Step 2: Add load dialog state to editor

```c
// src/024-editor.h

typedef struct EditorState {
    // ... existing fields ...

    // Load dialog state
    int show_load_dialog;
    BoardFileList* available_boards;
    int load_selected_index;
    int load_scroll_offset;
} EditorState;
```

### Step 3: Implement load dialog rendering

```c
void editor_render_load_dialog(EditorState* editor, int screen_width, int screen_height) {
    if (!editor->show_load_dialog) return;

    // Dim background
    DrawRectangle(0, 0, screen_width, screen_height, (Color){0, 0, 0, 150});

    // Dialog box
    int dialog_width = 400;
    int dialog_height = 350;
    int dialog_x = (screen_width - dialog_width) / 2;
    int dialog_y = (screen_height - dialog_height) / 2;

    DrawRectangle(dialog_x, dialog_y, dialog_width, dialog_height,
                  (Color){40, 40, 50, 250});
    DrawRectangleLines(dialog_x, dialog_y, dialog_width, dialog_height,
                       (Color){100, 100, 120, 255});

    // Title
    DrawText("Load Board", dialog_x + 20, dialog_y + 15, 20, WHITE);

    // File list area
    int list_x = dialog_x + 20;
    int list_y = dialog_y + 50;
    int list_width = dialog_width - 40;
    int list_height = 250;
    int item_height = 25;
    int visible_items = list_height / item_height;

    DrawRectangle(list_x, list_y, list_width, list_height, (Color){30, 30, 40, 255});
    DrawRectangleLines(list_x, list_y, list_width, list_height,
                       (Color){80, 80, 100, 255});

    // Render file list
    if (editor->available_boards && editor->available_boards->count > 0) {
        for (int i = 0; i < visible_items && (i + editor->load_scroll_offset) <
                          editor->available_boards->count; i++) {
            int file_index = i + editor->load_scroll_offset;
            const char* filename = editor->available_boards->filenames[file_index];

            int item_y = list_y + i * item_height;

            // Selection highlight
            if (file_index == editor->load_selected_index) {
                DrawRectangle(list_x + 2, item_y + 2, list_width - 4,
                             item_height - 4, (Color){60, 100, 180, 255});
            }

            // Filename (without .json extension)
            char display_name[64];
            strncpy(display_name, filename, 63);
            int len = strlen(display_name);
            if (len > 5) display_name[len - 5] = '\0';  // Remove .json

            DrawText(display_name, list_x + 10, item_y + 5, 14, WHITE);
        }
    } else {
        DrawText("No boards found", list_x + 10, list_y + 10, 14, GRAY);
    }

    // Scroll indicator if needed
    if (editor->available_boards &&
        editor->available_boards->count > visible_items) {
        float scroll_ratio = (float)editor->load_scroll_offset /
                            (editor->available_boards->count - visible_items);
        int scrollbar_y = list_y + (int)(scroll_ratio * (list_height - 30));
        DrawRectangle(list_x + list_width - 8, scrollbar_y, 6, 30,
                     (Color){100, 100, 120, 255});
    }

    // Controls hint
    DrawText("UP/DOWN: Select  ENTER: Load  ESC: Cancel",
             dialog_x + 20, dialog_y + dialog_height - 30, 12, GRAY);
}
```

### Step 4: Implement load dialog input handling

```c
void editor_handle_load_dialog_input(EditorState* editor) {
    if (!editor->show_load_dialog) return;
    if (!editor->available_boards || editor->available_boards->count == 0) {
        if (IsKeyPressed(KEY_ESCAPE)) {
            editor->show_load_dialog = 0;
        }
        return;
    }

    // Navigation
    if (IsKeyPressed(KEY_UP)) {
        editor->load_selected_index--;
        if (editor->load_selected_index < 0) {
            editor->load_selected_index = editor->available_boards->count - 1;
        }
        // Adjust scroll to keep selection visible
        int visible_items = 10;  // From render function
        if (editor->load_selected_index < editor->load_scroll_offset) {
            editor->load_scroll_offset = editor->load_selected_index;
        }
    }

    if (IsKeyPressed(KEY_DOWN)) {
        editor->load_selected_index++;
        if (editor->load_selected_index >= editor->available_boards->count) {
            editor->load_selected_index = 0;
        }
        // Adjust scroll
        int visible_items = 10;
        if (editor->load_selected_index >= editor->load_scroll_offset + visible_items) {
            editor->load_scroll_offset = editor->load_selected_index - visible_items + 1;
        }
    }

    // Mouse wheel scrolling
    int wheel = GetMouseWheelMove();
    if (wheel != 0) {
        editor->load_scroll_offset -= wheel * 3;
        if (editor->load_scroll_offset < 0) editor->load_scroll_offset = 0;
        int max_offset = editor->available_boards->count - 10;
        if (max_offset < 0) max_offset = 0;
        if (editor->load_scroll_offset > max_offset) {
            editor->load_scroll_offset = max_offset;
        }
    }

    // Load selected
    if (IsKeyPressed(KEY_ENTER)) {
        const char* filename = editor->available_boards->filenames[
            editor->load_selected_index];

        char filepath[280];
        snprintf(filepath, 280, "boards/%s", filename);

        editor_load_board(editor, filepath);
        editor->show_load_dialog = 0;
    }

    // Cancel
    if (IsKeyPressed(KEY_ESCAPE)) {
        editor->show_load_dialog = 0;
    }
}
```

### Step 5: Implement board loading into editor

```c
int editor_load_board(EditorState* editor, const char* filepath) {
    // Warn about unsaved changes
    if (editor->board_modified) {
        // Could show confirmation dialog here
        printf("Warning: Discarding unsaved changes\n");
    }

    // Load board data
    BoardData* new_data = board_data_load_json(filepath);
    if (!new_data) {
        editor_show_notification(editor, "Load failed!", 2.0f);
        return 0;
    }

    // Replace current board
    if (editor->board_data) {
        board_data_destroy(editor->board_data);
    }
    editor->board_data = new_data;

    // Update editor state
    strncpy(editor->current_filename, filepath, 255);
    editor->has_filename = 1;
    editor->board_modified = 0;

    // Reinitialize grid from loaded data
    editor->grid = grid_create(new_data->grid_cols, new_data->grid_rows,
                               new_data->cell_size,
                               editor->grid.origin_x, editor->grid.origin_y);

    editor_show_notification(editor, "Board loaded!", 2.0f);
    printf("Loaded board: %s\n", filepath);

    return 1;
}
```

### Step 6: Implement open load dialog

```c
void editor_open_load_dialog(EditorState* editor) {
    // Scan for available boards
    if (editor->available_boards) {
        board_file_list_destroy(editor->available_boards);
    }
    editor->available_boards = board_scan_directory("boards");

    // Reset selection
    editor->load_selected_index = 0;
    editor->load_scroll_offset = 0;

    // Show dialog
    editor->show_load_dialog = 1;
}
```

### Step 7: Add keyboard shortcut

```c
void editor_handle_input(EditorState* editor) {
    // ... existing input handling ...

    // Ctrl+O to open load dialog
    if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_O)) {
        editor_open_load_dialog(editor);
    }
}
```

### Step 8: Sync loaded board to game world

```c
void editor_apply_to_world(EditorState* editor, World* world) {
    if (!editor->board_data) return;

    // Clear existing world content
    if (world->pegs) {
        free(world->pegs);
        world->pegs = NULL;
        world->peg_count = 0;
    }

    // Apply loaded board data
    board_data_apply_to_world(editor->board_data, world);

    printf("Applied board to world: %d pegs\n", world->peg_count);
}
```

## Controls

| Input | Action |
|-------|--------|
| Ctrl+O | Open load dialog |
| Up/Down | Navigate file list |
| Mouse Wheel | Scroll file list |
| Enter | Load selected board |
| Escape | Cancel load dialog |

## Error Handling

- Invalid JSON: Show "Parse error" notification
- Missing required fields: Use defaults where possible, warn user
- File not found: Show error notification
- Empty boards directory: Show "No boards found" message

## Files to Modify

- `src/021-board-data.c` - Add directory scanning
- `src/024-editor.h` - Add load dialog state
- `src/025-editor.c` - Implement load dialog UI and logic

## Testing

1. Create several board files in boards/ directory
2. Press Ctrl+O - should show load dialog with file list
3. Navigate with Up/Down - selection should move
4. Press Enter - board should load
5. Verify loaded board appears correctly
6. Test with corrupted JSON - should show error
7. Test with empty boards/ directory - should show message

## Related Issues

- 1103-board-loader.md (JSON parsing logic)
- 1108-board-save.md (creates files to load)

## Implementation Notes

### Changes Made

1. **src/021-board-data.c**
   - Added `#define _POSIX_C_SOURCE 200809L` for `strdup()` support
   - Added `<dirent.h>` include
   - Implemented `board_scan_directory()` to scan boards/ for .json files
   - Implemented `board_file_list_destroy()` to free file list memory

2. **src/020-board-data.h**
   - Added `BoardFileList` struct definition
   - Added declarations for `board_scan_directory()` and `board_file_list_destroy()`

3. **src/024-editor.h**
   - Added load dialog state fields to EditorState:
     - `show_load_dialog` - visibility flag
     - `available_boards` - pointer to BoardFileList
     - `load_selected_index` - currently selected file
     - `load_scroll_offset` - scroll position for long lists
   - Added function declarations: `editor_load_board()`, `editor_open_load_dialog()`, `editor_close_load_dialog()`

4. **src/025-editor.c**
   - Added forward declarations for static functions
   - Implemented `editor_open_load_dialog()` - scans directory and shows dialog
   - Implemented `editor_close_load_dialog()` - frees resources
   - Implemented `editor_load_board()` - loads JSON, replaces board data, syncs to world
   - Implemented `editor_handle_load_dialog_input()` - keyboard/mouse navigation
   - Implemented `editor_render_load_dialog()` - draws dialog with file list
   - Added Ctrl+O key binding to open load dialog
   - Updated help text to show Ctrl+O=Load
   - Added early return from input handling when load dialog is open

### Key Implementation Details

- Load dialog renders on top of all other UI elements
- File list shows .json extension stripped from display names
- Up/Down arrows and mouse wheel for navigation
- Enter to load selected file, ESC to cancel
- Loaded board replaces current board data and syncs to world
- Notification shown on success/failure
- `current_filename` and `has_filename` updated after successful load

## Status: Complete
