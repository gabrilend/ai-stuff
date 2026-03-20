// src/032-editor-app.c
// Standalone editor application implementation
// Handles editor state, input, and coordinates rendering

#include "031-editor-app.h"
#include "034-object-render.h"
#include "050-material.h"
#include "048-ui-widget.h"
#include "051-ui-panel.h"
#include "000-config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

// =============================================================================
// Constants
// =============================================================================

#define TOOLBAR_HEIGHT 80
#define SIDEBAR_WIDTH 200
#define FOOTER_HEIGHT 30
#define TOOLS_PANEL_WIDTH 150  // Left side tools panel (issue 406)
// Use shared grid dimensions from 022-grid.h for game/editor consistency (issue 1205)
// DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS, DEFAULT_GRID_CELL_SIZE are defined there
#define PEG_RADIUS 12.0f
#define DEFAULT_LINE_THICKNESS 10.0f
#define MIN_LINE_THICKNESS 4.0f
#define MAX_LINE_THICKNESS 30.0f
#define DEFAULT_PORTAL_SIZE 1  // Grid cells (one square)

// Background color presets (issue 413)
// Index matches BACKGROUND_COLOR config value: 0=slate, 1=black, etc.
static const Color BG_COLORS[] = {
    {30, 35, 45, 255},     // 0: slate (default dark gray-blue)
    {0, 0, 0, 255},        // 1: black
    {180, 160, 130, 255},  // 2: tan (light wood)
    {25, 50, 35, 255},     // 3: felt (pool table green)
    {15, 25, 50, 255},     // 4: navy (deep blue)
    {40, 25, 45, 255},     // 5: plum (dark purple)
    {35, 35, 35, 255},     // 6: charcoal (neutral gray)
    {60, 30, 25, 255},     // 7: mahogany (dark red-brown)
};
#define BG_COLOR_COUNT (sizeof(BG_COLORS) / sizeof(BG_COLORS[0]))
#define BG_COLOR (BG_COLORS[BACKGROUND_COLOR < BG_COLOR_COUNT ? BACKGROUND_COLOR : 0])
#define PANEL_COLOR (Color){40, 40, 55, 255}
#define PANEL_BORDER (Color){60, 60, 80, 255}
#define BUTTON_COLOR (Color){60, 70, 90, 255}
#define BUTTON_HOVER (Color){80, 90, 110, 255}
#define BUTTON_ACTIVE (Color){100, 120, 160, 255}
#define TEXT_COLOR (Color){200, 200, 220, 255}
#define TEXT_DIM (Color){120, 120, 140, 255}

// Property panel constants (issue 1211)
#define PROP_PANEL_WIDTH 220
#define PROP_PANEL_HEIGHT 200
#define PROP_PANEL_MARGIN 10
#define PROP_SLIDER_HEIGHT 16

// 10% increment values for RGB properties (issue 1225)
// Maps 0-10 steps to 0-255 range
static const unsigned char INCREMENT_VALUES[11] = {
    0, 26, 51, 77, 102, 128, 153, 179, 204, 230, 255
};

// Point bonus mapping for blue channel (issue 1225)
// Maps 0-10 steps to point values matching gate scoring
static const int POINT_VALUES[11] = {
    0, 10, 20, 50, 100, 500, 500, 500, 500, 500, 500
};

// {{{ snap_to_increment
// Snaps a 0-255 value to nearest 10% increment (issue 1225)
static unsigned char snap_to_increment(unsigned char value) {
    // Find nearest step
    int best_step = 0;
    int best_diff = 255;
    for (int i = 0; i < 11; i++) {
        int diff = abs((int)value - (int)INCREMENT_VALUES[i]);
        if (diff < best_diff) {
            best_diff = diff;
            best_step = i;
        }
    }
    return INCREMENT_VALUES[best_step];
}
// }}}

// {{{ value_to_step
// Converts a 0-255 value to step index (0-10) (issue 1225)
static int value_to_step(unsigned char value) {
    for (int i = 0; i < 11; i++) {
        if (INCREMENT_VALUES[i] >= value) {
            // Check if previous step was closer
            if (i > 0) {
                int diff_curr = (int)INCREMENT_VALUES[i] - (int)value;
                int diff_prev = (int)value - (int)INCREMENT_VALUES[i-1];
                if (diff_prev < diff_curr) return i - 1;
            }
            return i;
        }
    }
    return 10;
}
// }}}

// =============================================================================
// Multi-Selection Helpers (issue 1226)
// =============================================================================

// {{{ selection_clear
// Clears all selected objects
static void selection_clear(EditorApp* app) {
    app->selection_count = 0;
    app->selected_object_index = -1;
    app->show_property_panel = 0;
}
// }}}

// {{{ selection_contains
// Returns 1 if object index is in selection, 0 otherwise
static int selection_contains(EditorApp* app, int index) {
    for (int i = 0; i < app->selection_count; i++) {
        if (app->selected_indices[i] == index) return 1;
    }
    return 0;
}
// }}}

// {{{ selection_add
// Adds an object to selection (if not already selected)
static void selection_add(EditorApp* app, int index) {
    if (selection_contains(app, index)) return;

    // Grow array if needed
    if (app->selection_count >= app->selection_capacity) {
        app->selection_capacity *= 2;
        app->selected_indices = realloc(app->selected_indices,
                                        app->selection_capacity * sizeof(int));
    }

    app->selected_indices[app->selection_count++] = index;

    // Update legacy single selection for property panel compatibility
    if (app->selection_count == 1) {
        app->selected_object_index = index;
    } else {
        app->selected_object_index = -1;  // Multiple selected
    }
    app->show_property_panel = 1;
}
// }}}

// {{{ selection_remove
// Removes an object from selection
static void selection_remove(EditorApp* app, int index) {
    for (int i = 0; i < app->selection_count; i++) {
        if (app->selected_indices[i] == index) {
            // Shift remaining elements
            for (int j = i; j < app->selection_count - 1; j++) {
                app->selected_indices[j] = app->selected_indices[j + 1];
            }
            app->selection_count--;

            // Update legacy single selection
            if (app->selection_count == 1) {
                app->selected_object_index = app->selected_indices[0];
            } else if (app->selection_count == 0) {
                app->selected_object_index = -1;
                app->show_property_panel = 0;
            } else {
                app->selected_object_index = -1;
            }
            return;
        }
    }
}
// }}}

// {{{ selection_toggle
// Toggles object in/out of selection
static void selection_toggle(EditorApp* app, int index) {
    if (selection_contains(app, index)) {
        selection_remove(app, index);
    } else {
        selection_add(app, index);
    }
}
// }}}

// {{{ selection_set_single
// Sets selection to single object (clears existing, adds one)
static void selection_set_single(EditorApp* app, int index) {
    selection_clear(app);
    if (index >= 0) {
        selection_add(app, index);
    }
}
// }}}

// {{{ selection_select_all
// Selects all objects
static void selection_select_all(EditorApp* app) {
    selection_clear(app);
    for (int i = 0; i < app->board->object_count; i++) {
        selection_add(app, i);
    }
}
// }}}

// {{{ selection_select_in_rect
// Selects all objects within a screen-space rectangle (issue 1226)
// If shift is held, adds to existing selection; otherwise replaces
static void selection_select_in_rect(EditorApp* app, float x1, float y1, float x2, float y2) {
    if (!app || !app->board) return;

    int shift_held = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
    if (!shift_held) {
        selection_clear(app);
    }

    // Normalize rectangle bounds
    float min_x = (x1 < x2) ? x1 : x2;
    float max_x = (x1 > x2) ? x1 : x2;
    float min_y = (y1 < y2) ? y1 : y2;
    float max_y = (y1 > y2) ? y1 : y2;

    // Convert screen bounds to world coordinates
    Vector2 world_min = GetScreenToWorld2D((Vector2){min_x, min_y}, app->camera);
    Vector2 world_max = GetScreenToWorld2D((Vector2){max_x, max_y}, app->camera);

    // Check each object
    for (int i = 0; i < app->board->object_count; i++) {
        BoardObject* obj = &app->board->objects[i];

        float obj_x = grid_to_pixel_x(&app->grid, obj->col, obj->row);
        float obj_y = grid_to_pixel_y(&app->grid, obj->col, obj->row);

        // Check if object center is within rectangle
        if (obj_x >= world_min.x && obj_x <= world_max.x &&
            obj_y >= world_min.y && obj_y <= world_max.y) {
            selection_add(app, i);
        }
    }
}
// }}}

// =============================================================================
// Forward Declarations
// =============================================================================

static void handle_input(EditorApp* app);
static void handle_canvas_click(EditorApp* app);
static void handle_tool_selection(EditorApp* app);
static int handle_toolbar_click(EditorApp* app);
static void handle_line_tool(EditorApp* app);
static void handle_track_tool(EditorApp* app);  // Issue 902b
static void update_hover(EditorApp* app);
static void render_toolbar(EditorApp* app);
static void render_sidebar(EditorApp* app);
static void render_footer(EditorApp* app);
static void render_canvas(EditorApp* app);
static void render_cursor_preview(EditorApp* app);
static void render_load_dialog(EditorApp* app);
static void render_save_dialog(EditorApp* app);
static void render_notification(EditorApp* app);
static void place_object(EditorApp* app);
static void erase_object(EditorApp* app);
static void open_load_dialog(EditorApp* app);
static void close_load_dialog(EditorApp* app);
static void open_save_dialog(EditorApp* app);
static void close_save_dialog(EditorApp* app);
static void handle_save_dialog_input(EditorApp* app);
static void setup_grid(EditorApp* app);
// Grid settings functions (issue 840)
static void change_grid_dimensions(EditorApp* app, int new_cols, int new_rows);
static int handle_grid_settings_input(EditorApp* app);
// Property panel functions (issue 1211)
static int handle_object_selection(EditorApp* app, float mouse_x, float mouse_y);
static void render_property_panel(EditorApp* app);
static int handle_property_panel_input(EditorApp* app);
// Polygon panel functions (issue 837)
static void render_polygon_panel(EditorApp* app);
// Rotor panel functions (issue 901g)
static void render_rotor_panel(EditorApp* app);
static int handle_rotor_panel_input(EditorApp* app);
static void render_slider(int x, int y, int width, unsigned char value,
                          const char* label, Color color_hint, int is_points);
// Material selector functions (issue 839)
static void render_material_selector(EditorApp* app, int x, int y, int width);
static int handle_material_selector_input(EditorApp* app, int panel_x, int panel_y);
// Multi-selection functions (issue 1226)
static void render_selection_highlights(EditorApp* app);
static void render_drag_selection_rect(EditorApp* app);

// =============================================================================
// Lifecycle
// =============================================================================

// {{{ editor_app_create
EditorApp* editor_app_create(int screen_width, int screen_height) {
    EditorApp* app = (EditorApp*)calloc(1, sizeof(EditorApp));
    if (!app) return NULL;

    app->screen_width = screen_width;
    app->screen_height = screen_height;

    // Create empty board using shared grid dimensions (issue 1205)
    app->board = board_data_create(DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS, (int)DEFAULT_GRID_CELL_SIZE);
    if (!app->board) {
        free(app);
        return NULL;
    }

    // Initialize state
    app->mode = APP_MODE_PLACE;
    app->tool = APP_TOOL_PEG;
    app->portal_channel = 1;
    app->selected_object_index = -1;

    // Line tool defaults
    app->line_tool.state = LINE_STATE_IDLE;
    app->line_tool.thickness = DEFAULT_LINE_THICKNESS;
    app->line_tool.min_thickness = MIN_LINE_THICKNESS;
    app->line_tool.max_thickness = MAX_LINE_THICKNESS;

    // Track tool defaults (issue 902b)
    app->track_tool.state = TRACK_STATE_IDLE;

    // Multi-selection array (issue 1226)
    app->selection_capacity = 64;  // Initial capacity
    app->selected_indices = (int*)malloc(app->selection_capacity * sizeof(int));
    if (!app->selected_indices) {
        board_data_destroy(app->board);
        free(app);
        return NULL;
    }
    app->selection_count = 0;
    app->is_drag_selecting = 0;

    // Setup camera (1:1, no zoom initially)
    app->camera.zoom = 1.0f;
    app->camera.rotation = 0.0f;
    app->camera.offset = (Vector2){0, 0};
    app->camera.target = (Vector2){0, 0};

    // Calculate canvas bounds and setup grid
    editor_app_resize(app, screen_width, screen_height);

    // Create polygon manager for closed shape detection (issue 837)
    app->polygon_manager = polygon_manager_create(
        (float)app->board->board_width,
        (float)app->board->board_height
    );
    app->polygons_dirty = 1;  // Rebuild on first update
    app->selected_polygon_index = -1;  // No polygon selected
    app->show_polygon_panel = 0;

    // Initialize rotor selection (issue 901g)
    app->selected_rotor_index = -1;
    app->show_rotor_panel = 0;

    // Create tools panel (issue 406)
    // Panel positioned on left side below toolbar
    Rectangle tools_bounds = {
        0, TOOLBAR_HEIGHT,
        TOOLS_PANEL_WIDTH, screen_height - TOOLBAR_HEIGHT - FOOTER_HEIGHT
    };
    app->tools_panel = panel_create("Tools", tools_bounds);
    if (app->tools_panel) {
        // Add tool buttons to panel (issue 901b: added rotor)
        // Button callbacks are set to NULL - we handle input via tool state
        panel_add_widget(app->tools_panel, widget_label("Placement"));
        panel_add_widget(app->tools_panel, widget_separator());
        panel_add_widget(app->tools_panel, widget_button("1: Peg", NULL, NULL));
        panel_add_widget(app->tools_panel, widget_button("2: Line", NULL, NULL));
        panel_add_widget(app->tools_panel, widget_button("3: Portal In", NULL, NULL));
        panel_add_widget(app->tools_panel, widget_button("4: Portal Out", NULL, NULL));
        panel_add_widget(app->tools_panel, widget_button("5: Rotor", NULL, NULL));
        panel_add_widget(app->tools_panel, widget_separator());
        panel_add_widget(app->tools_panel, widget_label("Mode"));
        panel_add_widget(app->tools_panel, widget_separator());
        panel_add_widget(app->tools_panel, widget_button("TAB: Toggle", NULL, NULL));
    }

    // Initialize drawer layout system (issue 409)
    // Passes tools_panel as tools drawer, NULL for inspector (not yet implemented)
    drawer_layout_init(&app->drawer_layout, app->tools_panel, NULL);

    return app;
}
// }}}

