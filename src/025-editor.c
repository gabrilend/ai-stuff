// src/025-editor.c
// Board editor implementation
// Handles mode toggle, grid overlay, cursor preview, and UI rendering
//
// External functions: editor_create, editor_destroy, editor_toggle,
//                     editor_is_active, editor_handle_input,
//                     editor_render_grid, editor_render_ui, editor_render_cursor

#include "024-editor.h"
#include "004-world.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

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
    ObjectType type;
    const char* name;
    const char* shortcut;
    Color preview_color;
} PaletteItem;
// }}}

// {{{ palette_items array
static PaletteItem palette_items[] = {
    { OBJECT_PEG,  "Peg",  "1", (Color){180, 180, 200, 255} },
    { OBJECT_LINE, "Line", "2", (Color){200, 150, 100, 255} }
};
#define PALETTE_ITEM_COUNT 2
// }}}

// Forward declaration for palette click handler (defined in Palette Rendering section)
static int editor_handle_palette_click(EditorState* editor);

// Forward declarations for line tool functions (defined in Line Tool Functions section)
static void line_tool_handle_cancel(EditorState* editor);
static void line_tool_update_thickness(EditorState* editor, Vector2 mouse_world);
static int line_tool_handle_click(EditorState* editor);
static void line_tool_render_preview(EditorState* editor);
static void line_tool_render_ui(EditorState* editor);

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

    // Object type selection with number keys
    if (IsKeyPressed(KEY_ONE)) {
        editor->selected_object_type = OBJECT_PEG;
        printf("Selected: PEG\n");
    }
    if (IsKeyPressed(KEY_TWO)) {
        editor->selected_object_type = OBJECT_LINE;
        printf("Selected: LINE\n");
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

    switch (item->type) {
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
            // Unknown type - draw question mark
            DrawText("?", cx - 5, cy - 8, 16, RED);
            break;
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
        int is_selected = (editor->selected_object_type == item->type);
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
            editor->selected_object_type = palette_items[i].type;
            printf("Selected: %s\n", palette_items[i].name);
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

    // Draw selected object indicator
    const char* obj_name;
    switch (editor->selected_object_type) {
        case OBJECT_PEG: obj_name = "PEG"; break;
        case OBJECT_LINE: obj_name = "LINE"; break;
        default: obj_name = "???"; break;
    }

    char selected_text[64];
    snprintf(selected_text, sizeof(selected_text), "Selected: %s (1=PEG, 2=LINE)", obj_name);

    int selected_width = MeasureText(selected_text, HELP_TEXT_FONT_SIZE);
    int sel_x = (editor->screen_width - selected_width) / 2;

    DrawRectangle(sel_x - 5, HELP_TEXT_Y - 2,
                  selected_width + 10, HELP_TEXT_FONT_SIZE + 4,
                  MODE_BG_COLOR);
    DrawText(selected_text, sel_x, HELP_TEXT_Y, HELP_TEXT_FONT_SIZE, WHITE);

    // Draw help text at bottom
    const char* help_text = "E=Exit | TAB=Mode | G=Grid | DEL=Remove | Click=Place/Erase";
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
}
// }}}

// {{{ editor_render_cursor
void editor_render_cursor(EditorState* editor) {
    if (!editor || editor->mode == EDITOR_MODE_DISABLED) return;

    // Line tool has its own preview rendering for all states
    if (editor->selected_object_type == OBJECT_LINE &&
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
        // Draw preview of selected object
        switch (editor->selected_object_type) {
            case OBJECT_PEG:
                // Draw peg preview (semi-transparent)
                DrawCircleV(pos, PEG_RADIUS, CURSOR_VALID_COLOR);
                DrawCircleLinesV(pos, PEG_RADIUS, GREEN);
                break;
            default:
                break;
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

    // Check if cell is occupied
    if (board_data_has_object_at(editor->board_data, col, row)) {
        printf("Cell (%d, %d) is occupied\n", col, row);
        return 0;
    }

    // Add object based on selected type
    int success = 0;
    switch (editor->selected_object_type) {
        case OBJECT_PEG:
            success = board_data_add_peg(editor->board_data, col, row);
            if (success) printf("Placed peg at (%d, %d)\n", col, row);
            break;

        case OBJECT_LINE:
            // LINE requires two-click placement (handled in 1110)
            // For now, just print a message
            printf("Line placement requires start and end points (use line tool)\n");
            return 0;

        default:
            printf("Unknown object type: %d\n", editor->selected_object_type);
            return 0;
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

    editor->board_modified = 0;
    printf("Synced board changes to world\n");
}
// }}}
