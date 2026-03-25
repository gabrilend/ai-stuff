# 804 - Editor Mode Toggle

## Current Behavior

The game has a single mode with an optional upgrade menu overlay:

```c
// src/001-main.c
if (IsKeyPressed(KEY_TAB)) {
    manager->menu_open = !manager->menu_open;
}
```

There is no editor mode - all content is fixed at compile time.

## Intended Behavior

Add an editor mode that can be toggled separately from play mode:

1. **E key** toggles editor mode (distinct from TAB for upgrades)
2. In editor mode:
   - Physics simulation pauses
   - Grid overlay becomes visible
   - Object palette appears
   - Click behavior changes to place/remove objects
3. Exiting editor mode resumes physics
4. Clear visual indication of current mode

## Suggested Implementation Steps

### Step 1: Define editor state enum

```c
// src/024-editor.h

typedef enum EditorMode {
    EDITOR_MODE_DISABLED,  // Normal gameplay
    EDITOR_MODE_PLACE,     // Click to place selected object
    EDITOR_MODE_ERASE      // Click to remove objects
} EditorMode;

typedef struct EditorState {
    EditorMode mode;
    int selected_object_type;  // OBJECT_PEG, OBJECT_RAMP_LEFT, etc.
    int hover_col, hover_row;  // Grid cell under cursor
    int show_grid;             // Grid visibility toggle

    // Current board being edited
    BoardData* board_data;
    Grid grid;
} EditorState;
```

### Step 2: Create editor state functions

```c
// Create editor state
EditorState* editor_create(void);

// Destroy editor state
void editor_destroy(EditorState* editor);

// Toggle editor mode
void editor_toggle(EditorState* editor);

// Check if editor is active
int editor_is_active(EditorState* editor);

// Handle editor input
void editor_handle_input(EditorState* editor);

// Render editor UI
void editor_render(EditorState* editor, Camera2D camera);
```

### Step 3: Implement toggle logic

```c
// src/025-editor.c

void editor_toggle(EditorState* editor) {
    if (editor->mode == EDITOR_MODE_DISABLED) {
        // Enter editor mode
        editor->mode = EDITOR_MODE_PLACE;
        editor->show_grid = 1;
        printf("Editor mode enabled\n");
    } else {
        // Exit editor mode
        editor->mode = EDITOR_MODE_DISABLED;
        editor->show_grid = 0;
        printf("Editor mode disabled\n");
    }
}

int editor_is_active(EditorState* editor) {
    return editor->mode != EDITOR_MODE_DISABLED;
}
```

### Step 4: Integrate with main loop

```c
// src/001-main.c

EditorState* editor = editor_create();

// In input handling:
if (IsKeyPressed(KEY_E)) {
    editor_toggle(editor);
}

// In update:
if (!editor_is_active(editor)) {
    // Normal physics update
    ball_manager_update(...);
} else {
    // Editor update (no physics)
    editor_handle_input(editor);
}

// In render:
if (editor_is_active(editor)) {
    editor_render(editor, camera);
}
```

### Step 5: Add mode indicator UI

```c
void editor_render_mode_indicator(EditorState* editor, int screen_width) {
    const char* mode_text;
    Color mode_color;

    switch (editor->mode) {
        case EDITOR_MODE_PLACE:
            mode_text = "EDITOR: PLACE";
            mode_color = GREEN;
            break;
        case EDITOR_MODE_ERASE:
            mode_text = "EDITOR: ERASE";
            mode_color = RED;
            break;
        default:
            return;  // Don't show indicator when disabled
    }

    // Draw at top of screen
    int text_width = MeasureText(mode_text, 20);
    int x = (screen_width - text_width) / 2;
    DrawRectangle(x - 10, 5, text_width + 20, 30, (Color){0, 0, 0, 180});
    DrawText(mode_text, x, 10, 20, mode_color);
}
```

### Step 6: Add sub-mode toggle

```c
void editor_handle_input(EditorState* editor) {
    // Toggle between place and erase modes
    if (IsKeyPressed(KEY_TAB)) {
        if (editor->mode == EDITOR_MODE_PLACE) {
            editor->mode = EDITOR_MODE_ERASE;
        } else if (editor->mode == EDITOR_MODE_ERASE) {
            editor->mode = EDITOR_MODE_PLACE;
        }
    }

    // Number keys to select object type
    if (IsKeyPressed(KEY_ONE)) editor->selected_object_type = OBJECT_PEG;
    if (IsKeyPressed(KEY_TWO)) editor->selected_object_type = OBJECT_RAMP_LEFT;
    if (IsKeyPressed(KEY_THREE)) editor->selected_object_type = OBJECT_RAMP_RIGHT;

    // Track cursor position in grid coordinates
    Vector2 mouse = GetMousePosition();
    // ... convert to grid coords
}
```

