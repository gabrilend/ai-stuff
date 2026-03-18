// src/025-editor.c
// Board editor implementation
// Handles mode toggle, grid overlay, cursor preview, and UI rendering
//
// External functions: editor_create, editor_destroy, editor_toggle,
//                     editor_is_active, editor_handle_input,
//                     editor_render_grid, editor_render_ui, editor_render_cursor

#include "024-editor.h"
#include "004-world.h"
#include "028-portal.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>

// =============================================================================
// Visual Constants
// =============================================================================

// Mode indicator colors
#define MODE_PLACE_COLOR GREEN
#define MODE_ERASE_COLOR RED
#define MODE_BG_COLOR (Color){0, 0, 0, 180}

// Cursor preview colors
#define CURSOR_VALID_COLOR (Color){100, 255, 100, 150}
#define CURSOR_INVALID_COLOR (Color){255, 100, 100, 150}
#define CURSOR_ERASE_COLOR (Color){255, 50, 50, 200}

// UI positioning
#define MODE_INDICATOR_Y 10
#define MODE_INDICATOR_FONT_SIZE 20
#define HELP_TEXT_Y 40
#define HELP_TEXT_FONT_SIZE 14

// Palette colors
#define PALETTE_BG_COLOR (Color){30, 30, 40, 220}
#define PALETTE_SELECTED_COLOR (Color){80, 120, 200, 255}
#define PALETTE_HOVER_COLOR (Color){60, 60, 80, 255}

// =============================================================================
// Palette Data
// =============================================================================

// {{{ typedef struct PaletteItem
typedef struct PaletteItem {
    EditorToolType tool_type;    // Object or zone placement
    ObjectType object_type;      // For EDITOR_TOOL_OBJECT
    PortalDirection portal_dir;  // For EDITOR_TOOL_ZONE_PORTAL
    const char* name;
    const char* shortcut;
    Color preview_color;
} PaletteItem;
// }}}

// {{{ palette_items array
static PaletteItem palette_items[] = {
    { EDITOR_TOOL_OBJECT,      OBJECT_PEG,  PORTAL_ENTRY, "Peg",       "1", (Color){180, 180, 200, 255} },
    { EDITOR_TOOL_OBJECT,      OBJECT_LINE, PORTAL_ENTRY, "Line",      "2", (Color){200, 150, 100, 255} },
    { EDITOR_TOOL_ZONE_PORTAL, OBJECT_PEG,  PORTAL_ENTRY, "Portal In", "3", (Color){50, 100, 255, 255} },
    { EDITOR_TOOL_ZONE_PORTAL, OBJECT_PEG,  PORTAL_EXIT,  "Portal Out","4", (Color){255, 150, 50, 255} }
};
#define PALETTE_ITEM_COUNT 4
// }}}

// Forward declaration for palette click handler (defined in Palette Rendering section)
static int editor_handle_palette_click(EditorState* editor);

// Forward declarations for line tool functions (defined in Line Tool Functions section)
static void line_tool_handle_cancel(EditorState* editor);
static void line_tool_update_thickness(EditorState* editor, Vector2 mouse_world);
static int line_tool_handle_click(EditorState* editor);
static void line_tool_render_preview(EditorState* editor);
static void line_tool_render_ui(EditorState* editor);

// Forward declarations for load dialog functions
static void editor_handle_load_dialog_input(EditorState* editor);
static void editor_render_load_dialog(EditorState* editor);

// =============================================================================
// Editor Lifecycle
// =============================================================================

// {{{ editor_create
EditorState* editor_create(struct World* world) {
    EditorState* editor = (EditorState*)malloc(sizeof(EditorState));
    if (!editor) {
        fprintf(stderr, "ERROR: Failed to allocate editor state\n");
        return NULL;
    }

    editor->mode = EDITOR_MODE_DISABLED;
    editor->selected_object_type = OBJECT_PEG;
    editor->hover_col = 0;
    editor->hover_row = 0;
    editor->hover_valid = 0;
    editor->show_grid = 0;
    editor->board_data = NULL;
    editor->board_modified = 0;
    editor->world = world;

    // Initialize grid with defaults
    editor->grid = grid_create_default();

    // Screen dimensions (will be updated)
    editor->screen_width = 800;
    editor->screen_height = 600;

    // Initialize line tool state
    editor->line_tool.state = LINE_TOOL_IDLE;
    editor->line_tool.start_col = 0;
    editor->line_tool.start_row = 0;
    editor->line_tool.end_col = 0;
    editor->line_tool.end_row = 0;
    editor->line_tool.start_x = 0;
    editor->line_tool.start_y = 0;
    editor->line_tool.end_x = 0;
    editor->line_tool.end_y = 0;
    editor->line_tool.thickness = 10.0f;
    editor->line_tool.min_thickness = 6.0f;
    editor->line_tool.max_thickness = 40.0f;

    // Initialize save state
    editor->current_filename[0] = '\0';
    editor->has_filename = 0;
    editor->notification_text[0] = '\0';
    editor->notification_timer = 0.0f;

    // Initialize load dialog state
    editor->show_load_dialog = 0;
    editor->available_boards = NULL;
    editor->load_selected_index = 0;
    editor->load_scroll_offset = 0;

    // Initialize portal tool state
    editor->tool_type = EDITOR_TOOL_OBJECT;
    editor->portal_direction = PORTAL_ENTRY;
    editor->portal_channel = 1;

    // Setup grid based on world if provided
    if (world) {
        editor_setup_grid(editor, world);
    }

    return editor;
}
// }}}

// {{{ editor_destroy
void editor_destroy(EditorState* editor) {
    if (!editor) return;

    // Free board file list if present
    if (editor->available_boards) {
        board_file_list_destroy(editor->available_boards);
    }

    // Board data is not owned by editor, don't free it
    free(editor);
}
// }}}

// =============================================================================
// Mode Control
// =============================================================================

// {{{ editor_toggle
void editor_toggle(EditorState* editor) {
    if (!editor) return;

    if (editor->mode == EDITOR_MODE_DISABLED) {
        // Enter editor mode
        editor->mode = EDITOR_MODE_PLACE;
        editor->show_grid = 1;
        printf("Editor mode enabled (PLACE)\n");
    } else {
        // Exit editor mode
        editor->mode = EDITOR_MODE_DISABLED;
        editor->show_grid = 0;
        editor->hover_valid = 0;
        printf("Editor mode disabled\n");
    }
}
// }}}

