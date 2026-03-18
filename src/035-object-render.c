// src/035-object-render.c
// Standalone object rendering implementation
// Used by both game and standalone editor

#include "034-object-render.h"
#include <stdio.h>

// =============================================================================
// Object Rendering
// =============================================================================

// {{{ render_peg
void render_peg(float x, float y, float radius, Color color) {
    // Draw filled circle
    DrawCircle((int)x, (int)y, radius, color);
    // Draw outline
    DrawCircleLines((int)x, (int)y, radius, PEG_OUTLINE_COLOR);
}
// }}}

// {{{ render_peg_preview
void render_peg_preview(float x, float y, float radius) {
    Color preview = (Color){255, 255, 255, 100};
    DrawCircle((int)x, (int)y, radius, preview);
    DrawCircleLines((int)x, (int)y, radius, (Color){255, 255, 255, 180});
}
// }}}

// {{{ render_line
void render_line(float x1, float y1, float x2, float y2,
                 float thickness, Color color) {
    // Draw main line
    DrawLineEx((Vector2){x1, y1}, (Vector2){x2, y2}, thickness, color);

    // Draw rounded endpoints
    float cap_radius = thickness / 2.0f;
    DrawCircle((int)x1, (int)y1, cap_radius, color);
    DrawCircle((int)x2, (int)y2, cap_radius, color);

    // Draw outline
    DrawCircleLines((int)x1, (int)y1, cap_radius, LINE_OUTLINE_COLOR);
    DrawCircleLines((int)x2, (int)y2, cap_radius, LINE_OUTLINE_COLOR);
}
// }}}

// {{{ render_line_preview
void render_line_preview(float x1, float y1, float x2, float y2,
                         float thickness) {
    Color preview = (Color){255, 255, 255, 100};
    DrawLineEx((Vector2){x1, y1}, (Vector2){x2, y2}, thickness, preview);

    float cap_radius = thickness / 2.0f;
    DrawCircle((int)x1, (int)y1, cap_radius, preview);
    DrawCircle((int)x2, (int)y2, cap_radius, preview);
}
// }}}

// {{{ render_portal_zone
void render_portal_zone(float x, float y, float width, float height,
                        PortalDirection direction, int channel) {
    // Choose color based on direction
    Color color = (direction == PORTAL_ENTRY) ? PORTAL_ENTRY_COLOR : PORTAL_EXIT_COLOR;

    // Draw filled rectangle
    DrawRectangle((int)x, (int)y, (int)width, (int)height, color);

    // Draw border
    DrawRectangleLines((int)x, (int)y, (int)width, (int)height, WHITE);

    // Draw direction indicator (arrow or symbol)
    float cx = x + width / 2.0f;
    float cy = y + height / 2.0f;

    if (direction == PORTAL_ENTRY) {
        // Draw down arrow for entry
        DrawTriangle(
            (Vector2){cx, cy + 10},
            (Vector2){cx - 8, cy - 5},
            (Vector2){cx + 8, cy - 5},
            WHITE
        );
    } else {
        // Draw up arrow for exit
        DrawTriangle(
            (Vector2){cx, cy - 10},
            (Vector2){cx + 8, cy + 5},
            (Vector2){cx - 8, cy + 5},
            WHITE
        );
    }

    // Draw channel number
    char text[4];
    snprintf(text, sizeof(text), "%d", channel);
    int text_width = MeasureText(text, 16);
    DrawText(text, (int)(cx - text_width / 2), (int)(y + 5), 16, WHITE);
}
// }}}

// {{{ render_portal_preview
void render_portal_preview(float x, float y, float width, float height,
                           PortalDirection direction, int channel) {
    Color preview = (direction == PORTAL_ENTRY)
        ? (Color){50, 150, 255, 80}
        : (Color){255, 150, 50, 80};

    DrawRectangle((int)x, (int)y, (int)width, (int)height, preview);
    DrawRectangleLines((int)x, (int)y, (int)width, (int)height,
                       (Color){255, 255, 255, 150});

    // Draw channel number
    float cx = x + width / 2.0f;
    char text[4];
    snprintf(text, sizeof(text), "%d", channel);
    int text_width = MeasureText(text, 16);
    DrawText(text, (int)(cx - text_width / 2), (int)(y + 5), 16,
             (Color){255, 255, 255, 150});
}
// }}}