// {{{ editor_app_destroy
void editor_app_destroy(EditorApp* app) {
    if (!app) return;

    if (app->board) {
        board_data_destroy(app->board);
    }

    if (app->load_dialog.file_list) {
        board_file_list_destroy(app->load_dialog.file_list);
    }

    // Free multi-selection array (issue 1226)
    if (app->selected_indices) {
        free(app->selected_indices);
    }

    // Free polygon manager (issue 837)
    if (app->polygon_manager) {
        polygon_manager_destroy(app->polygon_manager);
    }

    // Free tools panel (issue 406)
    if (app->tools_panel) {
        panel_destroy(app->tools_panel);
    }

    free(app);
}
// }}}

// =============================================================================
// Update and Render
// =============================================================================

// {{{ editor_app_update
void editor_app_update(EditorApp* app) {
    if (!app) return;

    float dt = GetFrameTime();

    // Update notification timer
    if (app->notification_timer > 0) {
        app->notification_timer -= dt;
    }

    // Update drawer layout system (issue 409)
    // Must be called before handle_input so drawer can intercept input
    drawer_layout_update(&app->drawer_layout, app->screen_width, app->screen_height, dt);

    // Handle drawer input first - if consumed, skip main input handling
    if (drawer_layout_handle_input(&app->drawer_layout, app->screen_width, app->screen_height)) {
        return;  // Input was consumed by drawer system
    }

    // Handle input
    handle_input(app);

    // Update hover position
    update_hover(app);

    // Rebuild polygon detection if lines changed (issue 837)
    if (app->polygons_dirty && app->polygon_manager) {
        polygon_manager_rebuild(app->polygon_manager, app->board,
                                app->board->cell_size);
        app->polygons_dirty = 0;
    }
}
// }}}

// {{{ editor_app_render
void editor_app_render(EditorApp* app) {
    if (!app) return;

    // Render canvas (grid and objects)
    render_canvas(app);

    // Render UI panels
    render_toolbar(app);
    render_sidebar(app);
    render_footer(app);

    // Render tools panel (issue 406)
    if (app->tools_panel) {
        panel_render(app->tools_panel);
    }

    // Render property panel if object selected (issue 1211)
    render_property_panel(app);

    // Render polygon panel if polygon selected (issue 837)
    render_polygon_panel(app);

    // Render rotor panel if rotor selected (issue 901g)
    render_rotor_panel(app);

    // Render drawer overlays and toolbar (issue 409)
    // Must be after main content but before dialogs
    drawer_layout_render(&app->drawer_layout, app->screen_width, app->screen_height);

    // Render load dialog if open
    if (app->load_dialog.visible) {
        render_load_dialog(app);
    }

    // Render save dialog if open
    if (app->save_dialog.visible) {
        render_save_dialog(app);
    }

    // Render notification
    render_notification(app);
}
// }}}

// {{{ editor_app_resize
void editor_app_resize(EditorApp* app, int width, int height) {
    if (!app) return;

    app->screen_width = width;
    app->screen_height = height;

    // Determine layout mode for responsive canvas sizing (issue 409)
    LayoutMode layout_mode = get_layout_mode(width, height);

    // Calculate canvas area based on layout mode
    if (layout_mode == LAYOUT_FULL) {
        // Full mode: permanent side panels visible
        // Canvas between tools panel, sidebar, toolbar, footer
        app->canvas_x = TOOLS_PANEL_WIDTH;
        app->canvas_y = TOOLBAR_HEIGHT;
        app->canvas_width = width - SIDEBAR_WIDTH - TOOLS_PANEL_WIDTH;
        app->canvas_height = height - TOOLBAR_HEIGHT - FOOTER_HEIGHT;

        // Update tools panel bounds (issue 406)
        if (app->tools_panel) {
            Rectangle tools_bounds = {
                0, TOOLBAR_HEIGHT,
                TOOLS_PANEL_WIDTH, height - TOOLBAR_HEIGHT - FOOTER_HEIGHT
            };
            panel_set_bounds(app->tools_panel, tools_bounds);
        }
    } else {
        // Collapsed mode: panels hidden, drawers overlay canvas
        // Canvas spans full width, footer replaced by drawer toolbar
        app->canvas_x = 0;
        app->canvas_y = TOOLBAR_HEIGHT;
        app->canvas_width = width - SIDEBAR_WIDTH;
        app->canvas_height = height - TOOLBAR_HEIGHT - (int)DRAWER_TOOLBAR_HEIGHT;
    }

    // Setup grid to fit canvas
    setup_grid(app);
}
// }}}

// =============================================================================
// File Operations
// =============================================================================

// {{{ editor_app_load
int editor_app_load(EditorApp* app, const char* filepath) {
    if (!app || !filepath) return 0;

    BoardData* new_board = board_data_load_json(filepath);
    if (!new_board) return 0;

    // Replace current board
    if (app->board) {
        board_data_destroy(app->board);
    }
    app->board = new_board;

    // Update filename
    strncpy(app->filename, filepath, sizeof(app->filename) - 1);
    app->has_filename = 1;
    app->modified = 0;

    // Reconfigure grid for new board dimensions
    setup_grid(app);

    // Rebuild polygon manager for new board dimensions (issue 837)
    if (app->polygon_manager) {
        polygon_manager_destroy(app->polygon_manager);
    }
    app->polygon_manager = polygon_manager_create(
        (float)new_board->board_width,
        (float)new_board->board_height
    );
    app->polygons_dirty = 1;
    app->selected_polygon_index = -1;  // Clear polygon selection
    app->show_polygon_panel = 0;
    app->selected_rotor_index = -1;    // Clear rotor selection (issue 901g)
    app->show_rotor_panel = 0;

    editor_app_notify(app, "Board loaded", 2.0f);
    return 1;
}
// }}}

// {{{ editor_app_save
int editor_app_save(EditorApp* app) {
    if (!app || !app->board) return 0;

    // Validate portals before saving
    int orphan_channel;
    if (!board_data_validate_portals(app->board, &orphan_channel)) {
        char msg[64];
        snprintf(msg, sizeof(msg), "Channel %d has no exit!", orphan_channel);
        editor_app_notify(app, msg, 3.0f);
        return 0;
    }

    // Generate filename if needed
    if (!app->has_filename) {
        time_t now = time(NULL);
        struct tm* t = localtime(&now);
        snprintf(app->filename, sizeof(app->filename),
                 "boards/board-%04d%02d%02d-%02d%02d%02d.json",
                 t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
                 t->tm_hour, t->tm_min, t->tm_sec);
        app->has_filename = 1;
    }

    // Save board
    if (board_data_save_json(app->board, app->filename)) {
        app->modified = 0;
        editor_app_notify(app, "Saved!", 2.0f);
        printf("Saved board to: %s\n", app->filename);
        return 1;
    } else {
        editor_app_notify(app, "Save failed!", 2.0f);
        return 0;
    }
}
// }}}

// {{{ editor_app_new_board
void editor_app_new_board(EditorApp* app) {
    if (!app) return;

    if (app->board) {
        board_data_destroy(app->board);
    }

    app->board = board_data_create(DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS, (int)DEFAULT_GRID_CELL_SIZE);
    app->has_filename = 0;
    app->filename[0] = '\0';
    app->modified = 0;
    app->selected_object_index = -1;

    setup_grid(app);

    // Rebuild polygon manager for new board (issue 837)
    if (app->polygon_manager) {
        polygon_manager_destroy(app->polygon_manager);
    }
    app->polygon_manager = polygon_manager_create(
        (float)app->board->board_width,
        (float)app->board->board_height
    );
    app->polygons_dirty = 1;
    app->selected_polygon_index = -1;  // Clear polygon selection
    app->show_polygon_panel = 0;
    app->selected_rotor_index = -1;    // Clear rotor selection (issue 901g)
    app->show_rotor_panel = 0;

    editor_app_notify(app, "New board", 1.5f);
}
// }}}

// =============================================================================
// State Queries
// =============================================================================

// {{{ editor_app_should_quit
int editor_app_should_quit(EditorApp* app) {
    return app ? app->should_quit : 1;
}
// }}}

// =============================================================================
// Notifications
// =============================================================================

// {{{ editor_app_notify
void editor_app_notify(EditorApp* app, const char* message, float duration) {
    if (!app) return;
    strncpy(app->notification, message, sizeof(app->notification) - 1);
    app->notification_timer = duration;
}
// }}}

// =============================================================================
// Internal: Input Handling
// =============================================================================

