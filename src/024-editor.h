// src/024-editor.h
// Board editor state and UI for visual level design
// Provides mode toggle, object selection, grid overlay, and placement controls

#ifndef EDITOR_H
#define EDITOR_H

#include "raylib.h"
#include "020-board-data.h"
#include "022-grid.h"

// Forward declarations
struct World;

// =============================================================================
// Palette Constants
// =============================================================================

#define PALETTE_X 10
#define PALETTE_Y 100
#define PALETTE_ITEM_SIZE 50
#define PALETTE_ITEM_SPACING 10

// =============================================================================
// Editor Mode Enumeration
// =============================================================================

// {{{ EditorMode enum
typedef enum EditorMode {
    EDITOR_MODE_DISABLED,  // Normal gameplay, editor hidden
    EDITOR_MODE_PLACE,     // Click to place selected object
    EDITOR_MODE_ERASE      // Click to remove objects
} EditorMode;
// }}}

// =============================================================================
// Editor State Structure
// =============================================================================

// {{{ typedef struct EditorState
// EditorState contains all editor-related state.
// Created once at startup, persists across mode toggles.
typedef struct EditorState {
    EditorMode mode;

    // Currently selected object type for placement
    ObjectType selected_object_type;

    // Grid cell under cursor
    int hover_col;
    int hover_row;
    int hover_valid;  // 1 if cursor is within grid bounds

    // Grid visibility (separate from mode)
    int show_grid;

    // Current board being edited
    BoardData* board_data;

    // Board modification tracking
    int board_modified;  // 1 if board has unsaved changes

    // Grid for coordinate conversion
    Grid grid;

    // Reference to world for live preview
    struct World* world;

    // Screen dimensions for UI anchoring
    int screen_width;
    int screen_height;
} EditorState;
// }}}

// =============================================================================
// Editor Lifecycle
// =============================================================================

// {{{ editor_create
// Creates and initializes editor state.
// Returns NULL on allocation failure.
EditorState* editor_create(struct World* world);
// }}}

// {{{ editor_destroy
// Frees editor state and associated resources.
void editor_destroy(EditorState* editor);
// }}}

// =============================================================================
// Mode Control
// =============================================================================

// {{{ editor_toggle
// Toggles editor mode on/off.
// When enabling: enters PLACE mode by default, shows grid.
// When disabling: hides grid, clears hover state.
void editor_toggle(EditorState* editor);
// }}}

// {{{ editor_is_active
// Returns 1 if editor mode is active (PLACE or ERASE), 0 if disabled.
int editor_is_active(EditorState* editor);
// }}}

// {{{ editor_toggle_submode
// Toggles between PLACE and ERASE modes.
// Only works when editor is active.
void editor_toggle_submode(EditorState* editor);
// }}}

// =============================================================================
// Input Handling
// =============================================================================

// {{{ editor_handle_input
// Processes editor-specific input (object selection, grid toggle).
// Called each frame when editor is active.
// Camera used to convert screen coords to world coords.
void editor_handle_input(EditorState* editor, Camera2D camera);
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ editor_render_grid
// Renders the grid overlay.
// Should be called within BeginMode2D/EndMode2D.
void editor_render_grid(EditorState* editor);
// }}}

// {{{ editor_render_ui
// Renders editor UI elements (mode indicator, palette).
// Should be called after EndMode2D (screen space).
void editor_render_ui(EditorState* editor);
// }}}

// {{{ editor_render_cursor
// Renders cursor preview at hover position.
// Shows selected object at grid position under cursor.
// Should be called within BeginMode2D/EndMode2D.
void editor_render_cursor(EditorState* editor);
// }}}

// =============================================================================
// Grid Setup
// =============================================================================

// {{{ editor_setup_grid
// Configures the editor grid based on world bounds.
// Call after world is initialized or resized.
void editor_setup_grid(EditorState* editor, struct World* world);
// }}}

// {{{ editor_update_screen_size
// Updates editor's cached screen dimensions.
// Call after window resize.
void editor_update_screen_size(EditorState* editor, int width, int height);
// }}}

// =============================================================================
// Placement and Sync
// =============================================================================

// {{{ editor_create_board_data
// Creates a new empty BoardData for editing.
// Initializes grid dimensions from editor's grid settings.
void editor_create_board_data(EditorState* editor);
// }}}

// {{{ editor_handle_placement
// Handles click-to-place when in PLACE mode.
// Adds object to BoardData at hover position.
// Returns 1 if object was placed, 0 otherwise.
int editor_handle_placement(EditorState* editor);
// }}}

// {{{ editor_handle_erase
// Handles click-to-erase when in ERASE mode.
// Removes object at hover position.
// Returns 1 if object was removed, 0 otherwise.
int editor_handle_erase(EditorState* editor);
// }}}

// {{{ editor_sync_to_world
// Syncs BoardData changes to the World for live preview.
// Only syncs if board_modified flag is set.
void editor_sync_to_world(EditorState* editor);
// }}}

// {{{ editor_is_over_ui
// Checks if mouse position is over editor UI (palette, etc.)
// Returns 1 if over UI, 0 otherwise.
int editor_is_over_ui(EditorState* editor);
// }}}

#endif // EDITOR_H