// {{{ editor_is_active
int editor_is_active(EditorState* editor) {
    if (!editor) return 0;
    return editor->mode != EDITOR_MODE_DISABLED;
}
// }}}

// {{{ editor_toggle_submode
void editor_toggle_submode(EditorState* editor) {
    if (!editor || editor->mode == EDITOR_MODE_DISABLED) return;

    if (editor->mode == EDITOR_MODE_PLACE) {
        editor->mode = EDITOR_MODE_ERASE;
        printf("Editor submode: ERASE\n");
    } else {
        editor->mode = EDITOR_MODE_PLACE;
        printf("Editor submode: PLACE\n");
    }
}
// }}}

// =============================================================================
// Input Handling
// =============================================================================

// {{{ editor_handle_input
void editor_handle_input(EditorState* editor, Camera2D camera) {
    if (!editor || editor->mode == EDITOR_MODE_DISABLED) return;

    // Toggle place/erase mode with TAB
    if (IsKeyPressed(KEY_TAB)) {
        editor_toggle_submode(editor);
    }

    // Toggle grid visibility with G
    if (IsKeyPressed(KEY_G)) {
        editor->show_grid = !editor->show_grid;
        printf("Grid visibility: %s\n", editor->show_grid ? "ON" : "OFF");
    }

    // Object/tool selection with number keys
    if (IsKeyPressed(KEY_ONE)) {
        editor->tool_type = EDITOR_TOOL_OBJECT;
        editor->selected_object_type = OBJECT_PEG;
        printf("Selected: PEG\n");
    }
    if (IsKeyPressed(KEY_TWO)) {
        editor->tool_type = EDITOR_TOOL_OBJECT;
        editor->selected_object_type = OBJECT_LINE;
        printf("Selected: LINE\n");
    }
    if (IsKeyPressed(KEY_THREE)) {
        editor->tool_type = EDITOR_TOOL_ZONE_PORTAL;
        editor->portal_direction = PORTAL_ENTRY;
        printf("Selected: PORTAL ENTRY (ch %d)\n", editor->portal_channel);
    }
    if (IsKeyPressed(KEY_FOUR)) {
        editor->tool_type = EDITOR_TOOL_ZONE_PORTAL;
        editor->portal_direction = PORTAL_EXIT;
        printf("Selected: PORTAL EXIT (ch %d)\n", editor->portal_channel);
    }

    // Portal channel selection with scroll wheel when portal tool is active
    if (editor->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
        int wheel = GetMouseWheelMove();
        if (wheel != 0 && !editor_is_over_ui(editor)) {
            editor->portal_channel += wheel;
            if (editor->portal_channel < 1) editor->portal_channel = 1;
            if (editor->portal_channel > 16) editor->portal_channel = 16;
            printf("Portal channel: %d\n", editor->portal_channel);
        }
    }

    // Delete/Backspace to remove object at cursor (works in any mode)
    if (IsKeyPressed(KEY_DELETE) || IsKeyPressed(KEY_BACKSPACE)) {
        if (editor->hover_valid && editor->board_data) {
            int removed = board_data_remove_object_at(editor->board_data,
                                                       editor->hover_col,
                                                       editor->hover_row);
            if (removed) {
                printf("Deleted object at (%d, %d)\n",
                       editor->hover_col, editor->hover_row);
                editor->board_modified = 1;
                editor_sync_to_world(editor);
            }
        }
    }

    // Ctrl+S to save board
    if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_S)) {
        editor_save_board(editor);
    }

    // Ctrl+O to open load dialog
    if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_O)) {
        editor_open_load_dialog(editor);
    }

    // Handle load dialog input if open (consumes all other input)
    if (editor->show_load_dialog) {
        editor_handle_load_dialog_input(editor);
        return;  // Don't process other input while dialog is open
    }

    // Handle palette clicks (consumes click if on palette)
    int palette_clicked = editor_handle_palette_click(editor);

    // Track cursor position in grid coordinates
    Vector2 mouse_screen = GetMousePosition();
    Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);

    // Convert to grid coordinates
    editor->hover_col = pixel_to_grid_col(&editor->grid, mouse_world.x);
    editor->hover_row = pixel_to_grid_row(&editor->grid, mouse_world.y);

    // Check if hover is within grid bounds
    editor->hover_valid = grid_pixel_in_bounds(&editor->grid, mouse_world.x, mouse_world.y);

    // Handle line tool escape (cancel operation)
    line_tool_handle_cancel(editor);

    // Update line tool thickness during width setting phase
    line_tool_update_thickness(editor, mouse_world);

    // Handle object placement/removal (only if palette wasn't clicked)
    if (!palette_clicked) {
        if (editor->mode == EDITOR_MODE_PLACE) {
            // Check if line tool handles the click first
            if (editor->selected_object_type == OBJECT_LINE) {
                if (line_tool_handle_click(editor)) {
                    // Line tool consumed the click
                    if (editor->board_modified) {
                        editor_sync_to_world(editor);
                    }
                }
            } else {
                // Normal placement for non-line objects
                if (editor_handle_placement(editor)) {
                    editor_sync_to_world(editor);
                }
            }
        } else if (editor->mode == EDITOR_MODE_ERASE) {
            if (editor_handle_erase(editor)) {
                editor_sync_to_world(editor);
            }
        }
    }
}
// }}}

// =============================================================================
// Palette Rendering
// =============================================================================