### Step 7: Handle conflicts with other systems

Editor mode should block:
- Ball spawning (click is used for placement)
- Upgrade menu (different use of TAB key)
- Physics simulation (paused during editing)

```c
// In main.c spawn logic:
if (!editor_is_active(editor) && mouse_controls_reticle) {
    // Allow spawning
}

// In upgrade menu toggle:
if (!editor_is_active(editor) && IsKeyPressed(KEY_TAB)) {
    // Allow upgrade menu
}
```

## Controls Summary

| Key | Action |
|-----|--------|
| E | Toggle editor mode on/off |
| TAB | (In editor) Toggle place/erase mode |
| 1 | Select peg |
| 2 | Select ramp (left) |
| 3 | Select ramp (right) |
| G | Toggle grid visibility |
| Click | Place or erase object (depending on mode) |

## Files to Create/Modify

- `src/024-editor.h` - Editor state definition
- `src/025-editor.c` - Editor implementation
- `src/001-main.c` - Integrate editor with main loop

## Testing

1. Press E - should enter editor mode, physics stops
2. Press E again - should exit editor mode, physics resumes
3. In editor mode, press TAB - should toggle place/erase indicator
4. Verify upgrade menu doesn't open in editor mode
5. Verify balls don't spawn in editor mode
6. Verify mode indicator displays correctly

## Related Issues

- 1105-object-palette.md (visual object selection)
- 1106-object-placement.md (click to place)
- 1107-object-removal.md (click to remove)
- 1114-editor-overlay-mode.md (redesign to use overlay panel instead of in-place editing)

## Known Issues / Superseded

The in-place editing approach implemented here has usability issues:
- Game objects disappear when editor activates
- No separation between game state and editor state
- Gate zones vanish but gate pegs remain (inconsistent behavior)

**See issue 1114-editor-overlay-mode.md** for the redesigned approach that opens a separate overlay panel for editing, preserving the game state underneath.

## Implementation Notes (Completed)

### Files Created:

1. **`src/024-editor.h`** - Editor state definition
   - `EditorMode` enum (DISABLED, PLACE, ERASE)
   - `EditorState` struct with mode, selection, hover, grid
   - Function declarations for lifecycle, mode control, input, rendering

2. **`src/025-editor.c`** - Editor implementation
   - `editor_create()` / `editor_destroy()` - lifecycle management
   - `editor_toggle()` - toggles between disabled and PLACE mode
   - `editor_is_active()` - checks if editor mode is active
   - `editor_toggle_submode()` - toggles between PLACE and ERASE
   - `editor_handle_input()` - handles E/TAB/G/1/2 keys and cursor tracking
   - `editor_render_grid()` - renders grid overlay with cell highlight
   - `editor_render_ui()` - renders mode indicator, selected object, help text
   - `editor_render_cursor()` - renders cursor preview at hover position
   - `editor_setup_grid()` - configures grid based on world bounds

### Main.c Integration:

1. Editor created after expansion_anim initialization
2. E key toggles editor mode (blocked when upgrade menu open)
3. Editor input handled each frame when active
4. Upgrade menu blocked when editor active
5. Physics skipped when editor active (goto skip_physics)
6. Ball spawning blocked when editor active
7. Editor grid/cursor rendered in world space (within BeginMode2D)
8. Editor UI rendered in screen space (after EndMode2D)
9. Editor destroyed in cleanup section
10. Editor screen size and grid updated on window resize

### Controls Implemented:

| Key | Action |
|-----|--------|
| E | Toggle editor mode on/off |
| TAB | Toggle place/erase mode (in editor) |
| G | Toggle grid visibility (in editor) |
| 1 | Select PEG object |
| 2 | Select LINE object |

### Visual Features:

- Mode indicator at top center (green=PLACE, red=ERASE)
- Selected object indicator below mode
- Help text at bottom
- Grid overlay with major/minor lines
- Cell highlight under cursor
- Cursor preview (peg circle or X mark)
- Grid coordinates displayed near cursor
