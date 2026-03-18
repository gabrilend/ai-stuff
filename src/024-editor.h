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

// {{{ EditorToolType enum
// Distinguishes between placing objects and zones
typedef enum EditorToolType {
    EDITOR_TOOL_OBJECT,       // Placing objects (pegs, lines)
    EDITOR_TOOL_ZONE_PORTAL   // Placing portal zones
} EditorToolType;
// }}}

// =============================================================================
// Line Tool State Machine
// =============================================================================

// {{{ LineToolState enum
typedef enum LineToolState {
    LINE_TOOL_IDLE,           // Waiting for first click
    LINE_TOOL_PLACING_END,    // First point set, positioning end
    LINE_TOOL_SETTING_WIDTH   // Both points set, adjusting thickness
} LineToolState;
// }}}

// {{{ typedef struct LineToolData
// State data for the multi-click line drawing tool
typedef struct LineToolData {
    LineToolState state;

    // Start point (grid coords)
    int start_col;
    int start_row;

    // End point (grid coords)
    int end_col;
    int end_row;

    // Pixel positions (calculated from grid coords)
    float start_x;
    float start_y;
    float end_x;
    float end_y;

    // Thickness settings
    float thickness;
    float min_thickness;
    float max_thickness;
} LineToolData;
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

    // Line tool state (for multi-click line placement)
    LineToolData line_tool;

    // Save state
    char current_filename[256];  // Currently loaded/saved file path
    int has_filename;            // 1 if file has been saved before

    // Notification message
    char notification_text[64];
    float notification_timer;    // Seconds remaining to show

    // Load dialog state
    int show_load_dialog;           // 1 if load dialog is visible
    BoardFileList* available_boards; // List of board files in boards/
    int load_selected_index;        // Currently selected file index
    int load_scroll_offset;         // Scroll position in file list

    // Portal tool state
    EditorToolType tool_type;       // Object vs zone placement
    PortalDirection portal_direction; // PORTAL_ENTRY or PORTAL_EXIT
    int portal_channel;             // Channel ID for linked portals (1-16)

    // Property editor state
    int selected_object_index;      // Index of selected object (-1 if none)
    int show_property_panel;        // 1 if property panel is visible
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

// =============================================================================
// Save/Load Operations
// =============================================================================

// {{{ editor_save_board
// Saves the current board to file.
// Uses current_filename if set, otherwise saves to default location.
// Returns 1 on success, 0 on failure.
int editor_save_board(EditorState* editor);
// }}}

// {{{ editor_show_notification
// Shows a temporary notification message.
// Duration is in seconds.
void editor_show_notification(EditorState* editor, const char* text, float duration);
// }}}

// {{{ editor_update_notification
// Updates notification timer. Call each frame with delta time.
void editor_update_notification(EditorState* editor, float dt);
// }}}

// {{{ editor_load_board
// Loads a board from a JSON file.
// Replaces current board data and syncs to world.
// Returns 1 on success, 0 on failure.
int editor_load_board(EditorState* editor, const char* filepath);
// }}}

// {{{ editor_open_load_dialog
// Opens the load dialog, scanning for available boards.
void editor_open_load_dialog(EditorState* editor);
// }}}

// {{{ editor_close_load_dialog
// Closes the load dialog and frees the file list.
void editor_close_load_dialog(EditorState* editor);
// }}}

#endif // EDITOR_H