// =============================================================================
// Grid Rendering
// =============================================================================

// {{{ render_grid
void render_grid(Grid* grid, float canvas_x, float canvas_y,
                 float canvas_width, float canvas_height) {
    if (!grid) return;

    // Draw vertical lines
    for (int col = 0; col <= grid->cols; col++) {
        float x = grid->origin_x + col * grid->cell_size;
        if (x < canvas_x || x > canvas_x + canvas_width) continue;

        // Major line every 5 cells
        Color line_color = (col % 5 == 0) ? GRID_MAJOR_COLOR : GRID_LINE_COLOR;
        DrawLine((int)x, (int)canvas_y, (int)x, (int)(canvas_y + canvas_height), line_color);
    }

    // Draw horizontal lines
    for (int row = 0; row <= grid->rows; row++) {
        float y = grid->origin_y + row * grid->cell_size;
        if (y < canvas_y || y > canvas_y + canvas_height) continue;

        // Major line every 5 cells
        Color line_color = (row % 5 == 0) ? GRID_MAJOR_COLOR : GRID_LINE_COLOR;
        DrawLine((int)canvas_x, (int)y, (int)(canvas_x + canvas_width), (int)y, line_color);
    }
}
// }}}

// {{{ render_grid_cursor
void render_grid_cursor(Grid* grid, int col, int row, Color color) {
    if (!grid) return;
    if (col < 0 || col >= grid->cols || row < 0 || row >= grid->rows) return;

    float x = grid->origin_x + col * grid->cell_size;
    float y = grid->origin_y + row * grid->cell_size;
    float size = grid->cell_size;

    // Draw highlighted cell
    DrawRectangle((int)x, (int)y, (int)size, (int)size, color);
    DrawRectangleLines((int)x, (int)y, (int)size, (int)size, WHITE);
}
// }}}

// =============================================================================
// BoardData Rendering
// =============================================================================

// {{{ render_board_objects
void render_board_objects(BoardData* board, Grid* grid) {
    if (!board || !grid) return;

    for (int i = 0; i < board->object_count; i++) {
        BoardObject* obj = &board->objects[i];

        // Convert grid coords to pixel coords
        float x = grid_to_pixel_x(grid, obj->col, obj->row);
        float y = grid_to_pixel_y(grid, obj->col, obj->row);

        // Create color from RGB properties
        Color color = (Color){obj->restitution, obj->friction, obj->point_bonus, 255};

        if (obj->type == OBJECT_PEG) {
            render_peg(x, y, 12.0f, color);
        } else if (obj->type == OBJECT_LINE) {
            float x2 = grid_to_pixel_x(grid, obj->end_col, obj->end_row);
            float y2 = grid_to_pixel_y(grid, obj->end_col, obj->end_row);
            render_line(x, y, x2, y2, obj->thickness, color);
        }
    }
}
// }}}

// {{{ render_board_zones
void render_board_zones(BoardData* board, Grid* grid) {
    if (!board || !grid) return;

    for (int i = 0; i < board->zone_count; i++) {
        BoardZone* zone = &board->zones[i];

        // Convert grid coords to pixel coords
        float x = grid_to_pixel_x(grid, zone->col, zone->row);
        float y = grid_to_pixel_y(grid, zone->col, zone->row);

        // Calculate size from grid
        float width = zone->width * grid->cell_size;
        float height = zone->height * grid->cell_size;

        // Center the zone on the grid position
        x -= width / 2.0f;
        y -= height / 2.0f;

        if (zone->type == ZONE_PORTAL) {
            render_portal_zone(x, y, width, height, zone->direction, zone->channel);
        }
    }
}
// }}}