// {{{ editor_render_palette_icon
// Renders a preview icon for a palette item
static void editor_render_palette_icon(PaletteItem* item, int x, int y, int size) {
    int cx = x + size / 2;
    int cy = y + size / 2;
    int half = size / 3;

    if (item->tool_type == EDITOR_TOOL_OBJECT) {
        // Object tools
        switch (item->object_type) {
            case OBJECT_PEG:
                // Circle
                DrawCircle(cx, cy, (float)half, item->preview_color);
                DrawCircleLines(cx, cy, (float)half, WHITE);
                break;

            case OBJECT_LINE:
                // Diagonal line with rounded endpoints
                DrawLineEx(
                    (Vector2){(float)(cx - half), (float)(cy - half)},
                    (Vector2){(float)(cx + half), (float)(cy + half)},
                    4, item->preview_color
                );
                // Ball joints at endpoints
                DrawCircle(cx - half, cy - half, 4, item->preview_color);
                DrawCircle(cx + half, cy + half, 4, item->preview_color);
                break;

            default:
                DrawText("?", cx - 5, cy - 8, 16, RED);
                break;
        }
    } else if (item->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
        // Portal zone preview - rectangle with direction indicator
        int rect_half = half - 2;
        DrawRectangle(cx - rect_half, cy - rect_half, rect_half * 2, rect_half * 2,
                     item->preview_color);
        DrawRectangleLines(cx - rect_half, cy - rect_half, rect_half * 2, rect_half * 2,
                          WHITE);

        // Direction indicator (arrow)
        if (item->portal_dir == PORTAL_ENTRY) {
            // Inward arrow (V pointing down)
            DrawTriangle(
                (Vector2){(float)cx, (float)(cy + 6)},       // Bottom
                (Vector2){(float)(cx + 6), (float)(cy - 4)}, // Top right
                (Vector2){(float)(cx - 6), (float)(cy - 4)}, // Top left
                WHITE
            );
        } else {
            // Outward arrow (^ pointing up)
            DrawTriangle(
                (Vector2){(float)cx, (float)(cy - 6)},       // Top
                (Vector2){(float)(cx - 6), (float)(cy + 4)}, // Bottom left
                (Vector2){(float)(cx + 6), (float)(cy + 4)}, // Bottom right
                WHITE
            );
        }
    }
}
// }}}

// {{{ editor_render_palette
// Renders the object palette on the left side of the screen
static void editor_render_palette(EditorState* editor) {
    if (!editor) return;

    int x = PALETTE_X;
    int y = PALETTE_Y;
    int width = PALETTE_ITEM_SIZE + 20;
    int height = PALETTE_ITEM_COUNT * (PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING) + 35;

    // Background panel
    DrawRectangle(x, y, width, height, PALETTE_BG_COLOR);
    DrawRectangleLines(x, y, width, height, (Color){80, 80, 100, 255});

    // Title
    DrawText("Objects", x + 5, y + 5, 12, LIGHTGRAY);

    // Items
    int item_y = y + 25;
    for (int i = 0; i < PALETTE_ITEM_COUNT; i++) {
        PaletteItem* item = &palette_items[i];
        int item_x = x + 10;

        // Selection/hover highlight
        Rectangle item_rect = { (float)item_x, (float)item_y,
                                (float)PALETTE_ITEM_SIZE, (float)PALETTE_ITEM_SIZE };
        // Check if this item is selected based on tool type and specific settings
        int is_selected = 0;
        if (item->tool_type == EDITOR_TOOL_OBJECT && editor->tool_type == EDITOR_TOOL_OBJECT) {
            is_selected = (editor->selected_object_type == item->object_type);
        } else if (item->tool_type == EDITOR_TOOL_ZONE_PORTAL && editor->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
            is_selected = (editor->portal_direction == item->portal_dir);
        }
        int is_hovered = CheckCollisionPointRec(GetMousePosition(), item_rect);

        if (is_selected) {
            DrawRectangleRec(item_rect, PALETTE_SELECTED_COLOR);
        } else if (is_hovered) {
            DrawRectangleRec(item_rect, PALETTE_HOVER_COLOR);
        }

        // Draw preview icon
        editor_render_palette_icon(item, item_x, item_y, PALETTE_ITEM_SIZE);

        // Shortcut key indicator
        DrawText(item->shortcut, item_x + PALETTE_ITEM_SIZE - 12,
                 item_y + PALETTE_ITEM_SIZE - 14, 10, GRAY);

        item_y += PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING;
    }
}
// }}}