// {{{ handle_input
static void handle_input(EditorApp* app) {
    // Handle load dialog input first if visible
    if (app->load_dialog.visible) {
        // Handle delete confirmation dialog (issue 1208)
        if (app->load_dialog.confirm_delete) {
            if (IsKeyPressed(KEY_Y) || IsKeyPressed(KEY_ENTER)) {
                // Confirm delete
                if (app->load_dialog.file_list &&
                    app->load_dialog.delete_index >= 0 &&
                    app->load_dialog.delete_index < app->load_dialog.file_list->count) {
                    const char* path = app->load_dialog.file_list->filenames[app->load_dialog.delete_index];
                    if (remove(path) == 0) {
                        editor_app_notify(app, "File deleted", 2.0f);
                        // Refresh file list
                        board_file_list_destroy(app->load_dialog.file_list);
                        app->load_dialog.file_list = board_scan_directory("boards");
                        // Adjust selection if needed
                        if (app->load_dialog.selected_index >= app->load_dialog.file_list->count) {
                            app->load_dialog.selected_index = app->load_dialog.file_list->count - 1;
                        }
                        if (app->load_dialog.selected_index < 0) {
                            app->load_dialog.selected_index = 0;
                        }
                    } else {
                        editor_app_notify(app, "Delete failed", 2.0f);
                    }
                }
                app->load_dialog.confirm_delete = 0;
            } else if (IsKeyPressed(KEY_N) || IsKeyPressed(KEY_ESCAPE)) {
                // Cancel delete
                app->load_dialog.confirm_delete = 0;
            }
            return;
        }

        if (IsKeyPressed(KEY_ESCAPE)) {
            close_load_dialog(app);
            return;
        }

        // Navigate file list (arrow keys and vim-style j/k - issue 1218)
        if ((IsKeyPressed(KEY_UP) || IsKeyPressed(KEY_K)) &&
            app->load_dialog.selected_index > 0) {
            app->load_dialog.selected_index--;
        }
        if ((IsKeyPressed(KEY_DOWN) || IsKeyPressed(KEY_J)) &&
            app->load_dialog.file_list &&
            app->load_dialog.selected_index < app->load_dialog.file_list->count - 1) {
            app->load_dialog.selected_index++;
        }

        // Vim-style h to cancel/close (issue 1218)
        if (IsKeyPressed(KEY_H)) {
            close_load_dialog(app);
            return;
        }

        // Delete selected file: DEL or X key (issue 1208)
        if ((IsKeyPressed(KEY_DELETE) || IsKeyPressed(KEY_X)) &&
            app->load_dialog.file_list && app->load_dialog.file_list->count > 0) {
            app->load_dialog.confirm_delete = 1;
            app->load_dialog.delete_index = app->load_dialog.selected_index;
        }

        // Load selected file (Enter or vim-style l - issue 1218)
        if ((IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_L)) &&
            app->load_dialog.file_list &&
            app->load_dialog.file_list->count > 0) {
            const char* path = app->load_dialog.file_list->filenames[app->load_dialog.selected_index];
            editor_app_load(app, path);
            close_load_dialog(app);
        }

        return;
    }

    // Handle save dialog input if visible
    if (app->save_dialog.visible) {
        handle_save_dialog_input(app);
        return;
    }

    // ESC: Close panels in order: property, polygon, rotor, then quit
    if (IsKeyPressed(KEY_ESCAPE)) {
        if (app->show_property_panel || app->selection_count > 0) {
            selection_clear(app);  // Clears selection and hides property panel
        } else if (app->show_polygon_panel || app->selected_polygon_index >= 0) {
            // Clear polygon selection (issue 837)
            app->selected_polygon_index = -1;
            app->show_polygon_panel = 0;
        } else if (app->show_rotor_panel || app->selected_rotor_index >= 0) {
            // Clear rotor selection (issue 901g)
            app->selected_rotor_index = -1;
            app->show_rotor_panel = 0;
        } else {
            app->should_quit = 1;
        }
        return;
    }

    // Property panel slider interaction (issue 1211)
    if (handle_property_panel_input(app)) {
        return;  // Panel consumed the input
    }

    // Rotor panel input handling (issue 901g)
    if (handle_rotor_panel_input(app)) {
        return;  // Panel consumed the input
    }

    // Grid settings input handling (issue 840)
    if (handle_grid_settings_input(app)) {
        return;  // Grid settings consumed the input
    }

    // Tools panel input handling (issue 406, 901b: added rotor button)
    if (app->tools_panel) {
        Vector2 mouse = GetMousePosition();
        int pressed = IsMouseButtonPressed(MOUSE_LEFT_BUTTON);
        int released = IsMouseButtonReleased(MOUSE_LEFT_BUTTON);
        float wheel = GetMouseWheelMove();
        if (panel_handle_input(app->tools_panel, mouse, pressed, released, wheel)) {
            // Panel consumed input - check if a tool button was clicked
            // Buttons are at widget indices 2,3,4,5,6 (after label and separator)
            // 2=PEG, 3=LINE, 4=ENTRY, 5=EXIT, 6=ROTOR
            for (int i = 2; i <= 6; i++) {
                Widget* w = panel_get_widget(app->tools_panel, i);
                if (w && w->type == WIDGET_BUTTON && w->data.button.pressed) {
                    app->tool = (EditorAppTool)(i - 2);  // 0=PEG, 1=LINE, 2=ENTRY, 3=EXIT, 4=ROTOR
                    app->line_tool.state = LINE_STATE_IDLE;
                }
            }
            // Check mode toggle button (index 10 after adding rotor)
            Widget* mode_btn = panel_get_widget(app->tools_panel, 10);
            if (mode_btn && mode_btn->type == WIDGET_BUTTON && mode_btn->data.button.pressed) {
                app->mode = (app->mode == APP_MODE_PLACE) ? APP_MODE_ERASE : APP_MODE_PLACE;
                app->line_tool.state = LINE_STATE_IDLE;
            }
            return;
        }
    }

    // Toolbar button clicks (issue 1213)
    if (handle_toolbar_click(app)) {
        return;  // Toolbar consumed the click
    }

    // Tool selection: 1-4
    handle_tool_selection(app);

    // Mode toggle: TAB
    if (IsKeyPressed(KEY_TAB)) {
        app->mode = (app->mode == APP_MODE_PLACE) ? APP_MODE_ERASE : APP_MODE_PLACE;
        // Reset line tool when switching modes
        app->line_tool.state = LINE_STATE_IDLE;
    }

    // Save: S or Ctrl+S - opens save dialog for filename
    if (IsKeyPressed(KEY_S)) {
        open_save_dialog(app);
    }

    // Load: L or Ctrl+O
    if (IsKeyPressed(KEY_L) || IsKeyPressed(KEY_O)) {
        open_load_dialog(app);
    }

    // New: N
    if (IsKeyPressed(KEY_N)) {
        editor_app_new_board(app);
    }

    // Portal channel: +/-
    if (IsKeyPressed(KEY_EQUAL) || IsKeyPressed(KEY_KP_ADD)) {
        app->portal_channel++;
        if (app->portal_channel > 16) app->portal_channel = 16;
    }
    if (IsKeyPressed(KEY_MINUS) || IsKeyPressed(KEY_KP_SUBTRACT)) {
        app->portal_channel--;
        if (app->portal_channel < 1) app->portal_channel = 1;
    }

    // Select all: Ctrl+A (issue 1226)
    if (IsKeyPressed(KEY_A) && (IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL))) {
        selection_select_all(app);
    }

    // Toggle advanced/standard mode: F12 (issue 839)
    if (IsKeyPressed(KEY_F12)) {
        int new_mode = editor_app_toggle_advanced_mode(app);
        const char* mode_name = new_mode ? "Advanced (RGB)" : "Standard (Materials)";
        editor_app_notify(app, mode_name, 1.5f);
    }

    // Canvas interaction
    if (app->hover_valid && IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        handle_canvas_click(app);
    }

    // Right-click handling (issue 1211, 1226, 902b)
    // Supports both click-to-select and drag-to-select
    if (IsMouseButtonPressed(MOUSE_RIGHT_BUTTON)) {
        // If line tool is active, cancel it
        if (app->tool == APP_TOOL_LINE && app->line_tool.state != LINE_STATE_IDLE) {
            app->line_tool.state = LINE_STATE_IDLE;
        // Issue 902b: If track tool is active, cancel it
        } else if (app->tool == APP_TOOL_TRACK && app->track_tool.state != TRACK_STATE_IDLE) {
            app->track_tool.state = TRACK_STATE_IDLE;
        } else {
            // Start potential drag selection
            Vector2 mouse = GetMousePosition();
            app->is_drag_selecting = 1;
            app->drag_start_x = mouse.x;
            app->drag_start_y = mouse.y;
        }
    }

    // Handle drag selection release (issue 1226)
    if (IsMouseButtonReleased(MOUSE_RIGHT_BUTTON) && app->is_drag_selecting) {
        Vector2 mouse = GetMousePosition();
        float dx = mouse.x - app->drag_start_x;
        float dy = mouse.y - app->drag_start_y;
        float drag_dist = sqrtf(dx * dx + dy * dy);

        // Threshold to distinguish click vs drag (10 pixels)
        if (drag_dist > 10.0f) {
            // Was a drag - select objects in rectangle
            selection_select_in_rect(app, app->drag_start_x, app->drag_start_y,
                                     mouse.x, mouse.y);
        } else {
            // Was a click - select single object
            handle_object_selection(app, mouse.x, mouse.y);
        }

        app->is_drag_selecting = 0;
    }

    // Line tool: thickness adjustment with mouse wheel in thickness mode
    if (app->tool == APP_TOOL_LINE && app->line_tool.state == LINE_STATE_THICKNESS) {
        float scroll = GetMouseWheelMove();
        if (scroll != 0) {
            app->line_tool.thickness += scroll * 2.0f;
            if (app->line_tool.thickness < app->line_tool.min_thickness) {
                app->line_tool.thickness = app->line_tool.min_thickness;
            }
            if (app->line_tool.thickness > app->line_tool.max_thickness) {
                app->line_tool.thickness = app->line_tool.max_thickness;
            }
        }
    } else {
        // Canvas scrolling with mouse wheel (when not adjusting line thickness)
        float scroll = GetMouseWheelMove();
        if (scroll != 0) {
            float scroll_speed = 40.0f;
            app->camera.offset.y += scroll * scroll_speed;

            // Scroll bounds (issue 1228):
            // - Scroll UP (max): board top at canvas bottom (one row visible)
            // - Scroll DOWN (min): board bottom at canvas top (one row visible)
            // Positive offset moves grid DOWN, negative moves grid UP
            float one_row = app->grid.cell_size;
            float max_scroll = app->canvas_height - one_row;  // Board top near canvas bottom
            float min_scroll = -app->grid.height + one_row;   // Board bottom near canvas top

            if (app->camera.offset.y > max_scroll) app->camera.offset.y = max_scroll;
            if (app->camera.offset.y < min_scroll) app->camera.offset.y = min_scroll;
        }
    }
}
// }}}

// {{{ handle_tool_selection
static void handle_tool_selection(EditorApp* app) {
    if (IsKeyPressed(KEY_ONE)) {
        app->tool = APP_TOOL_PEG;
        app->line_tool.state = LINE_STATE_IDLE;
        app->track_tool.state = TRACK_STATE_IDLE;
    }
    if (IsKeyPressed(KEY_TWO)) {
        app->tool = APP_TOOL_LINE;
        app->line_tool.state = LINE_STATE_IDLE;
        app->track_tool.state = TRACK_STATE_IDLE;
    }
    if (IsKeyPressed(KEY_THREE)) {
        app->tool = APP_TOOL_PORTAL_ENTRY;
        app->line_tool.state = LINE_STATE_IDLE;
        app->track_tool.state = TRACK_STATE_IDLE;
    }
    if (IsKeyPressed(KEY_FOUR)) {
        app->tool = APP_TOOL_PORTAL_EXIT;
        app->line_tool.state = LINE_STATE_IDLE;
        app->track_tool.state = TRACK_STATE_IDLE;
    }
    // Rotor tool: key 5 (issue 901b)
    if (IsKeyPressed(KEY_FIVE)) {
        app->tool = APP_TOOL_ROTOR;
        app->line_tool.state = LINE_STATE_IDLE;
        app->track_tool.state = TRACK_STATE_IDLE;
    }
    // Track tool: key 6 (issue 902b)
    if (IsKeyPressed(KEY_SIX)) {
        app->tool = APP_TOOL_TRACK;
        app->line_tool.state = LINE_STATE_IDLE;
        app->track_tool.state = TRACK_STATE_IDLE;
    }
}
// }}}

// {{{ handle_toolbar_click
// Handles mouse clicks on toolbar buttons (issue 1213, 901b: added rotor)
// Returns 1 if click was consumed, 0 otherwise
static int handle_toolbar_click(EditorApp* app) {
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return 0;

    Vector2 mouse = GetMousePosition();

    // Button layout (must match render_toolbar)
    int btn_x = 200;
    int btn_y = 10;
    int btn_w = 70;
    int btn_h = 30;
    int btn_spacing = 8;

    // Issue 902b: Added track tool to toolbar
    EditorAppTool tool_values[] = {APP_TOOL_PEG, APP_TOOL_LINE, APP_TOOL_PORTAL_ENTRY, APP_TOOL_PORTAL_EXIT, APP_TOOL_ROTOR, APP_TOOL_TRACK};

    for (int i = 0; i < 6; i++) {
        if (mouse.x >= btn_x && mouse.x < btn_x + btn_w &&
            mouse.y >= btn_y && mouse.y < btn_y + btn_h) {
            app->tool = tool_values[i];
            app->line_tool.state = LINE_STATE_IDLE;
            app->track_tool.state = TRACK_STATE_IDLE;
            return 1;
        }
        btn_x += btn_w + btn_spacing;
    }

    return 0;
}
// }}}

// {{{ handle_canvas_click
static void handle_canvas_click(EditorApp* app) {
    if (app->mode == APP_MODE_PLACE) {
        if (app->tool == APP_TOOL_LINE) {
            handle_line_tool(app);
        } else if (app->tool == APP_TOOL_TRACK) {
            // Issue 902b: Track tool uses two-click placement like lines
            handle_track_tool(app);
        } else {
            place_object(app);
        }
    } else {
        erase_object(app);
    }
}
// }}}

// {{{ handle_line_tool
static void handle_line_tool(EditorApp* app) {
    switch (app->line_tool.state) {
        case LINE_STATE_IDLE:
            // Set start point
            app->line_tool.start_col = app->hover_col;
            app->line_tool.start_row = app->hover_row;
            app->line_tool.start_x = grid_to_pixel_x(&app->grid, app->hover_col, app->hover_row);
            app->line_tool.start_y = grid_to_pixel_y(&app->grid, app->hover_col, app->hover_row);
            app->line_tool.state = LINE_STATE_END;
            break;

        case LINE_STATE_END:
            // Set end point
            app->line_tool.end_col = app->hover_col;
            app->line_tool.end_row = app->hover_row;
            app->line_tool.end_x = grid_to_pixel_x(&app->grid, app->hover_col, app->hover_row);
            app->line_tool.end_y = grid_to_pixel_y(&app->grid, app->hover_col, app->hover_row);
            app->line_tool.state = LINE_STATE_THICKNESS;
            break;

        case LINE_STATE_THICKNESS:
            // Confirm and add line
            board_data_add_line(app->board,
                               app->line_tool.start_col, app->line_tool.start_row,
                               app->line_tool.end_col, app->line_tool.end_row,
                               app->line_tool.thickness);
            app->modified = 1;
            app->polygons_dirty = 1;  // Rebuild polygon detection (issue 837)
            app->line_tool.state = LINE_STATE_IDLE;
            break;
    }
}
// }}}

// {{{ handle_track_tool
// Issue 902b: Track tool for drawing mover paths
// Simpler than line tool - no thickness adjustment, just two clicks
static void handle_track_tool(EditorApp* app) {
    switch (app->track_tool.state) {
        case TRACK_STATE_IDLE:
            // Set start point
            app->track_tool.start_col = app->hover_col;
            app->track_tool.start_row = app->hover_row;
            app->track_tool.start_x = grid_to_pixel_x(&app->grid, app->hover_col, app->hover_row);
            app->track_tool.start_y = grid_to_pixel_y(&app->grid, app->hover_col, app->hover_row);
            app->track_tool.state = TRACK_STATE_END;
            break;

        case TRACK_STATE_END:
            // Set end point and add track segment
            app->track_tool.end_col = app->hover_col;
            app->track_tool.end_row = app->hover_row;
            app->track_tool.end_x = grid_to_pixel_x(&app->grid, app->hover_col, app->hover_row);
            app->track_tool.end_y = grid_to_pixel_y(&app->grid, app->hover_col, app->hover_row);

            // Add track segment to board
            int seg_idx = board_data_add_track_segment(app->board,
                app->track_tool.start_col, app->track_tool.start_row,
                app->track_tool.end_col, app->track_tool.end_row);

            if (seg_idx >= 0) {
                app->modified = 1;
                // Recompute connectivity after adding segment
                board_data_compute_track_connectivity(app->board);
                editor_app_notify(app, "Track segment added", 1.0f);
            } else {
                editor_app_notify(app, "Failed to add track segment", 2.0f);
            }

            app->track_tool.state = TRACK_STATE_IDLE;
            break;
    }
}
// }}}

// {{{ update_hover
static void update_hover(EditorApp* app) {
    Vector2 mouse = GetMousePosition();

    // Check if mouse is in canvas area
    if (mouse.x < app->canvas_x || mouse.x > app->canvas_x + app->canvas_width ||
        mouse.y < app->canvas_y || mouse.y > app->canvas_y + app->canvas_height) {
        app->hover_valid = 0;
        return;
    }

    // Adjust mouse Y for scroll offset
    float adjusted_y = mouse.y - app->camera.offset.y;

    // Convert to grid coordinates
    // pixel_to_grid returns void, so we check bounds first
    // Use adjusted coordinates that account for scroll
    if (grid_pixel_in_bounds(&app->grid, mouse.x, adjusted_y)) {
        int col, row;
        pixel_to_grid(&app->grid, mouse.x, adjusted_y, &col, &row);
        app->hover_col = col;
        app->hover_row = row;
        app->hover_valid = 1;
    } else {
        app->hover_valid = 0;
    }
}
// }}}

// Default rotor speed: 1.0 radians per second (clockwise)
#define DEFAULT_ROTOR_SPEED 1.0f

// {{{ place_object
static void place_object(EditorApp* app) {
    if (!app->hover_valid) return;

    switch (app->tool) {
        case APP_TOOL_PEG:
            board_data_add_peg(app->board, app->hover_col, app->hover_row);
            app->modified = 1;
            break;

        case APP_TOOL_LINE:
            // Handled by line tool state machine
            break;

        case APP_TOOL_PORTAL_ENTRY:
            board_data_add_portal(app->board, app->hover_col, app->hover_row,
                                  DEFAULT_PORTAL_SIZE, DEFAULT_PORTAL_SIZE,
                                  app->portal_channel, PORTAL_ENTRY);
            app->modified = 1;
            break;

        case APP_TOOL_PORTAL_EXIT:
            board_data_add_portal(app->board, app->hover_col, app->hover_row,
                                  DEFAULT_PORTAL_SIZE, DEFAULT_PORTAL_SIZE,
                                  app->portal_channel, PORTAL_EXIT);
            app->modified = 1;
            break;

        // Rotor placement (issue 901b)
        case APP_TOOL_ROTOR:
            board_data_add_rotor(app->board, app->hover_col, app->hover_row,
                                 DEFAULT_ROTOR_SPEED);
            app->modified = 1;
            break;

        // Track tool (issue 902b) - handled by track tool state machine
        case APP_TOOL_TRACK:
            break;
    }
}
// }}}

