# 815 - Standalone Editor Application

## Current Behavior

The board editor is embedded within the game as an overlay panel:

```c
// src/001-main.c
if (IsKeyPressed(KEY_E) && !upgrade_manager->menu_open && !editor_is_overlay_open(editor)) {
    editor_toggle(editor);
}

// In render loop:
if (editor_is_overlay_open(editor)) {
    editor_render_overlay(editor);
}
```

This adds complexity to the main game loop and mixes editor concerns with gameplay concerns.

## Intended Behavior

Create a **standalone editor application** (`bin/board-editor`) that:

1. Launches independently from the game
2. Focuses purely on board creation and editing
3. Reuses existing rendering code for pegs, lines, portals, grids
4. Does NOT include:
   - Ball physics/spawning
   - Score tracking
   - Upgrade system
   - Adversary AI
   - Particle effects
   - Stage management
5. Saves/loads boards to `boards/` directory (same location game uses)

### Benefits

- **Reduced complexity**: Game code stays focused on gameplay
- **Cleaner architecture**: Clear separation of concerns
- **Smaller game binary**: No editor code compiled into game
- **Better UX**: Editor has full screen, not just an overlay
- **Independent development**: Can improve editor without touching game

### Shared Code

The editor will reuse these modules:
- `020-board-data.h/c` - Board data structures and JSON I/O
- `022-grid.h/c` - Grid coordinate system
- `016-ramp.h/c` - Line/ramp rendering (partial)
- `028-portal.h/c` - Portal zone definitions

The editor will NOT use:
- `001-main.c` - Game main loop
- `002-threadpool.h/c` - Parallel physics
- `004-world.h` - Game world state
- `006-ball.h/c` - Ball physics
- `008-particles.h/c` - Particle effects
- `011-upgrades.h/c` - Upgrade system
- `013-adversary.h/c` - AI system
- `014-stage.h/c` - Stage management

## Suggested Implementation Steps

### Step 1: Create editor main file

```c
// src/030-editor-main.c

#include "raylib.h"
#include "020-board-data.h"
#include "022-grid.h"

int main(int argc, char* argv[]) {
    // Initialize window
    InitWindow(1280, 800, "Board Editor");
    SetTargetFPS(60);

    // Create editor state
    EditorApp* app = editor_app_create();

    // Main loop
    while (!WindowShouldClose()) {
        editor_app_update(app);

        BeginDrawing();
        ClearBackground((Color){30, 30, 40, 255});
        editor_app_render(app);
        EndDrawing();
    }

    editor_app_destroy(app);
    CloseWindow();
    return 0;
}
```

### Step 2: Create editor app structure

```c
// src/031-editor-app.h

typedef struct EditorApp {
    // Board being edited
    BoardData* board;
    char filename[256];
    int has_filename;
    int modified;

    // Grid system
    Grid grid;

    // Editor state
    EditorMode mode;           // PLACE or ERASE
    EditorToolType tool_type;  // OBJECT or ZONE
    ObjectType object_type;    // PEG or LINE
    PortalDirection portal_dir;
    int portal_channel;

    // Line tool state
    LineToolData line_tool;

    // UI state
    int hover_col, hover_row;
    int hover_valid;
    int selected_object_index;
    int show_property_panel;
    int show_load_dialog;
    BoardFileList* available_boards;

    // Viewport
    Camera2D camera;
    int screen_width, screen_height;

    // Notifications
    char notification[64];
    float notification_timer;
} EditorApp;

EditorApp* editor_app_create(void);
void editor_app_destroy(EditorApp* app);
void editor_app_update(EditorApp* app);
void editor_app_render(EditorApp* app);
```

### Step 3: Extract rendering functions

Many rendering functions from `025-editor.c` can be reused:
- Grid rendering
- Peg/line/portal rendering
- Cursor preview
- Property panel
- Load dialog

Create `032-editor-render.c` with these functions, parameterized to work with EditorApp instead of EditorState.

