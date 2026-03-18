# 1114 - Editor Overlay Mode

## Current Behavior

Pressing the E key toggles editor mode, which operates **in-place** on the current game state:

```c
// src/025-editor.c
void editor_toggle(EditorState* editor) {
    if (editor->mode == EDITOR_MODE_DISABLED) {
        // Enter editor mode - operates on current world
        editor->mode = EDITOR_MODE_PLACE;
        editor->show_grid = 1;
    } else {
        editor->mode = EDITOR_MODE_DISABLED;
        editor->show_grid = 0;
    }
}
```

**Problems:**
1. When editor mode activates, game objects disappear (gate zones vanish, but gate pegs remain - inconsistent)
2. The editor modifies the existing board rather than creating a new one
3. Ball state, physics, and game progress are disrupted
4. No separation between "playing the game" and "designing a board"

## Intended Behavior

The editor should be a **separate overlay panel** that opens on top of the game:

1. **E key** opens a new blank editor canvas as an overlay
2. **Game state is preserved** - balls continue, physics pauses but state is saved
3. **Editor canvas is independent** - starts fresh with an empty grid
4. **Save creates a new board file** - saved to `boards/` directory
5. **Closing editor** returns to game with original state intact
6. **New boards become available** via the stage pool system when purchasing stages

### Workflow

```
[Playing Game]
      |
  E key pressed
      |
      v
+---------------------------+
|   EDITOR OVERLAY PANEL    |  <-- Separate canvas, not the game world
|  +---------------------+  |
|  |                     |  |
|  |   Empty Grid        |  |
|  |   (create new board)|  |
|  |                     |  |
|  +---------------------+  |
|  [Save] [Load] [Close]    |
+---------------------------+
      |
  ESC or Close
      |
      v
[Return to Game - unchanged]
```

### Key Principles

1. **Non-destructive**: Opening editor doesn't modify game state
2. **Fresh canvas**: Editor always starts with empty grid (or loaded file)
3. **Explicit save**: Board only persists when user saves
4. **Integration via stage pool**: Saved boards appear in stage purchases

## Suggested Implementation Steps

### Step 1: Add editor overlay state

```c
// src/024-editor.h

typedef struct EditorState {
    // ... existing fields ...

    // Overlay mode state
    int is_overlay_open;           // 1 if overlay panel is visible
    BoardData* edit_board;         // Board being edited (separate from game)

    // Position/size of overlay panel
    float panel_x, panel_y;        // Panel position (centered on screen)
    float panel_width, panel_height;

    // Preview camera for overlay
    Camera2D preview_camera;       // Camera for the edit canvas
} EditorState;
```

### Step 2: Change editor_toggle to open overlay

```c
void editor_toggle(EditorState* editor) {
    if (!editor) return;

    if (!editor->is_overlay_open) {
        // Open editor as overlay
        editor->is_overlay_open = 1;
        editor->mode = EDITOR_MODE_PLACE;
        editor->show_grid = 1;

        // Create fresh board data
        if (editor->edit_board) {
            board_data_destroy(editor->edit_board);
        }
        editor->edit_board = board_data_create_empty();

        printf("Editor overlay opened (new board)\n");
    } else {
        // Close overlay
        editor->is_overlay_open = 0;
        editor->mode = EDITOR_MODE_DISABLED;
        editor->show_grid = 0;

        printf("Editor overlay closed\n");
    }
}
```

### Step 3: Create separate render target or clipped region

The editor panel should render within a bounded region, not affecting the game view:

```c
void editor_render_overlay(EditorState* editor) {
    if (!editor->is_overlay_open) return;

    // Draw semi-transparent background over game
    DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(),
                  (Color){0, 0, 0, 150});

    // Calculate panel bounds (centered, with padding)
    float panel_margin = 50;
    editor->panel_x = panel_margin;
    editor->panel_y = panel_margin;
    editor->panel_width = GetScreenWidth() - panel_margin * 2;
    editor->panel_height = GetScreenHeight() - panel_margin * 2;

    // Draw panel background
    DrawRectangle(editor->panel_x, editor->panel_y,
                  editor->panel_width, editor->panel_height,
                  (Color){40, 40, 50, 255});

    // Draw panel border
    DrawRectangleLines(editor->panel_x, editor->panel_y,
                       editor->panel_width, editor->panel_height,
                       (Color){100, 100, 120, 255});

    // Set up scissor region for clipping
    BeginScissorMode(editor->panel_x, editor->panel_y,
                     editor->panel_width, editor->panel_height);

    // Render grid and objects within panel bounds
    // ... editor grid rendering with panel-relative coordinates

    EndScissorMode();

    // Draw panel title bar
    DrawText("BOARD EDITOR - New Board", editor->panel_x + 10,
             editor->panel_y + 5, 20, WHITE);

    // Draw toolbar buttons
    editor_render_overlay_toolbar(editor);
}
```

### Step 4: Transform mouse coordinates to panel space

```c
Vector2 editor_screen_to_panel(EditorState* editor, Vector2 screen_pos) {
    // Convert screen position to panel-relative coordinates
    return (Vector2){
        screen_pos.x - editor->panel_x,
        screen_pos.y - editor->panel_y - 30  // Account for title bar
    };
}

int editor_is_mouse_in_panel(EditorState* editor) {
    Vector2 mouse = GetMousePosition();
    return mouse.x >= editor->panel_x &&
           mouse.x <= editor->panel_x + editor->panel_width &&
           mouse.y >= editor->panel_y &&
           mouse.y <= editor->panel_y + editor->panel_height;
}
```

### Step 5: Modify main loop to handle overlay

