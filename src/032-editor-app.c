// src/032-editor-app.c
// Standalone editor application implementation
// Handles editor state, input, and coordinates rendering

#include "031-editor-app.h"
#include "034-object-render.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// =============================================================================
// Constants
// =============================================================================

#define TOOLBAR_HEIGHT 80
#define SIDEBAR_WIDTH 200
#define FOOTER_HEIGHT 30
#define EDITOR_GRID_COLS 12
#define EDITOR_GRID_ROWS 20
#define EDITOR_CELL_SIZE 50
#define PEG_RADIUS 12.0f
#define DEFAULT_LINE_THICKNESS 10.0f
#define MIN_LINE_THICKNESS 4.0f
#define MAX_LINE_THICKNESS 30.0f
#define DEFAULT_PORTAL_SIZE 2  // Grid cells

// Colors
#define BG_COLOR (Color){30, 30, 40, 255}
#define PANEL_COLOR (Color){40, 40, 55, 255}
#define PANEL_BORDER (Color){60, 60, 80, 255}
#define BUTTON_COLOR (Color){60, 70, 90, 255}
#define BUTTON_HOVER (Color){80, 90, 110, 255}
#define BUTTON_ACTIVE (Color){100, 120, 160, 255}
#define TEXT_COLOR (Color){200, 200, 220, 255}
#define TEXT_DIM (Color){120, 120, 140, 255}

// =============================================================================
// Forward Declarations
// =============================================================================

static void handle_input(EditorApp* app);
static void handle_canvas_click(EditorApp* app);
static void handle_tool_selection(EditorApp* app);
static void handle_line_tool(EditorApp* app);
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

// =============================================================================
// Lifecycle
// =============================================================================

// {{{ editor_app_create
EditorApp* editor_app_create(int screen_width, int screen_height) {
    EditorApp* app = (EditorApp*)calloc(1, sizeof(EditorApp));
    if (!app) return NULL;

    app->screen_width = screen_width;
    app->screen_height = screen_height;

    // Create empty board
    app->board = board_data_create(EDITOR_GRID_COLS, EDITOR_GRID_ROWS, EDITOR_CELL_SIZE);
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

    // Setup camera (1:1, no zoom initially)
    app->camera.zoom = 1.0f;
    app->camera.rotation = 0.0f;
    app->camera.offset = (Vector2){0, 0};
    app->camera.target = (Vector2){0, 0};

    // Calculate canvas bounds and setup grid
    editor_app_resize(app, screen_width, screen_height);

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

    free(app);
}
// }}}

// =============================================================================
// Update and Render
// =============================================================================

// {{{ editor_app_update
void editor_app_update(EditorApp* app) {
    if (!app) return;

    // Update notification timer
    if (app->notification_timer > 0) {
        app->notification_timer -= GetFrameTime();
    }

    // Handle input
    handle_input(app);

    // Update hover position
    update_hover(app);
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

    // Calculate canvas area (between toolbar, sidebar, footer)
    app->canvas_x = 0;
    app->canvas_y = TOOLBAR_HEIGHT;
    app->canvas_width = width - SIDEBAR_WIDTH;
    app->canvas_height = height - TOOLBAR_HEIGHT - FOOTER_HEIGHT;

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

    editor_app_notify(app, "Board loaded", 2.0f);
    return 1;
}
// }}}