### Step 4: Create simplified object rendering

```c
// src/033-object-render.c

// Render a peg at pixel coordinates
void render_peg(float x, float y, float radius, Color color) {
    DrawCircle((int)x, (int)y, radius, color);
    DrawCircleLines((int)x, (int)y, radius, WHITE);
}

// Render a line with rounded endpoints
void render_line(float x1, float y1, float x2, float y2,
                 float thickness, Color color) {
    DrawLineEx((Vector2){x1, y1}, (Vector2){x2, y2}, thickness, color);
    DrawCircle((int)x1, (int)y1, thickness / 2, color);
    DrawCircle((int)x2, (int)y2, thickness / 2, color);
}

// Render a portal zone
void render_portal(float x, float y, float radius,
                   PortalDirection dir, int channel) {
    Color color = (dir == PORTAL_ENTRY)
        ? (Color){50, 100, 255, 200}
        : (Color){255, 150, 50, 200};
    DrawCircle((int)x, (int)y, radius, color);
    DrawCircleLines((int)x, (int)y, radius, WHITE);

    char text[4];
    snprintf(text, sizeof(text), "%d", channel);
    int w = MeasureText(text, 14);
    DrawText(text, (int)(x - w/2), (int)(y - 7), 14, WHITE);
}
```

### Step 5: Update Makefile

```makefile
# Editor executable
EDITOR_SRCS = src/030-editor-main.c \
              src/031-editor-app.c \
              src/032-editor-render.c \
              src/033-object-render.c \
              src/020-board-data.c \
              src/021-board-data.c \
              src/022-grid.c \
              src/023-grid.c

EDITOR_OBJS = $(EDITOR_SRCS:.c=.o)

editor: $(EDITOR_OBJS) $(CJSON_OBJ)
	$(CC) $(EDITOR_OBJS) $(CJSON_OBJ) -o bin/board-editor $(LDFLAGS)

all: game editor
```

### Step 6: Add editor-specific features

With a dedicated editor, we can add features that wouldn't fit in an overlay:
- Larger canvas area
- Zoom in/out (mouse wheel)
- Pan with middle mouse button
- Keyboard shortcuts displayed permanently
- Recent files list
- Undo/redo stack
- Board preview (thumbnail)

## Editor UI Layout

```
+------------------------------------------------------------------+
|  BOARD EDITOR                              [New][Open][Save][Exit]|
+------------------------------------------------------------------+
|  Tools:  [Peg] [Line] [Portal-In] [Portal-Out]    Mode: [PLACE]  |
+------------------------------------------------------------------+
|                                                    | Properties  |
|                                                    |-------------|
|                                                    | R: [====]   |
|              GRID CANVAS                           | G: [====]   |
|              (main editing area)                   | B: [====]   |
|                                                    |             |
|                                                    | Preview:    |
|                                                    |   [color]   |
+------------------------------------------------------------------+
|  boards/my-board.json  *modified*               Pos: (5, 12)     |
+------------------------------------------------------------------+
```

## Files to Create

- `src/030-editor-main.c` - Editor entry point
- `src/031-editor-app.h` - Editor application state
- `src/032-editor-app.c` - Editor application logic
- `src/033-editor-render.c` - Editor rendering functions
- `src/034-object-render.h` - Shared object rendering
- `src/035-object-render.c` - Object rendering implementation

## Files to Modify

- `Makefile` - Add editor build target

## Testing

1. Run `make editor` - should compile standalone editor
2. Run `bin/board-editor` - editor window opens
3. Create board with pegs, lines, portals
4. Save to `boards/test.json`
5. Run game, purchase stage - `test.json` should appear

## Related Issues

- 1202-remove-editor-from-game.md (remove overlay editor)
- 1104-editor-mode-toggle.md (original overlay implementation)
- 1114-editor-overlay-mode.md (overlay redesign)

## Dependencies

Phase 11 must be complete (provides board data, grid, and portal systems).