```c
// src/001-main.c

// In input handling:
if (IsKeyPressed(KEY_E) && !upgrade_manager->menu_open) {
    editor_toggle(editor);
}

// Physics should still pause when overlay is open
if (!editor->is_overlay_open) {
    // Normal physics update
    ball_manager_update(...);
}

// In render:
// 1. Render game world normally
world_render(world);
// ... all game rendering ...

// 2. Render editor overlay ON TOP
if (editor->is_overlay_open) {
    editor_render_overlay(editor);
}
```

### Step 6: Add overlay-specific controls

```c
void editor_handle_overlay_input(EditorState* editor, Camera2D game_camera) {
    if (!editor->is_overlay_open) return;

    // ESC closes overlay
    if (IsKeyPressed(KEY_ESCAPE)) {
        editor_toggle(editor);  // Close overlay
        return;
    }

    // Only process input if mouse is in panel
    if (!editor_is_mouse_in_panel(editor)) return;

    Vector2 panel_mouse = editor_screen_to_panel(editor, GetMousePosition());

    // ... existing placement/erase logic using panel_mouse ...
}
```

### Step 7: Toolbar with Save/Load/Close buttons

```c
void editor_render_overlay_toolbar(EditorState* editor) {
    float btn_width = 80;
    float btn_height = 25;
    float btn_y = editor->panel_y + editor->panel_height - btn_height - 10;
    float btn_spacing = 10;

    // Calculate button positions (right-aligned)
    float close_x = editor->panel_x + editor->panel_width - btn_width - 10;
    float save_x = close_x - btn_width - btn_spacing;
    float load_x = save_x - btn_width - btn_spacing;

    // Draw buttons
    if (editor_draw_button(load_x, btn_y, btn_width, btn_height, "Load")) {
        editor_show_load_dialog(editor);
    }
    if (editor_draw_button(save_x, btn_y, btn_width, btn_height, "Save")) {
        editor_save_board(editor, editor->edit_board);
    }
    if (editor_draw_button(close_x, btn_y, btn_width, btn_height, "Close")) {
        editor_toggle(editor);
    }
}
```

### Step 8: Update board_data_create_empty()

```c
// src/021-board-data.c

BoardData* board_data_create_empty(void) {
    BoardData* data = calloc(1, sizeof(BoardData));
    if (!data) return NULL;

    data->board_width = DEFAULT_BOARD_COLS;
    data->board_height = DEFAULT_BOARD_ROWS;
    data->cell_size = DEFAULT_CELL_SIZE;
    data->object_count = 0;
    data->object_capacity = 64;
    data->objects = calloc(data->object_capacity, sizeof(BoardObject));
    data->zone_count = 0;
    data->zone_capacity = 16;
    data->zones = calloc(data->zone_capacity, sizeof(BoardZone));

    return data;
}
```

## Files to Modify

- `src/024-editor.h` - Add overlay state fields
- `src/025-editor.c` - Implement overlay rendering and input
- `src/001-main.c` - Update loop to handle overlay mode
- `src/021-board-data.c` - Add board_data_create_empty() if not exists

## Testing

1. Press E key - overlay panel should appear on top of game
2. Game should remain visible (dimmed) behind overlay
3. Balls and physics should pause but not disappear
4. Click in overlay to place objects
5. Close overlay with ESC - game resumes unchanged
6. Save a board, close overlay, purchase stage - new board should appear

## Related Issues

- 1104-editor-mode-toggle.md (original toggle implementation)
- 1108-board-save-functionality.md (save system)
- 1111-stage-pool-system.md (board selection on purchase)

## Notes

This is a significant workflow change from the original in-place editing. The overlay approach:
- Keeps game and editor states separate
- Prevents accidental data loss
- Provides clearer UX boundaries
- Matches common editor patterns (modal dialogs)

The original in-place editing could be retained as an optional "quick edit" mode for testing, but the primary workflow should be the overlay panel for creating new boards.

## Implementation Notes (Complete)

**Status:** Complete

**Files Modified:**
- `src/024-editor.h` - Added overlay state fields to EditorState:
  - `is_overlay_open` - Flag for overlay visibility
  - `edit_board` - Separate BoardData for overlay editing
  - `panel_x/y/width/height` - Panel bounds
  - `canvas_x/y/width/height` - Grid canvas area
  - `overlay_grid` - Separate grid for overlay
  - `overlay_hover_col/row/valid` - Separate hover state

- `src/025-editor.c` - Added ~700 lines of overlay implementation:
  - `editor_is_overlay_open()` - Query overlay state
  - `editor_render_overlay()` - Render full overlay panel
  - `editor_handle_overlay_input()` - Handle input when overlay open
  - `overlay_calculate_bounds()` - Calculate panel/canvas bounds
  - `overlay_render_grid/objects/cursor/toolbar/footer()` - Render components
  - `overlay_handle_placement/erase/selection()` - Input handlers
  - Modified `editor_toggle()` to open/close overlay

- `src/001-main.c` - Updated main loop:
  - Changed checks from `editor_is_active()` to `editor_is_overlay_open()`
  - Call `editor_handle_overlay_input()` and `editor_render_overlay()`
  - Removed old in-world editor grid/cursor rendering

**Key Features Implemented:**
1. E key opens overlay panel with fresh empty board
2. Game renders behind overlay (dimmed)
3. Physics pauses but game state preserved
4. Full toolbar: New, Load, Save, Close buttons
5. Grid rendering with scissor clipping
6. Object placement (pegs, lines, portals)
7. Erase mode and property editing
8. ESC hierarchy: close panel → close overlay → game
9. Boards save to `boards/` directory for stage pool

**Workflow:**
1. Press E during game - overlay appears
2. Place pegs/lines/portals in grid
3. Right-click objects to edit RGB properties
4. Click Save - board saved to `boards/`
5. Press ESC or Close - return to game
6. Purchase stage - random board from pool appears