// {{{ erase_rotor_at
// Removes a rotor at the given grid position (issue 901b)
// Returns 1 if a rotor was removed, 0 otherwise
static int erase_rotor_at(EditorApp* app, int col, int row) {
    if (!app || !app->board) return 0;

    for (int i = 0; i < app->board->rotor_count; i++) {
        if (app->board->rotors[i].col == col && app->board->rotors[i].row == row) {
            board_data_remove_rotor(app->board, i);
            return 1;
        }
    }
    return 0;
}
// }}}

// {{{ erase_object
static void erase_object(EditorApp* app) {
    if (!app->hover_valid) return;

    // Try to remove object at hover position
    if (board_data_remove_object_at(app->board, app->hover_col, app->hover_row)) {
        app->modified = 1;
        app->polygons_dirty = 1;  // Rebuild polygon detection (issue 837)
        return;
    }

    // Try to remove zone at hover position
    if (board_data_remove_zone_at(app->board, app->hover_col, app->hover_row)) {
        app->modified = 1;
        return;
    }

    // Try to remove rotor at hover position (issue 901b)
    if (erase_rotor_at(app, app->hover_col, app->hover_row)) {
        app->modified = 1;
    }
}
// }}}

// =============================================================================
// Internal: Load Dialog
// =============================================================================

// {{{ open_load_dialog
static void open_load_dialog(EditorApp* app) {
    if (app->load_dialog.file_list) {
        board_file_list_destroy(app->load_dialog.file_list);
    }

    app->load_dialog.file_list = board_scan_directory("boards");
    app->load_dialog.selected_index = 0;
    app->load_dialog.scroll_offset = 0;
    app->load_dialog.visible = 1;
}
// }}}

// {{{ close_load_dialog
static void close_load_dialog(EditorApp* app) {
    app->load_dialog.visible = 0;
}
// }}}

// =============================================================================
// Internal: Save Dialog
// =============================================================================

// {{{ open_save_dialog
static void open_save_dialog(EditorApp* app) {
    // Initialize with empty filename or existing filename (without path)
    if (app->has_filename) {
        const char* name = strrchr(app->filename, '/');
        name = name ? name + 1 : app->filename;
        // Remove .json extension for editing
        strncpy(app->save_dialog.filename, name, 63);
        app->save_dialog.filename[63] = '\0';
        char* dot = strrchr(app->save_dialog.filename, '.');
        if (dot) *dot = '\0';
    } else {
        app->save_dialog.filename[0] = '\0';
    }
    app->save_dialog.cursor_pos = (int)strlen(app->save_dialog.filename);
    // Initialize checkbox from board data (issue 1224)
    app->save_dialog.in_progress = app->board ? app->board->in_progress : 0;
    app->save_dialog.visible = 1;
}
// }}}

// {{{ close_save_dialog
static void close_save_dialog(EditorApp* app) {
    app->save_dialog.visible = 0;
}
// }}}

// {{{ handle_save_dialog_input
static void handle_save_dialog_input(EditorApp* app) {
    // Cancel on ESC
    if (IsKeyPressed(KEY_ESCAPE)) {
        close_save_dialog(app);
        return;
    }

    // Toggle in-progress checkbox with TAB (issue 1224)
    if (IsKeyPressed(KEY_TAB)) {
        app->save_dialog.in_progress = !app->save_dialog.in_progress;
        return;
    }

    // Confirm on Enter
    if (IsKeyPressed(KEY_ENTER)) {
        if (strlen(app->save_dialog.filename) > 0) {
            // Validate portals before saving
            int orphan_channel;
            if (!board_data_validate_portals(app->board, &orphan_channel)) {
                char msg[64];
                snprintf(msg, sizeof(msg), "Channel %d has no exit!", orphan_channel);
                editor_app_notify(app, msg, 3.0f);
                close_save_dialog(app);
                return;
            }

            // Apply in-progress flag to board data (issue 1224)
            app->board->in_progress = app->save_dialog.in_progress;

            // Build full path
            snprintf(app->filename, sizeof(app->filename), "boards/%s.json",
                     app->save_dialog.filename);
            app->has_filename = 1;

            // Save with the new filename
            if (board_data_save_json(app->board, app->filename)) {
                app->modified = 0;
                editor_app_notify(app, "Saved!", 2.0f);
                printf("Saved board to: %s\n", app->filename);
            } else {
                editor_app_notify(app, "Save failed!", 2.0f);
            }
            close_save_dialog(app);
        }
        return;
    }

    int len = (int)strlen(app->save_dialog.filename);

    // Cursor movement with arrow keys (issue 1214)
    if (IsKeyPressed(KEY_LEFT) || IsKeyPressedRepeat(KEY_LEFT)) {
        if (app->save_dialog.cursor_pos > 0) {
            app->save_dialog.cursor_pos--;
        }
    }
    if (IsKeyPressed(KEY_RIGHT) || IsKeyPressedRepeat(KEY_RIGHT)) {
        if (app->save_dialog.cursor_pos < len) {
            app->save_dialog.cursor_pos++;
        }
    }
    // Home/End keys
    if (IsKeyPressed(KEY_HOME)) {
        app->save_dialog.cursor_pos = 0;
    }
    if (IsKeyPressed(KEY_END)) {
        app->save_dialog.cursor_pos = len;
    }

    // Handle text input - insert at cursor position (issue 1214)
    int key = GetCharPressed();
    while (key > 0) {
        // Only allow alphanumeric, dash, underscore
        if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') ||
            (key >= '0' && key <= '9') || key == '-' || key == '_') {
            if (len < 63) {
                // Shift characters after cursor right
                for (int i = len; i >= app->save_dialog.cursor_pos; i--) {
                    app->save_dialog.filename[i + 1] = app->save_dialog.filename[i];
                }
                // Insert character at cursor
                app->save_dialog.filename[app->save_dialog.cursor_pos] = (char)key;
                app->save_dialog.cursor_pos++;
                len++;
            }
        }
        key = GetCharPressed();
    }

    // Backspace - delete character before cursor (issue 1214)
    if (IsKeyPressed(KEY_BACKSPACE) || IsKeyPressedRepeat(KEY_BACKSPACE)) {
        if (app->save_dialog.cursor_pos > 0) {
            // Shift characters after cursor left
            for (int i = app->save_dialog.cursor_pos - 1; i < len; i++) {
                app->save_dialog.filename[i] = app->save_dialog.filename[i + 1];
            }
            app->save_dialog.cursor_pos--;
        }
    }

    // Delete key - delete character at cursor (issue 1214)
    if (IsKeyPressed(KEY_DELETE) || IsKeyPressedRepeat(KEY_DELETE)) {
        if (app->save_dialog.cursor_pos < len) {
            // Shift characters after cursor left
            for (int i = app->save_dialog.cursor_pos; i < len; i++) {
                app->save_dialog.filename[i] = app->save_dialog.filename[i + 1];
            }
        }
    }
}
// }}}

// =============================================================================
// Internal: Grid Setup
// =============================================================================

// {{{ setup_grid
static void setup_grid(EditorApp* app) {
    if (!app || !app->board) return;

    // Use fixed cell size from board data (issue 1228)
    // Board dimensions stay constant regardless of window size
    float cell_size = (float)app->board->cell_size;
    if (cell_size < 20) cell_size = DEFAULT_GRID_CELL_SIZE;

    // Calculate grid width for horizontal centering
    float grid_width = app->board->grid_cols * cell_size;

    // Center grid horizontally in canvas
    float origin_x = app->canvas_x + (app->canvas_width - grid_width) / 2;
    // Start grid at top of canvas (scrolling will reveal more)
    float origin_y = app->canvas_y;

    app->grid = grid_create(app->board->grid_cols, app->board->grid_rows,
                            cell_size, origin_x, origin_y);

    // Reset scroll offset when grid changes
    app->camera.offset.y = 0;
}
// }}}

// =============================================================================
// Grid Settings (issue 840)
// =============================================================================

// Grid dimension limits
#define GRID_MIN_COLS 8
#define GRID_MAX_COLS 24
#define GRID_MIN_ROWS 12
#define GRID_MAX_ROWS 36

// {{{ change_grid_dimensions
// Changes board grid dimensions and repositions objects
// Objects outside new bounds are clamped to nearest valid position
static void change_grid_dimensions(EditorApp* app, int new_cols, int new_rows) {
    if (!app || !app->board) return;

    // Clamp to valid range
    if (new_cols < GRID_MIN_COLS) new_cols = GRID_MIN_COLS;
    if (new_cols > GRID_MAX_COLS) new_cols = GRID_MAX_COLS;
    if (new_rows < GRID_MIN_ROWS) new_rows = GRID_MIN_ROWS;
    if (new_rows > GRID_MAX_ROWS) new_rows = GRID_MAX_ROWS;

    // No change needed
    if (new_cols == app->board->grid_cols && new_rows == app->board->grid_rows) {
        return;
    }

    int old_cols = app->board->grid_cols;
    int old_rows = app->board->grid_rows;

    // Update board dimensions
    app->board->grid_cols = new_cols;
    app->board->grid_rows = new_rows;

    // Calculate new cell size from fixed board dimensions
    // Cell size = board dimension / grid count
    float cell_w = BOARD_WIDTH / new_cols;
    float cell_h = BOARD_HEIGHT / new_rows;
    // Use smaller dimension to ensure cells fit both ways
    float new_cell_size = (cell_w < cell_h) ? cell_w : cell_h;
    app->board->cell_size = (int)new_cell_size;

    // Update board pixel dimensions to match actual grid coverage
    app->board->board_width = (int)(new_cols * new_cell_size);
    app->board->board_height = (int)(new_rows * new_cell_size);

    // Clamp objects to new grid bounds
    // Objects store grid coordinates, clamp to [0, max-1]
    for (int i = 0; i < app->board->object_count; i++) {
        BoardObject* obj = &app->board->objects[i];
        if (obj->col >= new_cols) obj->col = new_cols - 1;
        if (obj->row >= new_rows) obj->row = new_rows - 1;
    }

    // Clamp zones to new bounds
    for (int i = 0; i < app->board->zone_count; i++) {
        BoardZone* zone = &app->board->zones[i];
        if (zone->col >= new_cols) zone->col = new_cols - 1;
        if (zone->row >= new_rows) zone->row = new_rows - 1;
        // Clamp zone size so it doesn't extend past grid
        if (zone->col + zone->width > new_cols) {
            zone->width = new_cols - zone->col;
        }
        if (zone->row + zone->height > new_rows) {
            zone->height = new_rows - zone->row;
        }
    }

    // Clamp rotors to new bounds (issue 901b)
    for (int i = 0; i < app->board->rotor_count; i++) {
        Rotor* rotor = &app->board->rotors[i];
        if (rotor->col >= new_cols) rotor->col = new_cols - 1;
        if (rotor->row >= new_rows) rotor->row = new_rows - 1;
    }

    // Rebuild polygon manager for new dimensions (issue 837)
    if (app->polygon_manager) {
        polygon_manager_destroy(app->polygon_manager);
        app->polygon_manager = polygon_manager_create(
            (float)app->board->board_width,
            (float)app->board->board_height
        );
        app->polygons_dirty = 1;
    }

    // Rebuild grid with new dimensions
    setup_grid(app);

    // Mark board as modified
    app->modified = 1;

    // Clear selection since objects may have moved
    selection_clear(app);

    // Notify user
    char msg[64];
    snprintf(msg, sizeof(msg), "Grid: %dx%d -> %dx%d", old_cols, old_rows, new_cols, new_rows);
    editor_app_notify(app, msg, 1.5f);
}
// }}}

// {{{ handle_grid_settings_input
// Handles clicks on grid settings buttons in sidebar
// Returns 1 if input was consumed, 0 otherwise
static int handle_grid_settings_input(EditorApp* app) {
    if (!app || !app->board) return 0;
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return 0;

    Vector2 mouse = GetMousePosition();

    // Calculate button positions (must match render_sidebar)
    int x = app->screen_width - SIDEBAR_WIDTH;
    int y = TOOLBAR_HEIGHT;

    // Trace through render_sidebar to find Grid Settings position:
    // y + 55 = tool info, y + 150 = Board Stats header
    // y + 185 = objects, y + 205 = zones, y + 225 = rotors, y + 245 = grid
    // y + 280 = Grid Settings header, y + 315 = first row buttons
    int info_y = y + 315;  // First row of buttons (columns)

    int btn_size = 20;
    int value_width = 30;
    int cols_x = x + 60;
    int rows_x = x + 60;

    // Columns buttons
    Rectangle cols_minus = { (float)cols_x, (float)info_y, (float)btn_size, (float)btn_size };
    Rectangle cols_plus = { (float)(cols_x + btn_size + value_width), (float)info_y, (float)btn_size, (float)btn_size };

    if (CheckCollisionPointRec(mouse, cols_minus)) {
        change_grid_dimensions(app, app->board->grid_cols - 1, app->board->grid_rows);
        return 1;
    }
    if (CheckCollisionPointRec(mouse, cols_plus)) {
        change_grid_dimensions(app, app->board->grid_cols + 1, app->board->grid_rows);
        return 1;
    }

    // Rows buttons (28 pixels below cols)
    info_y += 28;
    Rectangle rows_minus = { (float)rows_x, (float)info_y, (float)btn_size, (float)btn_size };
    Rectangle rows_plus = { (float)(rows_x + btn_size + value_width), (float)info_y, (float)btn_size, (float)btn_size };

    if (CheckCollisionPointRec(mouse, rows_minus)) {
        change_grid_dimensions(app, app->board->grid_cols, app->board->grid_rows - 1);
        return 1;
    }
    if (CheckCollisionPointRec(mouse, rows_plus)) {
        change_grid_dimensions(app, app->board->grid_cols, app->board->grid_rows + 1);
        return 1;
    }

    return 0;
}
// }}}

