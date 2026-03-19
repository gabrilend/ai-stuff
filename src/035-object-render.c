// src/035-object-render.c
// Standalone object rendering implementation
// Used by both game and standalone editor

#include "034-object-render.h"
#include "050-material.h"
#include <stdio.h>
#include <math.h>

// Rotor rendering constants (issue 901b)
#define ROTOR_CENTER_COLOR (Color){200, 150, 50, 255}
#define ROTOR_TOOTH_COLOR (Color){180, 130, 40, 255}
#define ROTOR_OUTLINE_COLOR (Color){100, 80, 30, 255}
#define ROTOR_TEETH_COUNT 8

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

// {{{ render_rotor
// Renders a rotor as a gear-shaped marker (issue 901b).
// current_angle: current rotation in radians (for visual animation)
// cw: 1 for clockwise, 0 for counter-clockwise (affects arrow direction)
void render_rotor(float x, float y, float radius, float current_angle, int cw) {
    // Draw gear teeth around the center
    // Teeth are small triangles pointing outward
    float inner_radius = radius * 0.7f;
    float outer_radius = radius * 1.3f;
    float tooth_half_angle = (float)(3.14159f / ROTOR_TEETH_COUNT / 2.5f);

    for (int i = 0; i < ROTOR_TEETH_COUNT; i++) {
        float angle = current_angle + (float)i * (2.0f * 3.14159f / ROTOR_TEETH_COUNT);

        // Tooth corners
        float cos_a = cosf(angle);
        float sin_a = sinf(angle);
        float cos_left = cosf(angle - tooth_half_angle);
        float sin_left = sinf(angle - tooth_half_angle);
        float cos_right = cosf(angle + tooth_half_angle);
        float sin_right = sinf(angle + tooth_half_angle);

        Vector2 tip = { x + outer_radius * cos_a, y + outer_radius * sin_a };
        Vector2 left = { x + inner_radius * cos_left, y + inner_radius * sin_left };
        Vector2 right = { x + inner_radius * cos_right, y + inner_radius * sin_right };

        DrawTriangle(tip, left, right, ROTOR_TOOTH_COLOR);
    }

    // Draw center circle
    DrawCircle((int)x, (int)y, inner_radius, ROTOR_CENTER_COLOR);

    // Draw outline rings
    DrawCircleLines((int)x, (int)y, inner_radius, ROTOR_OUTLINE_COLOR);
    DrawCircleLines((int)x, (int)y, radius, ROTOR_OUTLINE_COLOR);

    // Draw rotation direction arrow (small arc with arrowhead)
    // Arrow indicates which way the rotor spins
    float arrow_radius = radius * 0.5f;
    float arrow_start = current_angle + 0.3f;
    float arrow_end = current_angle + 1.5f;

    // Draw arc segments
    int segments = 8;
    for (int i = 0; i < segments; i++) {
        float t0 = arrow_start + (arrow_end - arrow_start) * (float)i / segments;
        float t1 = arrow_start + (arrow_end - arrow_start) * (float)(i + 1) / segments;
        Vector2 p0 = { x + arrow_radius * cosf(t0), y + arrow_radius * sinf(t0) };
        Vector2 p1 = { x + arrow_radius * cosf(t1), y + arrow_radius * sinf(t1) };
        DrawLineEx(p0, p1, 2.0f, WHITE);
    }

    // Arrowhead at end of arc
    float head_angle = cw ? arrow_end : arrow_start;
    float head_dir = cw ? (head_angle + 1.5f) : (head_angle - 1.5f);
    Vector2 head_pos = { x + arrow_radius * cosf(head_angle), y + arrow_radius * sinf(head_angle) };
    Vector2 head_tip = { head_pos.x + 6.0f * cosf(head_dir), head_pos.y + 6.0f * sinf(head_dir) };
    DrawLineEx(head_pos, head_tip, 2.0f, WHITE);
}
// }}}

// {{{ render_rotor_preview
// Renders a semi-transparent rotor preview for cursor placement (issue 901b)
void render_rotor_preview(float x, float y, float radius) {
    Color preview = (Color){200, 150, 50, 100};
    Color preview_light = (Color){180, 130, 40, 80};

    // Draw simplified gear shape (no teeth, just rings)
    DrawCircle((int)x, (int)y, radius * 1.3f, preview_light);
    DrawCircle((int)x, (int)y, radius * 0.7f, preview);
    DrawCircleLines((int)x, (int)y, radius * 0.7f, (Color){255, 255, 255, 150});
    DrawCircleLines((int)x, (int)y, radius, (Color){255, 255, 255, 150});
    DrawCircleLines((int)x, (int)y, radius * 1.3f, (Color){255, 255, 255, 100});
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
// Highlights an intersection point for erase mode cursor
// Uses intersection-based coordinates (col/row can be 0 to cols/rows inclusive)
void render_grid_cursor(Grid* grid, int col, int row, Color color) {
    if (!grid) return;
    // Allow col == grid->cols and row == grid->rows (valid intersections)
    if (col < 0 || col > grid->cols || row < 0 || row > grid->rows) return;

    // Get intersection point
    float x = grid->origin_x + col * grid->cell_size;
    float y = grid->origin_y + row * grid->cell_size;

    // Draw highlight centered on intersection point
    float radius = grid->cell_size * 0.4f;
    DrawCircle((int)x, (int)y, radius, color);
    DrawCircleLines((int)x, (int)y, radius, WHITE);
}
// }}}

// =============================================================================
// BoardData Rendering
// =============================================================================

// {{{ render_board_objects
// Issue 839: Objects now render with material display colors for visual consistency.
// Material is determined from RGB physics properties (restitution, friction, point_bonus).
void render_board_objects(BoardData* board, Grid* grid) {
    if (!board || !grid) return;

    for (int i = 0; i < board->object_count; i++) {
        BoardObject* obj = &board->objects[i];

        // Convert grid coords to pixel coords
        float x = grid_to_pixel_x(grid, obj->col, obj->row);
        float y = grid_to_pixel_y(grid, obj->col, obj->row);

        // Determine color from material (issue 839)
        // Find closest material and use its display color for visual consistency
        int mat_index = find_closest_material(obj->restitution, obj->friction, obj->point_bonus);
        Color color = material_get_display_color(mat_index);

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

        // Convert grid coords to pixel coords (issue 1227)
        // Zone starts at cell top-left, not centered on intersection
        float x = grid_to_pixel_x(grid, zone->col, zone->row);
        float y = grid_to_pixel_y(grid, zone->col, zone->row);

        // Calculate size from grid
        float width = zone->width * grid->cell_size;
        float height = zone->height * grid->cell_size;

        if (zone->type == ZONE_PORTAL) {
            render_portal_zone(x, y, width, height, zone->direction, zone->channel);
        }
    }
}
// }}}

// {{{ render_board_rotors
// Renders all rotors in the board (issue 901b)
void render_board_rotors(BoardData* board, Grid* grid) {
    if (!board || !grid) return;

    for (int i = 0; i < board->rotor_count; i++) {
        Rotor* rotor = &board->rotors[i];

        // Convert grid coords to pixel coords
        float x = grid_to_pixel_x(grid, rotor->col, rotor->row);
        float y = grid_to_pixel_y(grid, rotor->col, rotor->row);

        // Rotor radius matches peg radius for visual consistency
        float radius = 12.0f;

        // cw = 1 if rotation_speed >= 0 (positive = clockwise)
        int cw = (rotor->rotation_speed >= 0) ? 1 : 0;

        render_rotor(x, y, radius, rotor->current_angle, cw);
    }
}
// }}}
