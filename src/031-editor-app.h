// src/031-editor-app.h
// Standalone editor application state and API
// Provides full-screen board editing without game dependencies
//
// External functions: editor_app_create, editor_app_destroy, editor_app_update,
//                     editor_app_render, editor_app_resize, editor_app_load,
//                     editor_app_should_quit

#ifndef EDITOR_APP_H
#define EDITOR_APP_H

#include "raylib.h"
#include "020-board-data.h"
#include "022-grid.h"

// =============================================================================
// Editor Mode Enumerations
// =============================================================================

// {{{ EditorAppMode enum
typedef enum EditorAppMode {
    APP_MODE_PLACE,    // Click to place selected object
    APP_MODE_ERASE     // Click to remove objects
} EditorAppMode;
// }}}

// {{{ EditorAppTool enum
typedef enum EditorAppTool {
    APP_TOOL_PEG,          // Place pegs
    APP_TOOL_LINE,         // Draw lines
    APP_TOOL_PORTAL_ENTRY, // Place entry portals
    APP_TOOL_PORTAL_EXIT   // Place exit portals
} EditorAppTool;
// }}}

// {{{ LineToolState enum
typedef enum LineToolState {
    LINE_STATE_IDLE,       // Waiting for first click
    LINE_STATE_END,        // First point set, positioning end
    LINE_STATE_THICKNESS   // Both points set, adjusting thickness
} LineToolState;
// }}}

// =============================================================================
// Line Tool Data
// =============================================================================

// {{{ typedef struct AppLineToolData
typedef struct AppLineToolData {
    LineToolState state;

    // Start point (grid coords)
    int start_col, start_row;

    // End point (grid coords)
    int end_col, end_row;

    // Calculated pixel positions
    float start_x, start_y;
    float end_x, end_y;

    // Thickness
    float thickness;
    float min_thickness;
    float max_thickness;
} AppLineToolData;
// }}}

// =============================================================================
// Load Dialog Data
// =============================================================================

// {{{ typedef struct LoadDialogState
typedef struct LoadDialogState {
    int visible;
    BoardFileList* file_list;
    int selected_index;
    int scroll_offset;
    // Delete confirmation (issue 1208)
    int confirm_delete;      // 1 if confirmation dialog visible
    int delete_index;        // Index of file to delete
} LoadDialogState;
// }}}

// {{{ typedef struct SaveDialogState
typedef struct SaveDialogState {
    int visible;
    char filename[64];
    int cursor_pos;
    int in_progress;  // Checkbox state (issue 1224)
} SaveDialogState;
// }}}

// =============================================================================
// Editor Application Structure
// =============================================================================

// {{{ typedef struct EditorApp
typedef struct EditorApp {
    // Board being edited
    BoardData* board;
    char filename[256];
    int has_filename;
    int modified;

    // Grid system
    Grid grid;

    // Editor state
    EditorAppMode mode;
    EditorAppTool tool;
    int portal_channel;

    // Line tool state
    AppLineToolData line_tool;

    // Hover state
    int hover_col, hover_row;
    int hover_valid;

    // Selection/property editing (issue 1226 - multi-select)
    int* selected_indices;      // Array of selected object indices
    int selection_count;        // Number of selected objects
    int selection_capacity;     // Allocated capacity of selected_indices

    // Drag selection state
    int is_drag_selecting;      // Currently dragging to select
    float drag_start_x, drag_start_y;  // Start position in pixels

    // Legacy single selection (for property panel compatibility)
    int selected_object_index;
    int show_property_panel;

    // Load dialog
    LoadDialogState load_dialog;

    // Save dialog
    SaveDialogState save_dialog;

    // Viewport
    Camera2D camera;
    int screen_width, screen_height;

    // Canvas area (grid drawing region)
    float canvas_x, canvas_y;
    float canvas_width, canvas_height;

    // Notifications
    char notification[80];
    float notification_timer;

    // Quit flag
    int should_quit;
} EditorApp;
// }}}

// =============================================================================
// Lifecycle Functions
// =============================================================================

// {{{ editor_app_create
// Creates a new editor application with empty board.
// Returns NULL on allocation failure.
EditorApp* editor_app_create(int screen_width, int screen_height);
// }}}

// {{{ editor_app_destroy
// Frees editor application and all resources.
void editor_app_destroy(EditorApp* app);
// }}}

// =============================================================================
// Update and Render
// =============================================================================

// {{{ editor_app_update
// Updates editor state, handles input.
// Called each frame before render.
void editor_app_update(EditorApp* app);
// }}}

// {{{ editor_app_render
// Renders editor UI and canvas.
// Called between BeginDrawing/EndDrawing.
void editor_app_render(EditorApp* app);
// }}}

// {{{ editor_app_resize
// Handles window resize, updates canvas bounds.
void editor_app_resize(EditorApp* app, int width, int height);
// }}}

// =============================================================================
// File Operations
// =============================================================================

// {{{ editor_app_load
// Loads a board from file.
// Returns 1 on success, 0 on failure.
int editor_app_load(EditorApp* app, const char* filepath);
// }}}

// {{{ editor_app_save
// Saves the current board to file.
// Uses app->filename if set, otherwise generates name.
// Returns 1 on success, 0 on failure.
int editor_app_save(EditorApp* app);
// }}}

// {{{ editor_app_new_board
// Creates a new empty board, discarding current.
void editor_app_new_board(EditorApp* app);
// }}}

// =============================================================================
// State Queries
// =============================================================================

// {{{ editor_app_should_quit
// Returns 1 if user requested quit, 0 otherwise.
int editor_app_should_quit(EditorApp* app);
// }}}

// =============================================================================
// Notifications
// =============================================================================

// {{{ editor_app_notify
// Shows a temporary notification message.
void editor_app_notify(EditorApp* app, const char* message, float duration);
// }}}

#endif // EDITOR_APP_H