// =============================================================================
// Internal: Rendering
// =============================================================================

// {{{ render_toolbar
static void render_toolbar(EditorApp* app) {
    // Background
    DrawRectangle(0, 0, app->screen_width, TOOLBAR_HEIGHT, PANEL_COLOR);
    DrawLine(0, TOOLBAR_HEIGHT - 1, app->screen_width, TOOLBAR_HEIGHT - 1, PANEL_BORDER);

    // Title
    DrawText("BOARD EDITOR", 20, 15, 24, TEXT_COLOR);

    // Tool buttons (issue 901b: rotor, issue 902b: track)
    int btn_x = 200;
    int btn_y = 10;
    int btn_w = 70;
    int btn_h = 30;
    int btn_spacing = 8;

    const char* tools[] = {"1:Peg", "2:Line", "3:In", "4:Out", "5:Rotor", "6:Track"};
    EditorAppTool tool_values[] = {APP_TOOL_PEG, APP_TOOL_LINE, APP_TOOL_PORTAL_ENTRY, APP_TOOL_PORTAL_EXIT, APP_TOOL_ROTOR, APP_TOOL_TRACK};

    for (int i = 0; i < 6; i++) {
        Color btn_color = (app->tool == tool_values[i]) ? BUTTON_ACTIVE : BUTTON_COLOR;
        DrawRectangle(btn_x, btn_y, btn_w, btn_h, btn_color);
        DrawRectangleLines(btn_x, btn_y, btn_w, btn_h, PANEL_BORDER);

        int tw = MeasureText(tools[i], 16);
        DrawText(tools[i], btn_x + (btn_w - tw) / 2, btn_y + 7, 16, TEXT_COLOR);

        btn_x += btn_w + btn_spacing;
    }

    // Mode indicator
    const char* mode_text = (app->mode == APP_MODE_PLACE) ? "Mode: PLACE" : "Mode: ERASE";
    Color mode_color = (app->mode == APP_MODE_PLACE) ? GREEN : RED;
    DrawText(mode_text, btn_x + 20, btn_y + 7, 16, mode_color);

    // Second row: portal channel, keyboard hints
    btn_y = 45;
    DrawText("TAB=mode  S=save  L=load  N=new  ESC=quit", 20, btn_y + 5, 14, TEXT_DIM);

    // Portal channel (right side)
    if (app->tool == APP_TOOL_PORTAL_ENTRY || app->tool == APP_TOOL_PORTAL_EXIT) {
        char ch_text[32];
        snprintf(ch_text, sizeof(ch_text), "Channel: %d (+/-)", app->portal_channel);
        int tw = MeasureText(ch_text, 16);
        DrawText(ch_text, app->screen_width - SIDEBAR_WIDTH - tw - 20, btn_y + 5, 16, TEXT_COLOR);
    }
}
// }}}

// {{{ render_sidebar
static void render_sidebar(EditorApp* app) {
    int x = app->screen_width - SIDEBAR_WIDTH;
    int y = TOOLBAR_HEIGHT;
    int h = app->screen_height - TOOLBAR_HEIGHT - FOOTER_HEIGHT;

    // Background
    DrawRectangle(x, y, SIDEBAR_WIDTH, h, PANEL_COLOR);
    DrawLine(x, y, x, y + h, PANEL_BORDER);

    // Properties header
    DrawText("Properties", x + 15, y + 15, 18, TEXT_COLOR);
    DrawLine(x + 10, y + 40, x + SIDEBAR_WIDTH - 10, y + 40, PANEL_BORDER);

    // Current tool info (issue 901b: rotor, issue 902b: track)
    int info_y = y + 55;
    const char* tool_names[] = {"Peg", "Line", "Portal Entry", "Portal Exit", "Rotor", "Track"};
    DrawText("Tool:", x + 15, info_y, 14, TEXT_DIM);
    DrawText(tool_names[app->tool], x + 60, info_y, 14, TEXT_COLOR);

    info_y += 25;
    if (app->tool == APP_TOOL_LINE) {
        DrawText("Thickness:", x + 15, info_y, 14, TEXT_DIM);
        char th_text[16];
        snprintf(th_text, sizeof(th_text), "%.0f px", app->line_tool.thickness);
        DrawText(th_text, x + 90, info_y, 14, TEXT_COLOR);
        info_y += 20;
        DrawText("(scroll to adjust)", x + 15, info_y, 12, TEXT_DIM);
    }

    if (app->tool == APP_TOOL_PORTAL_ENTRY || app->tool == APP_TOOL_PORTAL_EXIT) {
        DrawText("Channel:", x + 15, info_y, 14, TEXT_DIM);
        char ch_text[8];
        snprintf(ch_text, sizeof(ch_text), "%d", app->portal_channel);
        DrawText(ch_text, x + 80, info_y, 14, TEXT_COLOR);
    }

    // Board stats
    info_y = y + 150;
    DrawText("Board Stats", x + 15, info_y, 16, TEXT_COLOR);
    DrawLine(x + 10, info_y + 22, x + SIDEBAR_WIDTH - 10, info_y + 22, PANEL_BORDER);

    info_y += 35;
    char stat_text[64];
    snprintf(stat_text, sizeof(stat_text), "Objects: %d", app->board ? app->board->object_count : 0);
    DrawText(stat_text, x + 15, info_y, 14, TEXT_COLOR);

    info_y += 20;
    snprintf(stat_text, sizeof(stat_text), "Zones: %d", app->board ? app->board->zone_count : 0);
    DrawText(stat_text, x + 15, info_y, 14, TEXT_COLOR);

    // Rotor count (issue 901b)
    info_y += 20;
    snprintf(stat_text, sizeof(stat_text), "Rotors: %d", app->board ? app->board->rotor_count : 0);
    DrawText(stat_text, x + 15, info_y, 14, TEXT_COLOR);

    info_y += 20;
    snprintf(stat_text, sizeof(stat_text), "Grid: %dx%d",
             app->board ? app->board->grid_cols : 0,
             app->board ? app->board->grid_rows : 0);
    DrawText(stat_text, x + 15, info_y, 14, TEXT_COLOR);

    // Grid Settings section (issue 840)
    info_y += 35;
    DrawText("Grid Settings", x + 15, info_y, 16, TEXT_COLOR);
    DrawLine(x + 10, info_y + 22, x + SIDEBAR_WIDTH - 10, info_y + 22, PANEL_BORDER);

    info_y += 35;
    int btn_size = 20;
    int value_width = 30;

    // Columns: [-] value [+]
    DrawText("Cols:", x + 15, info_y + 3, 14, TEXT_DIM);
    int cols_x = x + 60;
    // Minus button
    Rectangle cols_minus = { (float)cols_x, (float)info_y, (float)btn_size, (float)btn_size };
    DrawRectangleRec(cols_minus, BUTTON_COLOR);
    DrawText("-", cols_x + 6, info_y + 3, 14, TEXT_COLOR);
    // Value
    snprintf(stat_text, sizeof(stat_text), "%d", app->board ? app->board->grid_cols : 0);
    DrawText(stat_text, cols_x + btn_size + 8, info_y + 3, 14, TEXT_COLOR);
    // Plus button
    Rectangle cols_plus = { (float)(cols_x + btn_size + value_width), (float)info_y, (float)btn_size, (float)btn_size };
    DrawRectangleRec(cols_plus, BUTTON_COLOR);
    DrawText("+", cols_x + btn_size + value_width + 5, info_y + 3, 14, TEXT_COLOR);

    info_y += 28;

    // Rows: [-] value [+]
    DrawText("Rows:", x + 15, info_y + 3, 14, TEXT_DIM);
    int rows_x = x + 60;
    // Minus button
    Rectangle rows_minus = { (float)rows_x, (float)info_y, (float)btn_size, (float)btn_size };
    DrawRectangleRec(rows_minus, BUTTON_COLOR);
    DrawText("-", rows_x + 6, info_y + 3, 14, TEXT_COLOR);
    // Value
    snprintf(stat_text, sizeof(stat_text), "%d", app->board ? app->board->grid_rows : 0);
    DrawText(stat_text, rows_x + btn_size + 8, info_y + 3, 14, TEXT_COLOR);
    // Plus button
    Rectangle rows_plus = { (float)(rows_x + btn_size + value_width), (float)info_y, (float)btn_size, (float)btn_size };
    DrawRectangleRec(rows_plus, BUTTON_COLOR);
    DrawText("+", rows_x + btn_size + value_width + 5, info_y + 3, 14, TEXT_COLOR);

    // Show calculated cell size
    info_y += 28;
    if (app->board) {
        float cell_w = BOARD_WIDTH / app->board->grid_cols;
        float cell_h = BOARD_HEIGHT / app->board->grid_rows;
        snprintf(stat_text, sizeof(stat_text), "Cell: %.0fx%.0f px", cell_w, cell_h);
        DrawText(stat_text, x + 15, info_y, 12, TEXT_DIM);
    }
}
// }}}

// {{{ render_footer
static void render_footer(EditorApp* app) {
    int y = app->screen_height - FOOTER_HEIGHT;

    // Background
    DrawRectangle(0, y, app->screen_width, FOOTER_HEIGHT, PANEL_COLOR);
    DrawLine(0, y, app->screen_width, y, PANEL_BORDER);

    // Filename
    if (app->has_filename) {
        DrawText(app->filename, 15, y + 8, 14, TEXT_COLOR);
    } else {
        DrawText("(unsaved)", 15, y + 8, 14, TEXT_DIM);
    }

    // Modified indicator
    if (app->modified) {
        DrawText("*", 10 + (app->has_filename ? MeasureText(app->filename, 14) : MeasureText("(unsaved)", 14)) + 5,
                 y + 8, 14, YELLOW);
    }

    // Hover position
    if (app->hover_valid) {
        char pos_text[32];
        snprintf(pos_text, sizeof(pos_text), "Cell: (%d, %d)", app->hover_col, app->hover_row);
        int tw = MeasureText(pos_text, 14);
        DrawText(pos_text, app->screen_width - SIDEBAR_WIDTH - tw - 20, y + 8, 14, TEXT_COLOR);
    }
}
// }}}

// {{{ render_selection_highlights
// Renders highlight circles around selected objects (issue 1226)
static void render_selection_highlights(EditorApp* app) {
    if (!app || !app->board || app->selection_count == 0) return;

    Color highlight_color = (Color){100, 200, 255, 120};
    Color outline_color = (Color){100, 200, 255, 255};

    for (int i = 0; i < app->selection_count; i++) {
        int idx = app->selected_indices[i];
        if (idx < 0 || idx >= app->board->object_count) continue;

        BoardObject* obj = &app->board->objects[idx];
        float x = grid_to_pixel_x(&app->grid, obj->col, obj->row);
        float y = grid_to_pixel_y(&app->grid, obj->col, obj->row);

        // Draw selection highlight based on object type
        if (obj->type == OBJECT_PEG) {
            float radius = PEG_RADIUS + 4.0f;
            DrawCircle((int)x, (int)y, radius, highlight_color);
            DrawCircleLines((int)x, (int)y, radius, outline_color);
        } else if (obj->type == OBJECT_LINE) {
            // Highlight both endpoints
            float x2 = grid_to_pixel_x(&app->grid, obj->end_col, obj->end_row);
            float y2 = grid_to_pixel_y(&app->grid, obj->end_col, obj->end_row);
            float radius = obj->thickness / 2.0f + 4.0f;
            DrawCircle((int)x, (int)y, radius, highlight_color);
            DrawCircleLines((int)x, (int)y, radius, outline_color);
            DrawCircle((int)x2, (int)y2, radius, highlight_color);
            DrawCircleLines((int)x2, (int)y2, radius, outline_color);
        }
    }
}
// }}}

// {{{ render_drag_selection_rect
// Renders the drag selection rectangle while dragging (issue 1226)
static void render_drag_selection_rect(EditorApp* app) {
    if (!app || !app->is_drag_selecting) return;

    Vector2 mouse = GetMousePosition();
    float x1 = app->drag_start_x;
    float y1 = app->drag_start_y;
    float x2 = mouse.x;
    float y2 = mouse.y;

    // Normalize rectangle
    float min_x = (x1 < x2) ? x1 : x2;
    float max_x = (x1 > x2) ? x1 : x2;
    float min_y = (y1 < y2) ? y1 : y2;
    float max_y = (y1 > y2) ? y1 : y2;

    // Draw filled rectangle
    DrawRectangle((int)min_x, (int)min_y,
                  (int)(max_x - min_x), (int)(max_y - min_y),
                  (Color){100, 200, 255, 40});

    // Draw outline
    DrawRectangleLines((int)min_x, (int)min_y,
                       (int)(max_x - min_x), (int)(max_y - min_y),
                       (Color){100, 200, 255, 200});
}
// }}}