// {{{ editor_handle_palette_click
// Handles mouse clicks on palette items, returns 1 if click was consumed
static int editor_handle_palette_click(EditorState* editor) {
    if (!editor || !IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return 0;

    Vector2 mouse = GetMousePosition();
    int item_y = PALETTE_Y + 25;

    for (int i = 0; i < PALETTE_ITEM_COUNT; i++) {
        Rectangle item_rect = {
            (float)(PALETTE_X + 10), (float)item_y,
            (float)PALETTE_ITEM_SIZE, (float)PALETTE_ITEM_SIZE
        };

        if (CheckCollisionPointRec(mouse, item_rect)) {
            PaletteItem* item = &palette_items[i];
            editor->tool_type = item->tool_type;
            if (item->tool_type == EDITOR_TOOL_OBJECT) {
                editor->selected_object_type = item->object_type;
            } else if (item->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
                editor->portal_direction = item->portal_dir;
            }
            printf("Selected: %s\n", item->name);
            return 1;  // Click consumed
        }

        item_y += PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING;
    }

    return 0;  // Click not on palette
}
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ editor_render_grid
void editor_render_grid(EditorState* editor) {
    if (!editor || !editor->show_grid) return;

    grid_render(&editor->grid);

    // Highlight cell under cursor
    if (editor->hover_valid) {
        Color highlight = (editor->mode == EDITOR_MODE_PLACE) ?
                          CURSOR_VALID_COLOR : CURSOR_ERASE_COLOR;
        grid_render_cell_highlight(&editor->grid, editor->hover_col,
                                   editor->hover_row, highlight);
    }
}
// }}}

// {{{ editor_render_ui
void editor_render_ui(EditorState* editor) {
    if (!editor || editor->mode == EDITOR_MODE_DISABLED) return;

    // Mode indicator text
    const char* mode_text;
    Color mode_color;

    switch (editor->mode) {
        case EDITOR_MODE_PLACE:
            mode_text = "EDITOR: PLACE";
            mode_color = MODE_PLACE_COLOR;
            break;
        case EDITOR_MODE_ERASE:
            mode_text = "EDITOR: ERASE";
            mode_color = MODE_ERASE_COLOR;
            break;
        default:
            return;
    }

    // Draw mode indicator at top center
    int text_width = MeasureText(mode_text, MODE_INDICATOR_FONT_SIZE);
    int x = (editor->screen_width - text_width) / 2;

    DrawRectangle(x - 10, MODE_INDICATOR_Y - 5,
                  text_width + 20, MODE_INDICATOR_FONT_SIZE + 10,
                  MODE_BG_COLOR);
    DrawText(mode_text, x, MODE_INDICATOR_Y, MODE_INDICATOR_FONT_SIZE, mode_color);

    // Draw selected tool indicator
    char selected_text[80];
    if (editor->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
        const char* dir_name = (editor->portal_direction == PORTAL_ENTRY) ? "ENTRY" : "EXIT";
        snprintf(selected_text, sizeof(selected_text),
                "Portal %s Ch %d (3/4=Dir, Scroll=Ch)", dir_name, editor->portal_channel);
    } else {
        const char* obj_name;
        switch (editor->selected_object_type) {
            case OBJECT_PEG: obj_name = "PEG"; break;
            case OBJECT_LINE: obj_name = "LINE"; break;
            default: obj_name = "???"; break;
        }
        snprintf(selected_text, sizeof(selected_text), "Selected: %s (1=PEG, 2=LINE, 3/4=Portal)", obj_name);
    }

    int selected_width = MeasureText(selected_text, HELP_TEXT_FONT_SIZE);
    int sel_x = (editor->screen_width - selected_width) / 2;

    DrawRectangle(sel_x - 5, HELP_TEXT_Y - 2,
                  selected_width + 10, HELP_TEXT_FONT_SIZE + 4,
                  MODE_BG_COLOR);
    DrawText(selected_text, sel_x, HELP_TEXT_Y, HELP_TEXT_FONT_SIZE, WHITE);

    // Draw help text at bottom
    const char* help_text = "E=Exit | TAB=Mode | G=Grid | DEL=Remove | Ctrl+S=Save | Ctrl+O=Load";
    int help_width = MeasureText(help_text, HELP_TEXT_FONT_SIZE);
    int help_x = (editor->screen_width - help_width) / 2;
    int help_y = editor->screen_height - HELP_TEXT_FONT_SIZE - 10;

    DrawRectangle(help_x - 5, help_y - 2,
                  help_width + 10, HELP_TEXT_FONT_SIZE + 4,
                  MODE_BG_COLOR);
    DrawText(help_text, help_x, help_y, HELP_TEXT_FONT_SIZE, LIGHTGRAY);

    // Draw grid coordinates at cursor position
    if (editor->hover_valid) {
        char coord_text[32];
        snprintf(coord_text, sizeof(coord_text), "(%d, %d)",
                 editor->hover_col, editor->hover_row);

        Vector2 mouse = GetMousePosition();
        DrawText(coord_text, (int)mouse.x + 15, (int)mouse.y + 15,
                 14, WHITE);
    }

    // Draw object palette
    editor_render_palette(editor);

    // Draw line tool status
    line_tool_render_ui(editor);

    // Draw unsaved changes indicator
    if (editor->board_modified && editor->board_data) {
        const char* mod_text = "* Unsaved changes";
        DrawText(mod_text, PALETTE_X, PALETTE_Y - 20, 12, YELLOW);
    }

    // Draw notification message
    if (editor->notification_timer > 0) {
        int notif_width = MeasureText(editor->notification_text, 16);
        int notif_x = (editor->screen_width - notif_width) / 2;
        int notif_y = editor->screen_height / 2 - 50;

        // Background box
        DrawRectangle(notif_x - 15, notif_y - 10,
                      notif_width + 30, 36, (Color){20, 60, 20, 220});
        DrawRectangleLines(notif_x - 15, notif_y - 10,
                           notif_width + 30, 36, GREEN);
        DrawText(editor->notification_text, notif_x, notif_y, 16, GREEN);
    }

    // Draw load dialog (renders on top of everything else)
    editor_render_load_dialog(editor);
}
// }}}

// {{{ editor_render_cursor
void editor_render_cursor(EditorState* editor) {
    if (!editor || editor->mode == EDITOR_MODE_DISABLED) return;

    // Line tool has its own preview rendering for all states
    if (editor->tool_type == EDITOR_TOOL_OBJECT &&
        editor->selected_object_type == OBJECT_LINE &&
        editor->mode == EDITOR_MODE_PLACE) {
        line_tool_render_preview(editor);
        // Only render hover dot in idle state with valid hover
        if (editor->line_tool.state == LINE_TOOL_IDLE && editor->hover_valid) {
            Vector2 pos = grid_to_pixel(&editor->grid,
                                         editor->hover_col, editor->hover_row);
            DrawCircleV(pos, 8, CURSOR_VALID_COLOR);
            DrawCircleLinesV(pos, 8, GREEN);
        }
        return;
    }

    if (!editor->hover_valid) return;

    // Get pixel position of hovered cell
    Vector2 pos = grid_to_pixel(&editor->grid, editor->hover_col, editor->hover_row);

    if (editor->mode == EDITOR_MODE_PLACE) {
        if (editor->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
            // Portal zone preview
            float cell_size = editor->grid.cell_size;
            Color portal_color;
            if (editor->portal_direction == PORTAL_ENTRY) {
                portal_color = (Color){50, 100, 255, 150};  // Blue
            } else {
                portal_color = (Color){255, 150, 50, 150};  // Orange
            }

            // Draw portal zone rectangle
            DrawRectangle((int)(pos.x - cell_size/2), (int)(pos.y - cell_size/2),
                         (int)cell_size, (int)cell_size, portal_color);
            DrawRectangleLines((int)(pos.x - cell_size/2), (int)(pos.y - cell_size/2),
                              (int)cell_size, (int)cell_size, WHITE);

            // Draw direction indicator
            if (editor->portal_direction == PORTAL_ENTRY) {
                // Inward arrow
                DrawTriangle(
                    (Vector2){pos.x, pos.y + 10},
                    (Vector2){pos.x + 8, pos.y - 5},
                    (Vector2){pos.x - 8, pos.y - 5},
                    WHITE
                );
            } else {
                // Outward arrow
                DrawTriangle(
                    (Vector2){pos.x, pos.y - 10},
                    (Vector2){pos.x - 8, pos.y + 5},
                    (Vector2){pos.x + 8, pos.y + 5},
                    WHITE
                );
            }

            // Draw channel number
            char ch_text[8];
            snprintf(ch_text, sizeof(ch_text), "%d", editor->portal_channel);
            int text_width = MeasureText(ch_text, 14);
            DrawText(ch_text, (int)pos.x - text_width/2, (int)pos.y - 25, 14, WHITE);
        } else {
            // Object preview
            switch (editor->selected_object_type) {
                case OBJECT_PEG:
                    // Draw peg preview (semi-transparent)
                    DrawCircleV(pos, PEG_RADIUS, CURSOR_VALID_COLOR);
                    DrawCircleLinesV(pos, PEG_RADIUS, GREEN);
                    break;
                default:
                    break;
            }
        }
    } else if (editor->mode == EDITOR_MODE_ERASE) {
        // Draw X mark for erase mode
        float size = 15.0f;
        DrawLineEx((Vector2){pos.x - size, pos.y - size},
                   (Vector2){pos.x + size, pos.y + size},
                   3.0f, CURSOR_ERASE_COLOR);
        DrawLineEx((Vector2){pos.x + size, pos.y - size},
                   (Vector2){pos.x - size, pos.y + size},
                   3.0f, CURSOR_ERASE_COLOR);
    }
}
// }}}

// =============================================================================
// Grid Setup
// =============================================================================

// {{{ editor_setup_grid
void editor_setup_grid(EditorState* editor, struct World* world) {
    if (!editor || !world) return;

    editor->world = world;

    // Calculate grid dimensions based on table bounds
    // Grid covers the player's peg area
    float grid_width = world->table_width;
    float grid_height = world->table_bottom - world->table_top;

    // Use 60px cells (matching DEFAULT_PEG_SPACING)
    float cell_size = 60.0f;
    int cols = (int)(grid_width / cell_size);
    int rows = (int)(grid_height / cell_size);

    // Clamp to reasonable limits
    if (cols < 5) cols = 5;
    if (cols > 50) cols = 50;
    if (rows < 5) rows = 5;
    if (rows > 50) rows = 50;

    // Create grid with origin at table top-left
    editor->grid = grid_create(cols, rows, cell_size,
                               world->table_x, world->table_top);

    printf("Editor grid setup: %dx%d cells, origin=(%.0f, %.0f)\n",
           cols, rows, world->table_x, world->table_top);
}
// }}}

// {{{ editor_update_screen_size
void editor_update_screen_size(EditorState* editor, int width, int height) {
    if (!editor) return;
    editor->screen_width = width;
    editor->screen_height = height;
}
// }}}

// =============================================================================
// Line Tool Functions
// =============================================================================

// {{{ line_tool_render_thick_line
// Renders a thick line with rounded end caps
static void line_tool_render_thick_line(float x1, float y1, float x2, float y2,
                                         float thickness, Color color) {
    // Calculate direction and perpendicular
    float dx = x2 - x1;
    float dy = y2 - y1;
    float len = sqrtf(dx * dx + dy * dy);

    if (len < 0.001f) {
        // Zero-length line - just draw a circle
        DrawCircle((int)x1, (int)y1, thickness / 2.0f, color);
        return;
    }

    // Normalize and get perpendicular
    float nx = dx / len;
    float ny = dy / len;
    float px = -ny * (thickness / 2.0f);
    float py = nx * (thickness / 2.0f);

    // Draw rectangle body as two triangles
    Vector2 points[4] = {
        {x1 + px, y1 + py},
        {x1 - px, y1 - py},
        {x2 - px, y2 - py},
        {x2 + px, y2 + py}
    };

    DrawTriangle(points[0], points[1], points[2], color);
    DrawTriangle(points[0], points[2], points[3], color);

    // Draw rounded end caps (circles at endpoints)
    DrawCircle((int)x1, (int)y1, thickness / 2.0f, color);
    DrawCircle((int)x2, (int)y2, thickness / 2.0f, color);
}
// }}}

// {{{ line_tool_update_thickness
// Calculates thickness based on perpendicular distance from line to mouse
static void line_tool_update_thickness(EditorState* editor, Vector2 mouse_world) {
    LineToolData* tool = &editor->line_tool;
    if (tool->state != LINE_TOOL_SETTING_WIDTH) return;

    // Calculate line direction vector
    float dx = tool->end_x - tool->start_x;
    float dy = tool->end_y - tool->start_y;
    float line_length = sqrtf(dx * dx + dy * dy);

    if (line_length < 0.001f) return;

    // Normalize
    dx /= line_length;
    dy /= line_length;

    // Calculate orthogonal vector (perpendicular to line)
    float ortho_x = -dy;
    float ortho_y = dx;

    // Vector from line midpoint to mouse
    float mid_x = (tool->start_x + tool->end_x) / 2.0f;
    float mid_y = (tool->start_y + tool->end_y) / 2.0f;
    float to_mouse_x = mouse_world.x - mid_x;
    float to_mouse_y = mouse_world.y - mid_y;

    // Project onto orthogonal vector (gives signed distance)
    float ortho_dist = to_mouse_x * ortho_x + to_mouse_y * ortho_y;

    // Use absolute distance for thickness (both directions work)
    float abs_dist = fabsf(ortho_dist);

    // Map distance to thickness (with limits)
    tool->thickness = abs_dist * 2.0f;  // Multiply by 2 for more responsive feel
    if (tool->thickness < tool->min_thickness) {
        tool->thickness = tool->min_thickness;
    }
    if (tool->thickness > tool->max_thickness) {
        tool->thickness = tool->max_thickness;
    }
}
// }}}

// {{{ line_tool_place_line
// Places the current line in board_data
static void line_tool_place_line(EditorState* editor) {
    LineToolData* tool = &editor->line_tool;

    // Ensure board_data exists
    if (!editor->board_data) {
        editor_create_board_data(editor);
        if (!editor->board_data) {
            printf("Failed to create board data for line placement\n");
            return;
        }
    }

    // Add line to board data
    int success = board_data_add_line(editor->board_data,
                                      tool->start_col, tool->start_row,
                                      tool->end_col, tool->end_row,
                                      tool->thickness);

    if (success) {
        printf("Placed line: (%d,%d) -> (%d,%d), thickness=%.0f\n",
               tool->start_col, tool->start_row,
               tool->end_col, tool->end_row,
               tool->thickness);
        editor->board_modified = 1;
    } else {
        printf("Failed to place line\n");
    }
}
// }}}

// {{{ line_tool_handle_click
// Handles clicks for the line tool state machine
// Returns 1 if click was consumed, 0 otherwise
static int line_tool_handle_click(EditorState* editor) {
    if (!editor) return 0;
    if (editor->selected_object_type != OBJECT_LINE) return 0;
    if (editor->mode != EDITOR_MODE_PLACE) return 0;
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return 0;
    if (editor_is_over_ui(editor)) return 0;

    LineToolData* tool = &editor->line_tool;

    switch (tool->state) {
        case LINE_TOOL_IDLE:
            if (!editor->hover_valid) return 0;
            // Set start point
            tool->start_col = editor->hover_col;
            tool->start_row = editor->hover_row;
            {
                Vector2 pos = grid_to_pixel(&editor->grid,
                                            tool->start_col, tool->start_row);
                tool->start_x = pos.x;
                tool->start_y = pos.y;
            }
            tool->state = LINE_TOOL_PLACING_END;
            printf("Line start: (%d, %d)\n", tool->start_col, tool->start_row);
            return 1;

        case LINE_TOOL_PLACING_END:
            if (!editor->hover_valid) return 0;
            // Set end point
            tool->end_col = editor->hover_col;
            tool->end_row = editor->hover_row;

            // Don't allow zero-length lines
            if (tool->start_col == tool->end_col &&
                tool->start_row == tool->end_row) {
                printf("Invalid: zero-length line\n");
                return 1;  // Consume click but don't proceed
            }

            {
                Vector2 pos = grid_to_pixel(&editor->grid,
                                            tool->end_col, tool->end_row);
                tool->end_x = pos.x;
                tool->end_y = pos.y;
            }
            tool->thickness = tool->min_thickness;
            tool->state = LINE_TOOL_SETTING_WIDTH;
            printf("Line end: (%d, %d) - move mouse to set width\n",
                   tool->end_col, tool->end_row);
            return 1;

        case LINE_TOOL_SETTING_WIDTH:
            // Confirm and place line
            line_tool_place_line(editor);
            tool->state = LINE_TOOL_IDLE;
            return 1;
    }

    return 0;
}
// }}}

// {{{ line_tool_handle_cancel
// Handles escape key to cancel line tool operation
static void line_tool_handle_cancel(EditorState* editor) {
    if (!editor) return;
    if (editor->selected_object_type != OBJECT_LINE) return;

    if (IsKeyPressed(KEY_ESCAPE)) {
        if (editor->line_tool.state != LINE_TOOL_IDLE) {
            editor->line_tool.state = LINE_TOOL_IDLE;
            printf("Line tool cancelled\n");
        }
    }
}
// }}}

// {{{ line_tool_render_preview
// Renders the line tool preview based on current state
static void line_tool_render_preview(EditorState* editor) {
    if (!editor) return;
    if (editor->selected_object_type != OBJECT_LINE) return;
    if (editor->mode != EDITOR_MODE_PLACE) return;

    LineToolData* tool = &editor->line_tool;
    Color preview_color = (Color){100, 200, 255, 180};
    Color locked_color = (Color){100, 255, 100, 200};
    Color joint_color = (Color){150, 220, 255, 220};

    switch (tool->state) {
        case LINE_TOOL_IDLE:
            // Show dot at hover position (handled by editor_render_cursor)
            break;

        case LINE_TOOL_PLACING_END: {
            // Show locked start point
            DrawCircle((int)tool->start_x, (int)tool->start_y, 8, locked_color);
            DrawCircleLinesV((Vector2){tool->start_x, tool->start_y}, 8, WHITE);

            // Show preview line to hover if valid
            if (editor->hover_valid) {
                Vector2 hover_pos = grid_to_pixel(&editor->grid,
                                                   editor->hover_col,
                                                   editor->hover_row);
                DrawLineEx(
                    (Vector2){tool->start_x, tool->start_y},
                    hover_pos,
                    3.0f, preview_color
                );
                // Show end point preview
                DrawCircle((int)hover_pos.x, (int)hover_pos.y, 6, preview_color);
                DrawCircleLinesV(hover_pos, 6, WHITE);
            }
            break;
        }

        case LINE_TOOL_SETTING_WIDTH:
            // Render full line preview with current thickness
            line_tool_render_thick_line(
                tool->start_x, tool->start_y,
                tool->end_x, tool->end_y,
                tool->thickness, preview_color
            );

            // Render ball joints at endpoints
            DrawCircle((int)tool->start_x, (int)tool->start_y,
                       tool->thickness / 2.0f, joint_color);
            DrawCircle((int)tool->end_x, (int)tool->end_y,
                       tool->thickness / 2.0f, joint_color);

            // Outline the endpoints
            DrawCircleLinesV((Vector2){tool->start_x, tool->start_y},
                            tool->thickness / 2.0f, WHITE);
            DrawCircleLinesV((Vector2){tool->end_x, tool->end_y},
                            tool->thickness / 2.0f, WHITE);
            break;
    }
}
// }}}

// {{{ line_tool_render_ui
// Renders line tool status in screen space
static void line_tool_render_ui(EditorState* editor) {
    if (!editor) return;
    if (editor->selected_object_type != OBJECT_LINE) return;
    if (editor->mode != EDITOR_MODE_PLACE) return;

    LineToolData* tool = &editor->line_tool;
    const char* status = NULL;

    switch (tool->state) {
        case LINE_TOOL_IDLE:
            status = "Line: Click to set start point";
            break;
        case LINE_TOOL_PLACING_END:
            status = "Line: Click to set end point (ESC to cancel)";
            break;
        case LINE_TOOL_SETTING_WIDTH: {
            char buf[64];
            snprintf(buf, sizeof(buf), "Line: Move mouse for width (%.0f) - Click to place",
                     tool->thickness);
            DrawText(buf, 10, 70, 14, YELLOW);
            return;
        }
    }

    if (status) {
        DrawText(status, 10, 70, 14, YELLOW);
    }
}
// }}}

// =============================================================================
// Placement and Sync
// =============================================================================

// {{{ editor_create_board_data
void editor_create_board_data(EditorState* editor) {
    if (!editor) return;

    // Free existing board data
    if (editor->board_data) {
        board_data_destroy(editor->board_data);
    }

    // Create new board data with current grid dimensions
    editor->board_data = board_data_create(editor->grid.cols, editor->grid.rows,
                                           (int)editor->grid.cell_size);
    if (editor->board_data) {
        snprintf(editor->board_data->name, 64, "New Board");
        printf("Created new board data: %dx%d grid\n",
               editor->grid.cols, editor->grid.rows);
    }

    editor->board_modified = 0;
}
// }}}

// {{{ editor_is_over_ui
int editor_is_over_ui(EditorState* editor) {
    if (!editor) return 0;

    Vector2 mouse = GetMousePosition();

    // Check if over palette area
    Rectangle palette_rect = {
        (float)PALETTE_X, (float)PALETTE_Y,
        (float)(PALETTE_ITEM_SIZE + 20),
        (float)(PALETTE_ITEM_COUNT * (PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING) + 35)
    };

    return CheckCollisionPointRec(mouse, palette_rect);
}
// }}}

// {{{ editor_handle_placement
int editor_handle_placement(EditorState* editor) {
    if (!editor || editor->mode != EDITOR_MODE_PLACE) return 0;
    if (!editor->hover_valid) return 0;
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return 0;

    // Don't place if clicking on UI
    if (editor_is_over_ui(editor)) return 0;

    // Create board data if it doesn't exist
    if (!editor->board_data) {
        editor_create_board_data(editor);
        if (!editor->board_data) return 0;
    }

    int col = editor->hover_col;
    int row = editor->hover_row;

    int success = 0;

    // Handle based on tool type
    if (editor->tool_type == EDITOR_TOOL_ZONE_PORTAL) {
        // Portal zone placement
        success = board_data_add_portal(editor->board_data, col, row,
                                        1, 1, editor->portal_channel,
                                        editor->portal_direction);
        if (success) {
            const char* dir_name = (editor->portal_direction == PORTAL_ENTRY) ? "entry" : "exit";
            printf("Placed portal %s (ch %d) at (%d, %d)\n",
                   dir_name, editor->portal_channel, col, row);
        }
    } else {
        // Object placement
        // Check if cell is occupied by an object
        if (board_data_has_object_at(editor->board_data, col, row)) {
            printf("Cell (%d, %d) is occupied\n", col, row);
            return 0;
        }

        switch (editor->selected_object_type) {
            case OBJECT_PEG:
                success = board_data_add_peg(editor->board_data, col, row);
                if (success) printf("Placed peg at (%d, %d)\n", col, row);
                break;

            case OBJECT_LINE:
                // LINE requires two-click placement (handled in 1110)
                printf("Line placement requires start and end points (use line tool)\n");
                return 0;

            default:
                printf("Unknown object type: %d\n", editor->selected_object_type);
                return 0;
        }
    }

    if (success) {
        editor->board_modified = 1;
    }

    return success;
}
// }}}

// {{{ editor_handle_erase
// Track last erased position for drag removal
// Prevents repeated removal at same cell during drag
static int last_erase_col = -1;
static int last_erase_row = -1;

int editor_handle_erase(EditorState* editor) {
    if (!editor || editor->mode != EDITOR_MODE_ERASE) return 0;
    if (!editor->hover_valid) return 0;

    // Don't erase if clicking on UI
    if (editor_is_over_ui(editor)) return 0;

    // Check if board data exists
    if (!editor->board_data) return 0;

    int col = editor->hover_col;
    int row = editor->hover_row;

    // Single click or start of drag
    int should_erase = 0;
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        should_erase = 1;
        last_erase_col = col;
        last_erase_row = row;
    }
    // Continue drag - only erase if moved to new cell
    else if (IsMouseButtonDown(MOUSE_LEFT_BUTTON)) {
        if (col != last_erase_col || row != last_erase_row) {
            should_erase = 1;
            last_erase_col = col;
            last_erase_row = row;
        }
    }

    // Reset tracking when mouse released
    if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON)) {
        last_erase_col = -1;
        last_erase_row = -1;
    }

    if (!should_erase) return 0;

    // Try to remove object at position
    int success = board_data_remove_object_at(editor->board_data, col, row);
    if (success) {
        printf("Removed object at (%d, %d)\n", col, row);
        editor->board_modified = 1;
    }

    return success;
}
// }}}