// {{{ editor_app_save
int editor_app_save(EditorApp* app) {
    if (!app || !app->board) return 0;

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

    app->board = board_data_create(EDITOR_GRID_COLS, EDITOR_GRID_ROWS, EDITOR_CELL_SIZE);
    app->has_filename = 0;
    app->filename[0] = '\0';
    app->modified = 0;
    app->selected_object_index = -1;

    setup_grid(app);
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
        if (IsKeyPressed(KEY_ESCAPE)) {
            close_load_dialog(app);
            return;
        }

        // Navigate file list
        if (IsKeyPressed(KEY_UP) && app->load_dialog.selected_index > 0) {
            app->load_dialog.selected_index--;
        }
        if (IsKeyPressed(KEY_DOWN) && app->load_dialog.file_list &&
            app->load_dialog.selected_index < app->load_dialog.file_list->count - 1) {
            app->load_dialog.selected_index++;
        }

        // Load selected file
        if (IsKeyPressed(KEY_ENTER) && app->load_dialog.file_list &&
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

    // Quit on ESC
    if (IsKeyPressed(KEY_ESCAPE)) {
        app->should_quit = 1;
        return;
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

    // Canvas interaction
    if (app->hover_valid && IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        handle_canvas_click(app);
    }

    // Line tool: right-click cancels
    if (app->tool == APP_TOOL_LINE && IsMouseButtonPressed(MOUSE_RIGHT_BUTTON)) {
        app->line_tool.state = LINE_STATE_IDLE;
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

            // Clamp scroll to reasonable bounds
            float max_scroll = 200.0f;
            float min_scroll = -app->grid.height + app->canvas_height - 200.0f;
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
    }
    if (IsKeyPressed(KEY_TWO)) {
        app->tool = APP_TOOL_LINE;
        app->line_tool.state = LINE_STATE_IDLE;
    }
    if (IsKeyPressed(KEY_THREE)) {
        app->tool = APP_TOOL_PORTAL_ENTRY;
        app->line_tool.state = LINE_STATE_IDLE;
    }
    if (IsKeyPressed(KEY_FOUR)) {
        app->tool = APP_TOOL_PORTAL_EXIT;
        app->line_tool.state = LINE_STATE_IDLE;
    }
}
// }}}

// {{{ handle_canvas_click
static void handle_canvas_click(EditorApp* app) {
    if (app->mode == APP_MODE_PLACE) {
        if (app->tool == APP_TOOL_LINE) {
            handle_line_tool(app);
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
            app->line_tool.state = LINE_STATE_IDLE;
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
    }
}
// }}}

// {{{ erase_object
static void erase_object(EditorApp* app) {
    if (!app->hover_valid) return;

    // Try to remove object at hover position
    if (board_data_remove_object_at(app->board, app->hover_col, app->hover_row)) {
        app->modified = 1;
        return;
    }

    // Try to remove zone at hover position
    if (board_data_remove_zone_at(app->board, app->hover_col, app->hover_row)) {
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

    // Confirm on Enter
    if (IsKeyPressed(KEY_ENTER)) {
        if (strlen(app->save_dialog.filename) > 0) {
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

    // Handle text input
    int key = GetCharPressed();
    while (key > 0) {
        // Only allow alphanumeric, dash, underscore
        if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') ||
            (key >= '0' && key <= '9') || key == '-' || key == '_') {
            int len = (int)strlen(app->save_dialog.filename);
            if (len < 63) {
                app->save_dialog.filename[len] = (char)key;
                app->save_dialog.filename[len + 1] = '\0';
                app->save_dialog.cursor_pos = len + 1;
            }
        }
        key = GetCharPressed();
    }

    // Backspace
    if (IsKeyPressed(KEY_BACKSPACE) || IsKeyPressedRepeat(KEY_BACKSPACE)) {
        int len = (int)strlen(app->save_dialog.filename);
        if (len > 0) {
            app->save_dialog.filename[len - 1] = '\0';
            app->save_dialog.cursor_pos = len - 1;
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

    // Calculate cell size to fit canvas
    float available_width = app->canvas_width - 40;  // Margin
    float available_height = app->canvas_height - 40;

    float cell_w = available_width / app->board->grid_cols;
    float cell_h = available_height / app->board->grid_rows;
    float cell_size = (cell_w < cell_h) ? cell_w : cell_h;

    // Limit cell size
    if (cell_size < 20) cell_size = 20;
    if (cell_size > 80) cell_size = 80;

    // Center grid in canvas
    float grid_width = app->board->grid_cols * cell_size;
    float grid_height = app->board->grid_rows * cell_size;
    float origin_x = app->canvas_x + (app->canvas_width - grid_width) / 2;
    float origin_y = app->canvas_y + (app->canvas_height - grid_height) / 2;

    app->grid = grid_create(app->board->grid_cols, app->board->grid_rows,
                            cell_size, origin_x, origin_y);
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

    // Tool buttons
    int btn_x = 200;
    int btn_y = 10;
    int btn_w = 80;
    int btn_h = 30;
    int btn_spacing = 10;

    const char* tools[] = {"1:Peg", "2:Line", "3:In", "4:Out"};
    EditorAppTool tool_values[] = {APP_TOOL_PEG, APP_TOOL_LINE, APP_TOOL_PORTAL_ENTRY, APP_TOOL_PORTAL_EXIT};

    for (int i = 0; i < 4; i++) {
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

    // Current tool info
    int info_y = y + 55;
    const char* tool_names[] = {"Peg", "Line", "Portal Entry", "Portal Exit"};
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

    info_y += 20;
    snprintf(stat_text, sizeof(stat_text), "Grid: %dx%d",
             app->board ? app->board->grid_cols : 0,
             app->board ? app->board->grid_rows : 0);
    DrawText(stat_text, x + 15, info_y, 14, TEXT_COLOR);
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

    // Board objects and zones
    if (app->board) {
        render_board_objects(app->board, &app->grid);
        render_board_zones(app->board, &app->grid);
    }

    // Cursor preview
    render_cursor_preview(app);

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
                // Show line from start to hover
                render_line_preview(app->line_tool.start_x, app->line_tool.start_y,
                                   x, y, app->line_tool.thickness);
            } else if (app->line_tool.state == LINE_STATE_THICKNESS) {
                // Show line with current thickness (confirming)
                render_line_preview(app->line_tool.start_x, app->line_tool.start_y,
                                   app->line_tool.end_x, app->line_tool.end_y,
                                   app->line_tool.thickness);
                // Show thickness indicator
                DrawText("Click to confirm, scroll to adjust",
                         (int)app->line_tool.end_x + 10, (int)app->line_tool.end_y - 20,
                         14, (Color){255, 255, 255, 200});
            }
            break;

        case APP_TOOL_PORTAL_ENTRY:
        case APP_TOOL_PORTAL_EXIT: {
            float w = DEFAULT_PORTAL_SIZE * app->grid.cell_size;
            float h = DEFAULT_PORTAL_SIZE * app->grid.cell_size;
            PortalDirection dir = (app->tool == APP_TOOL_PORTAL_ENTRY) ? PORTAL_ENTRY : PORTAL_EXIT;
            render_portal_preview(x - w/2, y - h/2, w, h, dir, app->portal_channel);
            break;
        }
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

    // Instructions
    DrawText("UP/DOWN = select, ENTER = load, ESC = cancel",
             dialog_x + 20, dialog_y + dialog_h - 35, 14, TEXT_DIM);
}
// }}}

// {{{ render_save_dialog
static void render_save_dialog(EditorApp* app) {
    // Dim background
    DrawRectangle(0, 0, app->screen_width, app->screen_height, (Color){0, 0, 0, 150});

    // Dialog box
    int dialog_w = 400;
    int dialog_h = 150;
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

    // Blinking cursor
    if ((int)(GetTime() * 2) % 2 == 0) {
        int cursor_x = input_x + 5 + MeasureText(app->save_dialog.filename, 16);
        DrawLine(cursor_x, input_y + 4, cursor_x, input_y + input_h - 4, TEXT_COLOR);
    }

    // Instructions
    DrawText("ENTER = save, ESC = cancel",
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