// {{{ render_canvas
static void render_canvas(EditorApp* app) {
    // Canvas background
    DrawRectangle((int)app->canvas_x, (int)app->canvas_y,
                  (int)app->canvas_width, (int)app->canvas_height, BG_COLOR);

    // Apply scroll offset to grid temporarily
    float original_origin_y = app->grid.origin_y;
    app->grid.origin_y += app->camera.offset.y;

    // Grid
    render_grid(&app->grid, app->canvas_x, app->canvas_y,
                app->canvas_width, app->canvas_height);

    // Guard rails (vertical lines on left and right edges)
    float rail_top = app->grid.origin_y;
    float rail_bottom = app->grid.origin_y + app->grid.rows * app->grid.cell_size;
    float left_rail_x = app->grid.origin_x;
    float right_rail_x = app->grid.origin_x + app->grid.cols * app->grid.cell_size;
    Color rail_color = (Color){100, 100, 120, 255};
    DrawLineEx((Vector2){left_rail_x, rail_top}, (Vector2){left_rail_x, rail_bottom}, 4.0f, rail_color);
    DrawLineEx((Vector2){right_rail_x, rail_top}, (Vector2){right_rail_x, rail_bottom}, 4.0f, rail_color);

    // Detected polygons (render behind objects) (issue 837)
    if (app->polygon_manager) {
        polygon_manager_render_all(app->polygon_manager);

        // Highlight selected polygon (issue 837)
        if (app->selected_polygon_index >= 0 &&
            app->selected_polygon_index < app->polygon_manager->polygon_count) {
            Polygon* sel = &app->polygon_manager->polygons[app->selected_polygon_index];
            // Draw polygon outline in highlight color
            for (int i = 0; i < sel->vertex_count; i++) {
                int j = (i + 1) % sel->vertex_count;
                DrawLineEx(sel->vertices[i], sel->vertices[j], 3.0f,
                          (Color){255, 255, 100, 255});  // Yellow highlight
            }
        }
    }

    // Board objects, zones, rotors, and tracks
    if (app->board) {
        render_board_objects(app->board, &app->grid);
        render_board_zones(app->board, &app->grid);
        render_board_rotors(app->board, &app->grid);  // Issue 901b
        render_board_tracks(app->board, &app->grid);  // Issue 902b

        // Highlight selected rotor (issue 901g)
        if (app->selected_rotor_index >= 0 &&
            app->selected_rotor_index < app->board->rotor_count) {
            Rotor* sel = &app->board->rotors[app->selected_rotor_index];
            float rx = grid_to_pixel_x(&app->grid, sel->col, sel->row);
            float ry = grid_to_pixel_y(&app->grid, sel->col, sel->row);
            // Draw yellow highlight ring around selected rotor
            DrawCircleLines((int)rx, (int)ry, 20.0f, (Color){255, 255, 100, 255});
            DrawCircleLines((int)rx, (int)ry, 22.0f, (Color){255, 255, 100, 180});
        }
    }

    // Selection highlights (issue 1226)
    render_selection_highlights(app);

    // Cursor preview
    render_cursor_preview(app);

    // Drag selection rectangle (issue 1226)
    render_drag_selection_rect(app);

    // Restore original grid origin
    app->grid.origin_y = original_origin_y;
}
// }}}

// {{{ render_cursor_preview
static void render_cursor_preview(EditorApp* app) {
    if (!app->hover_valid) return;
    if (app->mode != APP_MODE_PLACE) {
        // Erase mode: show red highlight
        render_grid_cursor(&app->grid, app->hover_col, app->hover_row, (Color){255, 50, 50, 80});
        return;
    }

    float x = grid_to_pixel_x(&app->grid, app->hover_col, app->hover_row);
    float y = grid_to_pixel_y(&app->grid, app->hover_col, app->hover_row);

    switch (app->tool) {
        case APP_TOOL_PEG:
            render_peg_preview(x, y, PEG_RADIUS);
            break;

        case APP_TOOL_LINE:
            if (app->line_tool.state == LINE_STATE_IDLE) {
                // Show start point preview
                DrawCircle((int)x, (int)y, 5, (Color){255, 255, 255, 150});
            } else if (app->line_tool.state == LINE_STATE_END) {
                // Recalculate start position from grid coords (fixes scroll offset issue 1212)
                float start_x = grid_to_pixel_x(&app->grid, app->line_tool.start_col, app->line_tool.start_row);
                float start_y = grid_to_pixel_y(&app->grid, app->line_tool.start_col, app->line_tool.start_row);
                // Show line from start to hover
                render_line_preview(start_x, start_y, x, y, app->line_tool.thickness);
            } else if (app->line_tool.state == LINE_STATE_THICKNESS) {
                // Recalculate positions from grid coords (fixes scroll offset issue 1212)
                float start_x = grid_to_pixel_x(&app->grid, app->line_tool.start_col, app->line_tool.start_row);
                float start_y = grid_to_pixel_y(&app->grid, app->line_tool.start_col, app->line_tool.start_row);
                float end_x = grid_to_pixel_x(&app->grid, app->line_tool.end_col, app->line_tool.end_row);
                float end_y = grid_to_pixel_y(&app->grid, app->line_tool.end_col, app->line_tool.end_row);
                // Show line with current thickness (confirming)
                render_line_preview(start_x, start_y, end_x, end_y, app->line_tool.thickness);
                // Show thickness indicator
                DrawText("Click to confirm, scroll to adjust",
                         (int)end_x + 10, (int)end_y - 20,
                         14, (Color){255, 255, 255, 200});
            }
            break;

        case APP_TOOL_PORTAL_ENTRY:
        case APP_TOOL_PORTAL_EXIT: {
            // Portal fills cell starting at intersection point (issue 1227)
            float w = DEFAULT_PORTAL_SIZE * app->grid.cell_size;
            float h = DEFAULT_PORTAL_SIZE * app->grid.cell_size;
            PortalDirection dir = (app->tool == APP_TOOL_PORTAL_ENTRY) ? PORTAL_ENTRY : PORTAL_EXIT;
            render_portal_preview(x, y, w, h, dir, app->portal_channel);
            break;
        }

        // Rotor preview (issue 901b)
        case APP_TOOL_ROTOR:
            render_rotor_preview(x, y, PEG_RADIUS);
            break;

        case APP_TOOL_TRACK:
            // Issue 902b: Track tool preview
            if (app->track_tool.state == TRACK_STATE_IDLE) {
                // Show start point preview
                DrawCircle((int)x, (int)y, 5, (Color){80, 200, 220, 150});
            } else if (app->track_tool.state == TRACK_STATE_END) {
                // Recalculate start position from grid coords
                float start_x = grid_to_pixel_x(&app->grid, app->track_tool.start_col, app->track_tool.start_row);
                float start_y = grid_to_pixel_y(&app->grid, app->track_tool.start_col, app->track_tool.start_row);
                // Show track from start to hover
                render_track_preview(start_x, start_y, x, y);
            }
            break;
    }
}
// }}}

// {{{ render_load_dialog
static void render_load_dialog(EditorApp* app) {
    // Dim background
    DrawRectangle(0, 0, app->screen_width, app->screen_height, (Color){0, 0, 0, 150});

    // Dialog box
    int dialog_w = 400;
    int dialog_h = 350;
    int dialog_x = (app->screen_width - dialog_w) / 2;
    int dialog_y = (app->screen_height - dialog_h) / 2;

    DrawRectangle(dialog_x, dialog_y, dialog_w, dialog_h, PANEL_COLOR);
    DrawRectangleLines(dialog_x, dialog_y, dialog_w, dialog_h, TEXT_COLOR);

    // Title
    DrawText("Load Board", dialog_x + 20, dialog_y + 15, 20, TEXT_COLOR);
    DrawLine(dialog_x + 10, dialog_y + 45, dialog_x + dialog_w - 10, dialog_y + 45, PANEL_BORDER);

    // Delete confirmation overlay (issue 1208)
    if (app->load_dialog.confirm_delete) {
        // Draw confirmation dialog on top
        int conf_w = 300;
        int conf_h = 100;
        int conf_x = (app->screen_width - conf_w) / 2;
        int conf_y = (app->screen_height - conf_h) / 2;

        DrawRectangle(conf_x, conf_y, conf_w, conf_h, (Color){60, 40, 40, 255});
        DrawRectangleLines(conf_x, conf_y, conf_w, conf_h, (Color){255, 100, 100, 255});

        // Get filename for display
        const char* path = app->load_dialog.file_list->filenames[app->load_dialog.delete_index];
        const char* name = strrchr(path, '/');
        name = name ? name + 1 : path;

        DrawText("Delete this file?", conf_x + 20, conf_y + 15, 18, TEXT_COLOR);
        DrawText(name, conf_x + 20, conf_y + 40, 14, (Color){255, 150, 150, 255});
        DrawText("Y = delete, N/ESC = cancel", conf_x + 20, conf_y + 70, 14, TEXT_DIM);
        return;
    }

    // File list
    if (!app->load_dialog.file_list || app->load_dialog.file_list->count == 0) {
        DrawText("No boards found in boards/", dialog_x + 20, dialog_y + 60, 16, TEXT_DIM);
    } else {
        int item_y = dialog_y + 55;
        int visible_count = 10;

        for (int i = 0; i < app->load_dialog.file_list->count && i < visible_count; i++) {
            int idx = i + app->load_dialog.scroll_offset;
            if (idx >= app->load_dialog.file_list->count) break;

            Color item_color = (idx == app->load_dialog.selected_index) ? BUTTON_ACTIVE : PANEL_COLOR;
            DrawRectangle(dialog_x + 10, item_y, dialog_w - 20, 24, item_color);

            // Extract filename from path
            const char* path = app->load_dialog.file_list->filenames[idx];
            const char* name = strrchr(path, '/');
            name = name ? name + 1 : path;

            DrawText(name, dialog_x + 20, item_y + 4, 16, TEXT_COLOR);
            item_y += 26;
        }
    }

    // Instructions (updated for vim keybinds - issue 1218)
    DrawText("j/k or UP/DOWN = select, l/ENTER = load, X/DEL = delete, h/ESC = cancel",
             dialog_x + 10, dialog_y + dialog_h - 35, 11, TEXT_DIM);
}
// }}}

// {{{ render_save_dialog
static void render_save_dialog(EditorApp* app) {
    // Dim background
    DrawRectangle(0, 0, app->screen_width, app->screen_height, (Color){0, 0, 0, 150});

    // Dialog box
    int dialog_w = 400;
    int dialog_h = 190;  // Taller to fit checkbox (issue 1224)
    int dialog_x = (app->screen_width - dialog_w) / 2;
    int dialog_y = (app->screen_height - dialog_h) / 2;

    DrawRectangle(dialog_x, dialog_y, dialog_w, dialog_h, PANEL_COLOR);
    DrawRectangleLines(dialog_x, dialog_y, dialog_w, dialog_h, TEXT_COLOR);

    // Title
    DrawText("Save Board", dialog_x + 20, dialog_y + 15, 20, TEXT_COLOR);
    DrawLine(dialog_x + 10, dialog_y + 45, dialog_x + dialog_w - 10, dialog_y + 45, PANEL_BORDER);

    // Filename label
    DrawText("Filename:", dialog_x + 20, dialog_y + 60, 16, TEXT_COLOR);

    // Text input box
    int input_x = dialog_x + 20;
    int input_y = dialog_y + 85;
    int input_w = dialog_w - 40;
    int input_h = 28;

    DrawRectangle(input_x, input_y, input_w, input_h, BG_COLOR);
    DrawRectangleLines(input_x, input_y, input_w, input_h, TEXT_COLOR);

    // Filename text with cursor
    char display_text[80];
    snprintf(display_text, sizeof(display_text), "%s.json", app->save_dialog.filename);
    DrawText(display_text, input_x + 5, input_y + 6, 16, TEXT_COLOR);

    // Blinking cursor at cursor_pos (issue 1214)
    if ((int)(GetTime() * 2) % 2 == 0) {
        // Measure text up to cursor position
        char temp[64];
        int pos = app->save_dialog.cursor_pos;
        if (pos > 63) pos = 63;
        strncpy(temp, app->save_dialog.filename, pos);
        temp[pos] = '\0';
        int cursor_x = input_x + 5 + MeasureText(temp, 16);
        DrawLine(cursor_x, input_y + 4, cursor_x, input_y + input_h - 4, TEXT_COLOR);
    }

    // In-progress checkbox (issue 1224)
    int checkbox_x = dialog_x + 20;
    int checkbox_y = input_y + input_h + 12;
    int checkbox_size = 18;

    // Checkbox box
    DrawRectangle(checkbox_x, checkbox_y, checkbox_size, checkbox_size, BG_COLOR);
    DrawRectangleLines(checkbox_x, checkbox_y, checkbox_size, checkbox_size, TEXT_COLOR);

    // Checkmark if checked
    if (app->save_dialog.in_progress) {
        DrawLine(checkbox_x + 3, checkbox_y + 9, checkbox_x + 7, checkbox_y + 13, TEXT_COLOR);
        DrawLine(checkbox_x + 7, checkbox_y + 13, checkbox_x + 15, checkbox_y + 5, TEXT_COLOR);
    }

    // Label
    DrawText("In-progress (exclude from random selection)",
             checkbox_x + checkbox_size + 8, checkbox_y + 2, 14, TEXT_COLOR);

    // Instructions
    DrawText("ENTER = save, TAB = toggle checkbox, ESC = cancel",
             dialog_x + 20, dialog_y + dialog_h - 25, 14, TEXT_DIM);
}
// }}}

// {{{ render_notification
static void render_notification(EditorApp* app) {
    if (app->notification_timer <= 0) return;

    // Fade out in last 0.5 seconds
    float alpha = 1.0f;
    if (app->notification_timer < 0.5f) {
        alpha = app->notification_timer / 0.5f;
    }

    int tw = MeasureText(app->notification, 20);
    int x = (app->screen_width - tw) / 2;
    int y = app->screen_height / 2 - 50;

    unsigned char a = (unsigned char)(alpha * 200);
    DrawRectangle(x - 20, y - 10, tw + 40, 40, (Color){0, 0, 0, a});
    DrawText(app->notification, x, y, 20, (Color){255, 255, 255, (unsigned char)(alpha * 255)});
}
// }}}

// =============================================================================
// Property Panel (issue 1211)
// =============================================================================

// {{{ render_slider
// Renders a single slider with label and value display.
// is_points: if true, shows point value mapping for blue channel (issue 1225)
static void render_slider(int x, int y, int width, unsigned char value,
                          const char* label, Color color_hint, int is_points) {
    // Label
    DrawText(label, x, y, 12, color_hint);

    int slider_y = y + 14;
    float ratio = (float)value / 255.0f;
    int fill_width = (int)(width * ratio);

    // Background
    DrawRectangle(x, slider_y, width, PROP_SLIDER_HEIGHT, (Color){30, 30, 40, 255});

    // Fill bar
    DrawRectangle(x, slider_y, fill_width, PROP_SLIDER_HEIGHT, color_hint);

    // Border
    DrawRectangleLines(x, slider_y, width, PROP_SLIDER_HEIGHT,
                       (Color){80, 80, 100, 255});

    // Value text - show percentage and (for points) mapped value (issue 1225)
    char val_text[24];
    int step = value_to_step(value);
    int percent = step * 10;
    if (is_points) {
        int points = POINT_VALUES[step];
        snprintf(val_text, sizeof(val_text), "%d%% (%dpts)", percent, points);
    } else {
        snprintf(val_text, sizeof(val_text), "%d%%", percent);
    }
    DrawText(val_text, x + width + 5, slider_y + 2, 12, TEXT_COLOR);
}
// }}}