// {{{ editor_sync_to_world
void editor_sync_to_world(EditorState* editor) {
    if (!editor || !editor->world) return;
    if (!editor->board_modified) return;
    if (!editor->board_data) return;

    // Apply board data to world
    board_data_apply_to_world(editor->board_data, editor->world, &editor->grid);

    // Regenerate bumpers based on new zone layout
    if (editor->world->zone_count > 0) {
        world_generate_bumpers(editor->world);
    }

    // Sync portals
    // Create portal manager if needed
    if (!editor->world->portals) {
        editor->world->portals = portal_manager_create();
    }
    if (editor->world->portals) {
        portal_manager_load_from_board(editor->world->portals,
                                       editor->board_data, &editor->grid);
    }

    editor->board_modified = 0;
    printf("Synced board changes to world\n");
}
// }}}

// =============================================================================
// Save/Load Operations
// =============================================================================

// {{{ editor_show_notification
void editor_show_notification(EditorState* editor, const char* text, float duration) {
    if (!editor || !text) return;
    strncpy(editor->notification_text, text, sizeof(editor->notification_text) - 1);
    editor->notification_text[sizeof(editor->notification_text) - 1] = '\0';
    editor->notification_timer = duration;
}
// }}}

// {{{ editor_update_notification
void editor_update_notification(EditorState* editor, float dt) {
    if (!editor) return;
    if (editor->notification_timer > 0) {
        editor->notification_timer -= dt;
    }
}
// }}}