// {{{ handle_object_selection
// Handles right-click to select an object for property editing.
// Supports shift-click to add/remove from multi-selection (issue 1226).
// Returns 1 if an object was selected, 0 otherwise.
static int handle_object_selection(EditorApp* app, float mouse_x, float mouse_y) {
    if (!app || !app->board) return 0;

    // Check if shift is held for multi-select
    int shift_held = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);

    // Convert screen coords to world coords
    Vector2 screen_pos = {mouse_x, mouse_y};
    Vector2 world_pos = GetScreenToWorld2D(screen_pos, app->camera);

    // Search through objects to find one under cursor
    for (int i = 0; i < app->board->object_count; i++) {
        BoardObject* obj = &app->board->objects[i];

        // Get object position in pixels
        float obj_x = grid_to_pixel_x(&app->grid, obj->col, obj->row);
        float obj_y = grid_to_pixel_y(&app->grid, obj->col, obj->row);

        float dx = world_pos.x - obj_x;
        float dy = world_pos.y - obj_y;
        float dist = sqrtf(dx * dx + dy * dy);

        // Click radius depends on object type
        float click_radius;
        if (obj->type == OBJECT_PEG) {
            click_radius = PEG_RADIUS + 5.0f;
        } else if (obj->type == OBJECT_LINE) {
            click_radius = obj->thickness / 2.0f + 10.0f;
        } else {
            click_radius = 20.0f;
        }

        if (dist <= click_radius) {
            // Object found under cursor
            // Clear polygon and rotor selection when selecting regular object
            app->selected_polygon_index = -1;
            app->show_polygon_panel = 0;
            app->selected_rotor_index = -1;
            app->show_rotor_panel = 0;

            if (shift_held) {
                // Shift-click: toggle in selection
                selection_toggle(app, i);
            } else {
                // Normal click: replace selection with single object
                selection_set_single(app, i);
            }
            return 1;
        }
    }

    // No object found - check if clicking inside a polygon (issue 837)
    if (app->polygon_manager && !shift_held) {
        Polygon* poly = polygon_manager_get_polygon_at(
            app->polygon_manager, world_pos.x, world_pos.y
        );
        if (poly) {
            // Find polygon index
            for (int i = 0; i < app->polygon_manager->polygon_count; i++) {
                if (&app->polygon_manager->polygons[i] == poly) {
                    app->selected_polygon_index = i;
                    app->show_polygon_panel = 1;
                    // Clear object selection when selecting polygon
                    selection_clear(app);
                    app->show_property_panel = 0;
                    app->selected_rotor_index = -1;
                    app->show_rotor_panel = 0;
                    return 1;
                }
            }
        }
    }

    // Check if clicking on a rotor (issue 901g)
    if (!shift_held) {
        for (int i = 0; i < app->board->rotor_count; i++) {
            Rotor* rotor = &app->board->rotors[i];
            float rotor_x = grid_to_pixel_x(&app->grid, rotor->col, rotor->row);
            float rotor_y = grid_to_pixel_y(&app->grid, rotor->col, rotor->row);

            float dx = world_pos.x - rotor_x;
            float dy = world_pos.y - rotor_y;
            float dist = sqrtf(dx * dx + dy * dy);

            // Rotor click radius (outer gear radius is ~15.6, use ~20 for easy clicking)
            if (dist <= 20.0f) {
                app->selected_rotor_index = i;
                app->show_rotor_panel = 1;
                // Clear other selections
                selection_clear(app);
                app->show_property_panel = 0;
                app->selected_polygon_index = -1;
                app->show_polygon_panel = 0;
                return 1;
            }
        }
    }

    // Clicked empty space
    if (!shift_held) {
        // Only deselect if shift not held
        selection_clear(app);
        // Also clear polygon and rotor selection
        app->selected_polygon_index = -1;
        app->show_polygon_panel = 0;
        app->selected_rotor_index = -1;
        app->show_rotor_panel = 0;
    }
    return 0;
}
// }}}

// {{{ render_property_panel
// Renders the property editing panel on the right side of screen.
// Supports multi-selection (issue 1226).
// Issue 839: Shows material selector in standard mode, sliders in advanced mode.
static void render_property_panel(EditorApp* app) {
    if (!app || !app->show_property_panel) return;
    if (!app->board) return;
    if (app->selection_count == 0) return;

    // Get the first selected object for display
    int first_idx = app->selected_indices[0];
    if (first_idx < 0 || first_idx >= app->board->object_count) return;
    BoardObject* obj = &app->board->objects[first_idx];

    int panel_x = app->screen_width - PROP_PANEL_WIDTH - PROP_PANEL_MARGIN;
    int panel_y = 100;

    // Panel height varies by mode (standard mode needs more space for material grid)
    int panel_h = app->advanced_mode ? PROP_PANEL_HEIGHT : (PROP_PANEL_HEIGHT + 40);

    // Background
    DrawRectangle(panel_x, panel_y, PROP_PANEL_WIDTH, panel_h,
                  (Color){40, 40, 50, 240});
    DrawRectangleLines(panel_x, panel_y, PROP_PANEL_WIDTH, panel_h,
                       (Color){100, 100, 120, 255});

    // Title - show count if multiple selected (issue 1226)
    char title[64];
    if (app->selection_count > 1) {
        snprintf(title, sizeof(title), "Multiple (%d)", app->selection_count);
    } else {
        const char* type_name = (obj->type == OBJECT_PEG) ? "Peg" : "Line";
        snprintf(title, sizeof(title), "%s Properties", type_name);
    }
    DrawText(title, panel_x + 10, panel_y + 10, 16, TEXT_COLOR);

    // Mode indicator (issue 839)
    const char* mode_label = app->advanced_mode ? "[ADV]" : "[STD]";
    Color mode_color = app->advanced_mode ? (Color){255, 200, 100, 255} : (Color){100, 200, 255, 255};
    DrawText(mode_label, panel_x + PROP_PANEL_WIDTH - 50, panel_y + 12, 12, mode_color);

    int content_x = panel_x + 10;
    int content_width = PROP_PANEL_WIDTH - 20;
    int y = panel_y + 35;

    if (app->advanced_mode) {
        // Advanced mode: RGB sliders (original behavior)
        // Color preview swatch
        Color preview = (Color){ obj->restitution, obj->friction, obj->point_bonus, 255 };
        int swatch_x = panel_x + PROP_PANEL_WIDTH - 40;
        DrawRectangle(swatch_x, panel_y + 8, 30, 20, preview);
        DrawRectangleLines(swatch_x, panel_y + 8, 30, 20, TEXT_COLOR);

        int slider_width = PROP_PANEL_WIDTH - 50;
        y += 5;

        // Restitution slider (R channel)
        render_slider(content_x, y, slider_width, obj->restitution,
                      "Restitution (R)", (Color){255, 100, 100, 255}, 0);
        y += PROP_SLIDER_HEIGHT + 25;

        // Friction slider (G channel)
        render_slider(content_x, y, slider_width, obj->friction,
                      "Friction (G)", (Color){100, 255, 100, 255}, 0);
        y += PROP_SLIDER_HEIGHT + 25;

        // Point Bonus slider (B channel)
        render_slider(content_x, y, slider_width, obj->point_bonus,
                      "Point Bonus (B)", (Color){100, 100, 255, 255}, 1);
    } else {
        // Standard mode: Material selector (issue 839)
        render_material_selector(app, content_x, y, content_width);
    }

    // Controls hint at bottom
    DrawText("F12: Toggle mode", panel_x + 10, panel_y + panel_h - 50,
             10, TEXT_DIM);
    DrawText("RClick: Select object", panel_x + 10, panel_y + panel_h - 35,
             10, TEXT_DIM);
    DrawText("ESC: Close panel", panel_x + 10, panel_y + panel_h - 20,
             10, TEXT_DIM);
}
// }}}

// {{{ render_polygon_panel
// Renders the polygon properties panel when a polygon is selected (issue 837).
// Shows polygon info and allows editing fill color and physics properties.
static void render_polygon_panel(EditorApp* app) {
    if (!app || !app->show_polygon_panel) return;
    if (!app->polygon_manager) return;
    if (app->selected_polygon_index < 0 ||
        app->selected_polygon_index >= app->polygon_manager->polygon_count) return;

    Polygon* poly = &app->polygon_manager->polygons[app->selected_polygon_index];

    // Panel dimensions (same position as property panel)
    int panel_x = app->screen_width - PROP_PANEL_WIDTH - PROP_PANEL_MARGIN;
    int panel_y = 100;
    int panel_h = 180;

    // Background
    DrawRectangle(panel_x, panel_y, PROP_PANEL_WIDTH, panel_h, PANEL_COLOR);
    DrawRectangleLines(panel_x, panel_y, PROP_PANEL_WIDTH, panel_h, PANEL_BORDER);

    // Title
    DrawText("Polygon", panel_x + 10, panel_y + 8, 14, TEXT_COLOR);

    // Polygon info
    char info[64];
    snprintf(info, sizeof(info), "Vertices: %d", poly->vertex_count);
    DrawText(info, panel_x + 10, panel_y + 30, 10, TEXT_DIM);

    snprintf(info, sizeof(info), "Triangles: %d", poly->triangle_count);
    DrawText(info, panel_x + 10, panel_y + 45, 10, TEXT_DIM);

    // Restitution slider
    int slider_y = panel_y + 70;
    float restitution = poly->restitution / 255.0f;
    snprintf(info, sizeof(info), "Bounce: %.0f%%", restitution * 100);
    DrawText(info, panel_x + 10, slider_y, 10, TEXT_COLOR);
    DrawRectangle(panel_x + 80, slider_y, 100, 12, (Color){60, 60, 80, 255});
    DrawRectangle(panel_x + 80, slider_y, (int)(100 * restitution), 12,
                  (Color){100, 200, 100, 255});

    // Friction slider
    slider_y += 25;
    float friction = poly->friction / 255.0f;
    snprintf(info, sizeof(info), "Friction: %.0f%%", friction * 100);
    DrawText(info, panel_x + 10, slider_y, 10, TEXT_COLOR);
    DrawRectangle(panel_x + 80, slider_y, 100, 12, (Color){60, 60, 80, 255});
    DrawRectangle(panel_x + 80, slider_y, (int)(100 * friction), 12,
                  (Color){200, 150, 100, 255});

    // Fill color preview
    slider_y += 25;
    DrawText("Fill:", panel_x + 10, slider_y, 10, TEXT_COLOR);
    DrawRectangle(panel_x + 80, slider_y, 100, 20, poly->fill_color);
    DrawRectangleLines(panel_x + 80, slider_y, 100, 20, TEXT_DIM);

    // Instructions
    DrawText("ESC: Deselect", panel_x + 10, panel_y + panel_h - 20,
             10, TEXT_DIM);
}
// }}}

// {{{ render_rotor_panel
// Renders the rotor properties panel when a rotor is selected (issue 901g).
// Shows direction toggle, speed slider, and connected object count.
static void render_rotor_panel(EditorApp* app) {
    if (!app || !app->show_rotor_panel) return;
    if (!app->board) return;
    if (app->selected_rotor_index < 0 ||
        app->selected_rotor_index >= app->board->rotor_count) return;

    Rotor* rotor = &app->board->rotors[app->selected_rotor_index];

    // Panel dimensions (same position as other property panels)
    int panel_x = app->screen_width - PROP_PANEL_WIDTH - PROP_PANEL_MARGIN;
    int panel_y = 100;
    int panel_h = 200;

    // Background
    DrawRectangle(panel_x, panel_y, PROP_PANEL_WIDTH, panel_h, PANEL_COLOR);
    DrawRectangleLines(panel_x, panel_y, PROP_PANEL_WIDTH, panel_h, PANEL_BORDER);

    // Title
    DrawText("Rotor", panel_x + 10, panel_y + 8, 14, TEXT_COLOR);

    char info[64];
    int y = panel_y + 30;

    // Direction toggle buttons
    int is_cw = (rotor->rotation_speed >= 0);
    int btn_width = 60;
    int btn_height = 22;
    int btn_x_cw = panel_x + 10;
    int btn_x_ccw = btn_x_cw + btn_width + 10;

    // CW button
    Color cw_bg = is_cw ? (Color){80, 150, 80, 255} : (Color){60, 60, 80, 255};
    Color cw_border = is_cw ? (Color){120, 200, 120, 255} : (Color){80, 80, 100, 255};
    DrawRectangle(btn_x_cw, y, btn_width, btn_height, cw_bg);
    DrawRectangleLines(btn_x_cw, y, btn_width, btn_height, cw_border);
    DrawText("CW", btn_x_cw + 20, y + 5, 12, TEXT_COLOR);

    // CCW button
    Color ccw_bg = !is_cw ? (Color){80, 150, 80, 255} : (Color){60, 60, 80, 255};
    Color ccw_border = !is_cw ? (Color){120, 200, 120, 255} : (Color){80, 80, 100, 255};
    DrawRectangle(btn_x_ccw, y, btn_width, btn_height, ccw_bg);
    DrawRectangleLines(btn_x_ccw, y, btn_width, btn_height, ccw_border);
    DrawText("CCW", btn_x_ccw + 16, y + 5, 12, TEXT_COLOR);

    y += btn_height + 15;

    // Speed slider
    float max_speed = 6.28f;  // ~1 rotation per second max
    float speed_abs = fabsf(rotor->rotation_speed);
    float speed_pct = speed_abs / max_speed;
    if (speed_pct > 1.0f) speed_pct = 1.0f;

    DrawText("Speed:", panel_x + 10, y, 10, TEXT_COLOR);
    y += 14;

    int slider_width = PROP_PANEL_WIDTH - 40;
    int slider_x = panel_x + 10;
    DrawRectangle(slider_x, y, slider_width, 12, (Color){60, 60, 80, 255});
    DrawRectangle(slider_x, y, (int)(slider_width * speed_pct), 12,
                  (Color){200, 180, 100, 255});
    DrawRectangleLines(slider_x, y, slider_width, 12, (Color){80, 80, 100, 255});

    snprintf(info, sizeof(info), "%.0f%%", speed_pct * 100);
    DrawText(info, slider_x + slider_width + 5, y, 10, TEXT_DIM);

    y += 25;

    // Connected objects count
    snprintf(info, sizeof(info), "Connected: %d objects", rotor->connection_count);
    DrawText(info, panel_x + 10, y, 10, TEXT_DIM);

    y += 20;

    // Current angle display
    float angle_deg = rotor->current_angle * (180.0f / 3.14159f);
    while (angle_deg < 0) angle_deg += 360.0f;
    while (angle_deg >= 360.0f) angle_deg -= 360.0f;
    snprintf(info, sizeof(info), "Angle: %.0f deg", angle_deg);
    DrawText(info, panel_x + 10, y, 10, TEXT_DIM);

    // Instructions
    DrawText("R: Reverse direction", panel_x + 10, panel_y + panel_h - 35,
             10, TEXT_DIM);
    DrawText("ESC: Deselect", panel_x + 10, panel_y + panel_h - 20,
             10, TEXT_DIM);
}
// }}}

// {{{ handle_rotor_panel_input
// Handles mouse input on the rotor panel (issue 901g).
// Returns 1 if input was consumed, 0 otherwise.
static int handle_rotor_panel_input(EditorApp* app) {
    if (!app || !app->show_rotor_panel) return 0;
    if (!app->board) return 0;
    if (app->selected_rotor_index < 0 ||
        app->selected_rotor_index >= app->board->rotor_count) return 0;

    Rotor* rotor = &app->board->rotors[app->selected_rotor_index];

    // Panel bounds
    int panel_x = app->screen_width - PROP_PANEL_WIDTH - PROP_PANEL_MARGIN;
    int panel_y = 100;
    int panel_h = 200;

    Vector2 mouse = GetMousePosition();

    // Handle R key for direction reversal when rotor selected
    if (IsKeyPressed(KEY_R)) {
        rotor->rotation_speed = -rotor->rotation_speed;
        app->modified = 1;
        return 1;
    }

    // Check if mouse is within panel bounds
    if (mouse.x < panel_x || mouse.x > panel_x + PROP_PANEL_WIDTH ||
        mouse.y < panel_y || mouse.y > panel_y + panel_h) {
        return 0;
    }

    // Direction button bounds
    int btn_width = 60;
    int btn_height = 22;
    int btn_y = panel_y + 30;
    int btn_x_cw = panel_x + 10;
    int btn_x_ccw = btn_x_cw + btn_width + 10;

    // Check CW button click
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        if (mouse.x >= btn_x_cw && mouse.x < btn_x_cw + btn_width &&
            mouse.y >= btn_y && mouse.y < btn_y + btn_height) {
            // Set direction to clockwise
            if (rotor->rotation_speed < 0) {
                rotor->rotation_speed = -rotor->rotation_speed;
                app->modified = 1;
            }
            return 1;
        }

        // Check CCW button click
        if (mouse.x >= btn_x_ccw && mouse.x < btn_x_ccw + btn_width &&
            mouse.y >= btn_y && mouse.y < btn_y + btn_height) {
            // Set direction to counter-clockwise
            if (rotor->rotation_speed >= 0) {
                rotor->rotation_speed = -rotor->rotation_speed;
                // Handle zero speed case
                if (rotor->rotation_speed == 0) {
                    rotor->rotation_speed = -0.01f;  // Small CCW value
                }
                app->modified = 1;
            }
            return 1;
        }
    }

    // Speed slider handling
    int slider_y = btn_y + btn_height + 29;  // y after buttons + label height
    int slider_width = PROP_PANEL_WIDTH - 40;
    int slider_x = panel_x + 10;
    int slider_height = 12;

    if (IsMouseButtonDown(MOUSE_LEFT_BUTTON)) {
        if (mouse.x >= slider_x && mouse.x <= slider_x + slider_width &&
            mouse.y >= slider_y && mouse.y <= slider_y + slider_height + 4) {
            // Calculate new speed from mouse position
            float t = (mouse.x - slider_x) / (float)slider_width;
            if (t < 0) t = 0;
            if (t > 1) t = 1;

            float max_speed = 6.28f;
            float new_speed = t * max_speed;

            // Preserve direction
            if (rotor->rotation_speed < 0) {
                rotor->rotation_speed = -new_speed;
            } else {
                rotor->rotation_speed = new_speed;
            }
            app->modified = 1;
            return 1;
        }
    }

    // Always consume input when over panel
    return 1;
}
// }}}

// {{{ handle_property_panel_input
// Handles mouse input on the property panel sliders.
// Applies changes to all selected objects (issue 1226).
// Issue 839: Handles both material selector (standard) and sliders (advanced).
// Returns 1 if input was consumed (clicked on panel), 0 otherwise.
static int handle_property_panel_input(EditorApp* app) {
    if (!app || !app->show_property_panel) return 0;
    if (!app->board) return 0;
    if (app->selection_count == 0) return 0;

    // Check if mouse is over the panel
    int panel_x = app->screen_width - PROP_PANEL_WIDTH - PROP_PANEL_MARGIN;
    int panel_y = 100;

    // Panel height varies by mode
    int panel_h = app->advanced_mode ? PROP_PANEL_HEIGHT : (PROP_PANEL_HEIGHT + 40);

    Vector2 mouse = GetMousePosition();

    // Check if mouse is within panel bounds
    if (mouse.x < panel_x || mouse.x > panel_x + PROP_PANEL_WIDTH ||
        mouse.y < panel_y || mouse.y > panel_y + panel_h) {
        return 0;
    }

    // Handle material selector in standard mode (issue 839)
    if (!app->advanced_mode) {
        return handle_material_selector_input(app, panel_x, panel_y) ? 1 : 1;
        // Always return 1 when over panel to prevent canvas interaction
    }

    // Advanced mode: handle slider input
    if (!IsMouseButtonDown(MOUSE_LEFT_BUTTON)) {
        return 1;  // Over panel but not clicking - still consume
    }

    int slider_width = PROP_PANEL_WIDTH - 50;
    int content_x = panel_x + 10;
    int slider_x = content_x;

    // Calculate slider Y positions (must match render function)
    int base_y = panel_y + 40;
    int slider_spacing = PROP_SLIDER_HEIGHT + 25;

    // Slider rectangles (the actual draggable areas)
    int slider_ys[3] = {
        base_y + 14,
        base_y + slider_spacing + 14,
        base_y + 2 * slider_spacing + 14
    };

    // Check each slider
    for (int i = 0; i < 3; i++) {
        Rectangle slider_rect = {
            (float)slider_x, (float)slider_ys[i],
            (float)slider_width, (float)PROP_SLIDER_HEIGHT
        };

        if (CheckCollisionPointRec(mouse, slider_rect)) {
            float ratio = (mouse.x - slider_x) / slider_width;
            if (ratio < 0.0f) ratio = 0.0f;
            if (ratio > 1.0f) ratio = 1.0f;
            // Snap to 10% increments (issue 1225)
            unsigned char raw_value = (unsigned char)(ratio * 255.0f);
            unsigned char snapped = snap_to_increment(raw_value);

            // Apply to all selected objects (issue 1226)
            for (int j = 0; j < app->selection_count; j++) {
                int idx = app->selected_indices[j];
                if (idx < 0 || idx >= app->board->object_count) continue;
                BoardObject* obj = &app->board->objects[idx];

                switch (i) {
                    case 0: obj->restitution = snapped; break;
                    case 1: obj->friction = snapped; break;
                    case 2: obj->point_bonus = snapped; break;
                }
            }
            app->modified = 1;
            return 1;
        }
    }

    return 1;  // Over panel, consumed
}
// }}}

// =============================================================================
// Material Selector (issue 839)
// =============================================================================

// Material button layout constants
#define MATERIAL_BTN_SIZE 45
#define MATERIAL_BTN_SPACING 5
#define MATERIAL_COLS 4

// {{{ render_material_selector
// Renders a grid of material buttons for standard mode.
// Shows current material highlighted, allows clicking to change.
static void render_material_selector(EditorApp* app, int x, int y, int width) {
    (void)width;  // Currently unused, may be used for future layout
    if (!app || !app->board || app->selection_count == 0) return;

    // Get first selected object to show current material
    int first_idx = app->selected_indices[0];
    if (first_idx < 0 || first_idx >= app->board->object_count) return;
    BoardObject* obj = &app->board->objects[first_idx];

    // Determine current material from object's RGB values
    int current_mat = find_closest_material(obj->restitution, obj->friction, obj->point_bonus);

    // Label
    DrawText("Material:", x, y, 14, TEXT_COLOR);
    y += 20;

    // Material grid (2 rows x 4 columns)
    Vector2 mouse = GetMousePosition();

    for (int i = 0; i < MATERIAL_COUNT; i++) {
        int col = i % MATERIAL_COLS;
        int row = i / MATERIAL_COLS;

        int btn_x = x + col * (MATERIAL_BTN_SIZE + MATERIAL_BTN_SPACING);
        int btn_y = y + row * (MATERIAL_BTN_SIZE + MATERIAL_BTN_SPACING);

        Rectangle btn_rect = { (float)btn_x, (float)btn_y,
                               (float)MATERIAL_BTN_SIZE, (float)MATERIAL_BTN_SIZE };

        // Button color based on selection state
        Color bg_color;
        if (i == current_mat) {
            bg_color = (Color){100, 150, 200, 255};  // Selected
        } else if (CheckCollisionPointRec(mouse, btn_rect)) {
            bg_color = (Color){80, 90, 110, 255};    // Hover
        } else {
            bg_color = (Color){50, 55, 70, 255};     // Normal
        }

        // Draw button background
        DrawRectangle(btn_x, btn_y, MATERIAL_BTN_SIZE, MATERIAL_BTN_SIZE, bg_color);

        // Draw material color swatch
        Color mat_color = material_get_display_color(i);
        int swatch_margin = 4;
        int swatch_size = MATERIAL_BTN_SIZE - swatch_margin * 2;
        DrawRectangle(btn_x + swatch_margin, btn_y + swatch_margin,
                      swatch_size, swatch_size - 14, mat_color);

        // Draw material name (abbreviated)
        const char* name = material_get_name(i);
        int text_width = MeasureText(name, 10);
        int text_x = btn_x + (MATERIAL_BTN_SIZE - text_width) / 2;
        DrawText(name, text_x, btn_y + MATERIAL_BTN_SIZE - 14, 10, TEXT_COLOR);

        // Button border
        Color border = (i == current_mat) ? (Color){150, 200, 255, 255} : (Color){70, 75, 90, 255};
        DrawRectangleLines(btn_x, btn_y, MATERIAL_BTN_SIZE, MATERIAL_BTN_SIZE, border);
    }

    // Show current material description below grid
    int desc_y = y + 2 * (MATERIAL_BTN_SIZE + MATERIAL_BTN_SPACING) + 5;
    const char* desc = material_get_description(current_mat);
    DrawText(desc, x, desc_y, 12, TEXT_DIM);

    // Show physics values
    int values_y = desc_y + 18;
    char values_text[64];
    snprintf(values_text, sizeof(values_text), "R:%d G:%d B:%d",
             obj->restitution, obj->friction, obj->point_bonus);
    DrawText(values_text, x, values_y, 10, TEXT_DIM);
}
// }}}

// {{{ handle_material_selector_input
// Handles clicks on material buttons.
// Returns 1 if input was consumed, 0 otherwise.
static int handle_material_selector_input(EditorApp* app, int panel_x, int panel_y) {
    if (!app || app->advanced_mode) return 0;  // Only in standard mode
    if (!app->board || app->selection_count == 0) return 0;

    Vector2 mouse = GetMousePosition();

    // Calculate button grid position (must match render function)
    int grid_x = panel_x + 10;
    int grid_y = panel_y + 35 + 20;  // After "Material:" label

    // Check each material button
    for (int i = 0; i < MATERIAL_COUNT; i++) {
        int col = i % MATERIAL_COLS;
        int row = i / MATERIAL_COLS;

        int btn_x = grid_x + col * (MATERIAL_BTN_SIZE + MATERIAL_BTN_SPACING);
        int btn_y = grid_y + row * (MATERIAL_BTN_SIZE + MATERIAL_BTN_SPACING);

        Rectangle btn_rect = { (float)btn_x, (float)btn_y,
                               (float)MATERIAL_BTN_SIZE, (float)MATERIAL_BTN_SIZE };

        if (CheckCollisionPointRec(mouse, btn_rect)) {
            if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
                // Apply material to all selected objects
                for (int j = 0; j < app->selection_count; j++) {
                    int idx = app->selected_indices[j];
                    if (idx < 0 || idx >= app->board->object_count) continue;
                    BoardObject* obj = &app->board->objects[idx];

                    material_apply_to_object(i, &obj->restitution, &obj->friction, NULL);
                }
                app->modified = 1;

                // Show notification with material name
                char notify_text[64];
                snprintf(notify_text, sizeof(notify_text), "Material: %s", material_get_name(i));
                editor_app_notify(app, notify_text, 1.0f);
            }
            return 1;  // Consumed (hovering over button)
        }
    }

    return 0;
}
// }}}

// =============================================================================
// Material Mode (issue 839)
// =============================================================================

// {{{ editor_app_set_advanced_mode
void editor_app_set_advanced_mode(EditorApp* app, int advanced) {
    if (!app) return;
    app->advanced_mode = advanced ? 1 : 0;
}
// }}}

// {{{ editor_app_toggle_advanced_mode
int editor_app_toggle_advanced_mode(EditorApp* app) {
    if (!app) return 0;
    app->advanced_mode = !app->advanced_mode;
    return app->advanced_mode;
}
// }}}