// {{{ editor_save_board
int editor_save_board(EditorState* editor) {
    if (!editor) return 0;

    // Create board data if it doesn't exist
    if (!editor->board_data) {
        editor_show_notification(editor, "Nothing to save", 2.0f);
        return 0;
    }

    // Use current filename if set, otherwise use default
    const char* filename;
    if (editor->has_filename && editor->current_filename[0] != '\0') {
        filename = editor->current_filename;
    } else {
        // Generate default filename
        snprintf(editor->current_filename, sizeof(editor->current_filename),
                 "boards/editor-board.json");
        filename = editor->current_filename;
        editor->has_filename = 1;
    }

    // Save to file
    int success = board_data_save_json(editor->board_data, filename);
    if (success) {
        editor->board_modified = 0;
        char msg[80];
        snprintf(msg, sizeof(msg), "Saved: %s", filename);
        editor_show_notification(editor, msg, 3.0f);
        printf("Board saved to: %s\n", filename);
    } else {
        editor_show_notification(editor, "Save failed!", 3.0f);
        fprintf(stderr, "ERROR: Failed to save board to %s\n", filename);
    }

    return success;
}
// }}}

// =============================================================================
// Load Dialog
// =============================================================================

// {{{ editor_open_load_dialog
void editor_open_load_dialog(EditorState* editor) {
    if (!editor) return;

    // Free existing file list
    if (editor->available_boards) {
        board_file_list_destroy(editor->available_boards);
    }

    // Scan for board files
    editor->available_boards = board_scan_directory("boards");

    // Reset selection
    editor->load_selected_index = 0;
    editor->load_scroll_offset = 0;

    // Show dialog
    editor->show_load_dialog = 1;
    printf("Load dialog opened\n");
}
// }}}

// {{{ editor_close_load_dialog
void editor_close_load_dialog(EditorState* editor) {
    if (!editor) return;

    editor->show_load_dialog = 0;

    // Free file list
    if (editor->available_boards) {
        board_file_list_destroy(editor->available_boards);
        editor->available_boards = NULL;
    }
}
// }}}

// {{{ editor_load_board
int editor_load_board(EditorState* editor, const char* filepath) {
    if (!editor || !filepath) return 0;

    // Load board data from file
    BoardData* new_data = board_data_load_json(filepath);
    if (!new_data) {
        editor_show_notification(editor, "Load failed!", 2.0f);
        fprintf(stderr, "ERROR: Failed to load board: %s\n", filepath);
        return 0;
    }

    // Free existing board data
    if (editor->board_data) {
        board_data_destroy(editor->board_data);
    }

    // Set new board data
    editor->board_data = new_data;

    // Update editor state
    strncpy(editor->current_filename, filepath, sizeof(editor->current_filename) - 1);
    editor->current_filename[sizeof(editor->current_filename) - 1] = '\0';
    editor->has_filename = 1;
    editor->board_modified = 0;

    // Update grid from loaded data
    editor->grid = grid_create(new_data->grid_cols, new_data->grid_rows,
                               (float)new_data->cell_size,
                               editor->grid.origin_x, editor->grid.origin_y);

    // Sync to world
    if (editor->world) {
        board_data_apply_to_world(editor->board_data, editor->world, &editor->grid);
    }

    char msg[80];
    snprintf(msg, sizeof(msg), "Loaded: %s", filepath);
    editor_show_notification(editor, msg, 3.0f);
    printf("Board loaded: %s (%d objects)\n", filepath, new_data->object_count);

    return 1;
}
// }}}

// {{{ editor_handle_load_dialog_input
static void editor_handle_load_dialog_input(EditorState* editor) {
    if (!editor || !editor->show_load_dialog) return;

    // Escape to cancel
    if (IsKeyPressed(KEY_ESCAPE)) {
        editor_close_load_dialog(editor);
        return;
    }

    // Handle empty list case
    if (!editor->available_boards || editor->available_boards->count == 0) {
        return;
    }

    int visible_items = 10;  // Max items visible at once

    // Navigation with Up/Down
    if (IsKeyPressed(KEY_UP)) {
        editor->load_selected_index--;
        if (editor->load_selected_index < 0) {
            editor->load_selected_index = editor->available_boards->count - 1;
            // Scroll to show selection
            int max_scroll = editor->available_boards->count - visible_items;
            if (max_scroll < 0) max_scroll = 0;
            editor->load_scroll_offset = max_scroll;
        }
        // Adjust scroll to keep selection visible
        if (editor->load_selected_index < editor->load_scroll_offset) {
            editor->load_scroll_offset = editor->load_selected_index;
        }
    }

    if (IsKeyPressed(KEY_DOWN)) {
        editor->load_selected_index++;
        if (editor->load_selected_index >= editor->available_boards->count) {
            editor->load_selected_index = 0;
            editor->load_scroll_offset = 0;
        }
        // Adjust scroll to keep selection visible
        if (editor->load_selected_index >= editor->load_scroll_offset + visible_items) {
            editor->load_scroll_offset = editor->load_selected_index - visible_items + 1;
        }
    }

    // Mouse wheel scrolling
    int wheel = (int)GetMouseWheelMove();
    if (wheel != 0) {
        editor->load_scroll_offset -= wheel * 2;
        if (editor->load_scroll_offset < 0) {
            editor->load_scroll_offset = 0;
        }
        int max_scroll = editor->available_boards->count - visible_items;
        if (max_scroll < 0) max_scroll = 0;
        if (editor->load_scroll_offset > max_scroll) {
            editor->load_scroll_offset = max_scroll;
        }
    }

    // Enter to load selected
    if (IsKeyPressed(KEY_ENTER)) {
        const char* filename = editor->available_boards->filenames[
            editor->load_selected_index];

        char filepath[280];
        snprintf(filepath, sizeof(filepath), "boards/%s", filename);

        editor_load_board(editor, filepath);
        editor_close_load_dialog(editor);
    }
}
// }}}

// {{{ editor_render_load_dialog
// Renders the load dialog UI (call from editor_render_ui)
static void editor_render_load_dialog(EditorState* editor) {
    if (!editor || !editor->show_load_dialog) return;

    int screen_width = editor->screen_width;
    int screen_height = editor->screen_height;

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
        for (int i = 0; i < visible_items; i++) {
            int file_index = i + editor->load_scroll_offset;
            if (file_index >= editor->available_boards->count) break;

            const char* filename = editor->available_boards->filenames[file_index];
            int item_y = list_y + i * item_height;

            // Selection highlight
            if (file_index == editor->load_selected_index) {
                DrawRectangle(list_x + 2, item_y + 2, list_width - 4,
                             item_height - 4, (Color){60, 100, 180, 255});
            }

            // Filename (remove .json extension for display)
            char display_name[64];
            strncpy(display_name, filename, sizeof(display_name) - 1);
            display_name[sizeof(display_name) - 1] = '\0';
            size_t len = strlen(display_name);
            if (len > 5) display_name[len - 5] = '\0';  // Remove .json

            DrawText(display_name, list_x + 10, item_y + 5, 14, WHITE);
        }

        // Scroll indicator if needed
        if (editor->available_boards->count > visible_items) {
            float scroll_ratio = (float)editor->load_scroll_offset /
                                (editor->available_boards->count - visible_items);
            int scrollbar_y = list_y + (int)(scroll_ratio * (list_height - 30));
            DrawRectangle(list_x + list_width - 8, scrollbar_y, 6, 30,
                         (Color){100, 100, 120, 255});
        }
    } else {
        DrawText("No boards found", list_x + 10, list_y + 10, 14, GRAY);
        DrawText("Save a board first with Ctrl+S", list_x + 10, list_y + 30, 12, DARKGRAY);
    }

    // Controls hint
    DrawText("UP/DOWN: Select  ENTER: Load  ESC: Cancel",
             dialog_x + 20, dialog_y + dialog_height - 30, 12, GRAY);
}
// }}}
