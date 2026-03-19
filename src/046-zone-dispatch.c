// src/046-zone-dispatch.c
// Grid-based zone dispatch implementation
// Provides fast zone lookup and unified handler dispatch
//
// Issue 318: Unified zone handling replaces fragmented zone checks.
// Key benefits:
// - O(1) zone lookup via grid cell
// - No branching in hot path (function pointer dispatch)
// - has_scored reset handled naturally by background zones
// - Extensible for future zone types (rotors, movers)

#include "045-zone-dispatch.h"
#include "006-ball.h"
#include "004-world.h"
#include "036-wrap-zones.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "raylib.h"

// =============================================================================
// Zone Handler Forward Declarations
// =============================================================================

static int zone_background(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_gate_10(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_gate_20(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_gate_50(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_gate_100(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_gate_200(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_gate_500(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_wrap_to_bottom(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_wrap_to_top(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_wall_left(Ball* ball, ZoneGrid* grid, int col, int row);
static int zone_wall_right(Ball* ball, ZoneGrid* grid, int col, int row);

// =============================================================================
// Dispatch Table
// =============================================================================

// {{{ zone_functions array
// Function pointer array indexed by DispatchZoneType.
// Each entry handles the corresponding zone type.
// Placeholders use zone_background for future types.
static ZoneFunc zone_functions[DISPATCH_ZONE_TYPE_COUNT] = {
    [DISPATCH_ZONE_BACKGROUND]     = zone_background,
    [DISPATCH_ZONE_GATE_10]        = zone_gate_10,
    [DISPATCH_ZONE_GATE_20]        = zone_gate_20,
    [DISPATCH_ZONE_GATE_50]        = zone_gate_50,
    [DISPATCH_ZONE_GATE_100]       = zone_gate_100,
    [DISPATCH_ZONE_GATE_200]       = zone_gate_200,
    [DISPATCH_ZONE_GATE_500]       = zone_gate_500,
    [DISPATCH_ZONE_WRAP_TO_BOTTOM] = zone_wrap_to_bottom,
    [DISPATCH_ZONE_WRAP_TO_TOP]    = zone_wrap_to_top,
    [DISPATCH_ZONE_WALL_LEFT]      = zone_wall_left,
    [DISPATCH_ZONE_WALL_RIGHT]     = zone_wall_right,
    [DISPATCH_ZONE_PORTAL_ENTRY]   = zone_background,  // Placeholder (Phase 9)
    [DISPATCH_ZONE_PORTAL_EXIT]    = zone_background,  // Placeholder (Phase 9)
    [DISPATCH_ZONE_ROTOR_AREA]     = zone_background,  // Placeholder (Phase 9)
    [DISPATCH_ZONE_MOVER_AREA]     = zone_background,  // Placeholder (Phase 9)
};
// }}}

// =============================================================================
// Zone Handler Implementations
// =============================================================================

// {{{ zone_background
// Default zone - resets has_scored flag, continues normal physics.
// This is the key to fixing issue 316 (multiple gate scoring):
// When ball passes through background after scoring, it can score again.
static int zone_background(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)grid; (void)col; (void)row;  // Unused parameters
    ball->passed_gate = 0;  // Reset scoring flag - can score at next gate
    return 1;  // Continue physics
}
// }}}

// {{{ zone_gate_generic
// Generic gate handler - awards points based on passed base value.
// Applies multiplier from grid overlay.
// Sets passed_gate flag to prevent double-scoring.
// Sets pending_score for main loop to collect.
static int zone_gate_generic(Ball* ball, ZoneGrid* grid, int col, int row,
                             int base_points) {
    if (!ball->passed_gate) {
        // Calculate points with multiplier
        int multiplier = 1 + grid->multipliers[row][col];
        int points = base_points * multiplier;

        // Store pending score in ball for main loop to collect
        ball->pending_score = points;
        ball->score_x = ball->x;
        ball->score_y = ball->y;

        ball->passed_gate = 1;  // Mark as scored, prevents double-scoring
    }
    return 1;  // Continue physics (ball passes through gate)
}
// }}}

// {{{ zone_gate_10
static int zone_gate_10(Ball* ball, ZoneGrid* grid, int col, int row) {
    return zone_gate_generic(ball, grid, col, row, 10);
}
// }}}

// {{{ zone_gate_20
static int zone_gate_20(Ball* ball, ZoneGrid* grid, int col, int row) {
    return zone_gate_generic(ball, grid, col, row, 20);
}
// }}}

// {{{ zone_gate_50
static int zone_gate_50(Ball* ball, ZoneGrid* grid, int col, int row) {
    return zone_gate_generic(ball, grid, col, row, 50);
}
// }}}

// {{{ zone_gate_100
static int zone_gate_100(Ball* ball, ZoneGrid* grid, int col, int row) {
    return zone_gate_generic(ball, grid, col, row, 100);
}
// }}}

// {{{ zone_gate_200
static int zone_gate_200(Ball* ball, ZoneGrid* grid, int col, int row) {
    return zone_gate_generic(ball, grid, col, row, 200);
}
// }}}

// {{{ zone_gate_500
static int zone_gate_500(Ball* ball, ZoneGrid* grid, int col, int row) {
    return zone_gate_generic(ball, grid, col, row, 500);
}
// }}}

// {{{ zone_wrap_to_bottom
// Teleports ball from top of world to bottom.
// Player balls entering bottom wrap zone go to top.
// Resets passed_gate so ball can score again on new board.
static int zone_wrap_to_bottom(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)col; (void)row;

    // Use world's wrap zones for accurate teleportation
    World* world = grid->world;
    if (world && world->wrap_zones) {
        WrapZones* wz = world->wrap_zones;
        // Calculate offset into wrap zone
        float offset_in_zone = ball->y - wz->bottom_zone_y;
        // Mirror position to top wrap zone
        ball->y = wz->top_zone_y + offset_in_zone;
    } else {
        // Fallback: simple wrap based on grid
        float world_height = grid->rows * grid->cell_size;
        ball->y -= world_height;
    }

    ball->passed_gate = 0;  // Reset scoring for new board
    return 0;  // Position changed, skip remaining physics this frame
}
// }}}

// {{{ zone_wrap_to_top
// Teleports ball from bottom of world to top.
// Adversary balls entering top wrap zone go to bottom.
// Resets passed_gate so ball can score again on new board.
static int zone_wrap_to_top(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)col; (void)row;

    World* world = grid->world;
    if (world && world->wrap_zones) {
        WrapZones* wz = world->wrap_zones;
        float top_zone_bottom = wz->top_zone_y + wz->zone_height;
        float offset_from_bottom = top_zone_bottom - ball->y;
        ball->y = wz->bottom_zone_y + wz->zone_height - offset_from_bottom;
    } else {
        // Fallback
        float world_height = grid->rows * grid->cell_size;
        ball->y += world_height;
    }

    ball->passed_gate = 0;
    return 0;
}
// }}}

// {{{ zone_wall_left
// Reflects ball off left wall boundary.
// Note: Wall collision is also handled in ball_collide_with_walls,
// this is for grid-based boundary detection (future use).
static int zone_wall_left(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)col; (void)row;

    float left_wall = grid->origin_x;
    if (ball->x - ball->radius < left_wall) {
        ball->x = left_wall + ball->radius;
        ball->vx = -ball->vx * 0.6f;  // Wall restitution
    }
    return 1;  // Continue physics
}
// }}}

// {{{ zone_wall_right
// Reflects ball off right wall boundary.
static int zone_wall_right(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)col; (void)row;

    float right_wall = grid->origin_x + (grid->cols * grid->cell_size);
    if (ball->x + ball->radius > right_wall) {
        ball->x = right_wall - ball->radius;
        ball->vx = -ball->vx * 0.6f;
    }
    return 1;
}
// }}}

// =============================================================================
// Zone Grid Creation/Destruction
// =============================================================================

// {{{ zone_grid_create
ZoneGrid* zone_grid_create(float origin_x, float origin_y, float cell_size,
                           int cols, int rows, World* world) {
    ZoneGrid* grid = (ZoneGrid*)malloc(sizeof(ZoneGrid));
    if (!grid) {
        fprintf(stderr, "ERROR: Failed to allocate zone grid\n");
        return NULL;
    }

    // Clamp dimensions to max
    if (cols > ZONE_GRID_MAX_COLS) cols = ZONE_GRID_MAX_COLS;
    if (rows > ZONE_GRID_MAX_ROWS) rows = ZONE_GRID_MAX_ROWS;

    grid->origin_x = origin_x;
    grid->origin_y = origin_y;
    grid->cell_size = cell_size;
    grid->cols = cols;
    grid->rows = rows;
    grid->world = world;

    // Initialize to all background
    zone_grid_init(grid);

    printf("Zone grid created: %dx%d cells, origin=(%.0f, %.0f), cell_size=%.0f\n",
           grid->cols, grid->rows, grid->origin_x, grid->origin_y, grid->cell_size);

    return grid;
}
// }}}

// {{{ zone_grid_destroy
void zone_grid_destroy(ZoneGrid* grid) {
    if (grid) {
        free(grid);
    }
}
// }}}

// =============================================================================
// Zone Grid Initialization
// =============================================================================

// {{{ zone_grid_init
void zone_grid_init(ZoneGrid* grid) {
    if (!grid) return;

    // Clear all cells to background (0)
    memset(grid->cells, DISPATCH_ZONE_BACKGROUND, sizeof(grid->cells));
    memset(grid->multipliers, 0, sizeof(grid->multipliers));

    grid->active_row_start = 0;
    grid->active_row_end = grid->rows;
}
// }}}

// {{{ zone_grid_set_gate_row
void zone_grid_set_gate_row(ZoneGrid* grid, int row, int multiplier) {
    if (!grid) return;
    if (row < 0 || row >= ZONE_GRID_MAX_ROWS) return;

    // Standard gate pattern for 14 columns:
    // 10, 20, 50, 100, 100, 200, 500, 500, 200, 100, 100, 50, 20, 10
    // Higher points in center, lower on edges
    static const DispatchZoneType gate_pattern[14] = {
        DISPATCH_ZONE_GATE_10, DISPATCH_ZONE_GATE_20, DISPATCH_ZONE_GATE_50, DISPATCH_ZONE_GATE_100,
        DISPATCH_ZONE_GATE_100, DISPATCH_ZONE_GATE_200, DISPATCH_ZONE_GATE_500, DISPATCH_ZONE_GATE_500,
        DISPATCH_ZONE_GATE_200, DISPATCH_ZONE_GATE_100, DISPATCH_ZONE_GATE_100, DISPATCH_ZONE_GATE_50,
        DISPATCH_ZONE_GATE_20, DISPATCH_ZONE_GATE_10
    };

    for (int c = 0; c < grid->cols && c < 14; c++) {
        grid->cells[row][c] = gate_pattern[c];
        grid->multipliers[row][c] = (uint8_t)multiplier;
    }

    printf("Zone grid: set gate row %d with multiplier %d\n", row, multiplier);
}
// }}}

// {{{ zone_grid_set_wrap_zones
void zone_grid_set_wrap_zones(ZoneGrid* grid, int top_row, int bottom_row) {
    if (!grid) return;

    // Set top wrap zone (balls here go to bottom)
    if (top_row >= 0 && top_row < ZONE_GRID_MAX_ROWS) {
        for (int c = 0; c < grid->cols; c++) {
            grid->cells[top_row][c] = DISPATCH_ZONE_WRAP_TO_BOTTOM;
        }
        printf("Zone grid: set top wrap zone at row %d\n", top_row);
    }

    // Set bottom wrap zone (balls here go to top)
    if (bottom_row >= 0 && bottom_row < ZONE_GRID_MAX_ROWS) {
        for (int c = 0; c < grid->cols; c++) {
            grid->cells[bottom_row][c] = DISPATCH_ZONE_WRAP_TO_TOP;
        }
        printf("Zone grid: set bottom wrap zone at row %d\n", bottom_row);
    }
}
// }}}

// {{{ zone_grid_set_walls
void zone_grid_set_walls(ZoneGrid* grid, int start_row, int end_row) {
    if (!grid) return;
    if (start_row < 0) start_row = 0;
    if (end_row > ZONE_GRID_MAX_ROWS) end_row = ZONE_GRID_MAX_ROWS;

    // Note: Wall zones are placeholders for now.
    // Wall collision is handled in ball_collide_with_walls.
    // These would be used for grid-based boundary detection.
    for (int r = start_row; r < end_row; r++) {
        // Leftmost cell is wall (column -1 would be out of bounds)
        // grid->cells[r][0] = ZONE_WALL_LEFT;
        // Rightmost cell is wall
        // grid->cells[r][grid->cols - 1] = ZONE_WALL_RIGHT;
    }
}
// }}}

// =============================================================================
// Zone Dispatch
// =============================================================================

// {{{ zone_dispatch
int zone_dispatch(Ball* ball, ZoneGrid* grid) {
    if (!ball || !grid) return 1;
    if (!ball->active) return 1;

    // Convert ball position to grid cell
    int col = (int)((ball->x - grid->origin_x) / grid->cell_size);
    int row = (int)((ball->y - grid->origin_y) / grid->cell_size);

    // Bounds check - out of grid is treated as background
    if (col < 0 || col >= grid->cols || row < 0 || row >= grid->rows) {
        return zone_background(ball, grid, col, row);
    }

    // Lookup zone type and dispatch via function pointer
    uint8_t zone_type = grid->cells[row][col];

    // Safety check for valid zone type
    if (zone_type >= DISPATCH_ZONE_TYPE_COUNT) {
        zone_type = DISPATCH_ZONE_BACKGROUND;
    }

    // Dispatch to handler
    return zone_functions[zone_type](ball, grid, col, row);
}
// }}}

// =============================================================================
// Zone Grid Expansion
// =============================================================================

// {{{ zone_grid_expand_down
void zone_grid_expand_down(ZoneGrid* grid, int new_rows) {
    if (!grid) return;
    if (new_rows <= 0) return;

    // Check if expansion would exceed max
    if (grid->rows + new_rows > ZONE_GRID_MAX_ROWS) {
        fprintf(stderr, "WARNING: Zone grid expansion would exceed max rows\n");
        new_rows = ZONE_GRID_MAX_ROWS - grid->rows;
    }

    if (new_rows > 0) {
        grid->rows += new_rows;
        grid->active_row_end = grid->rows;
        printf("Zone grid expanded: now %d rows\n", grid->rows);
    }
}
// }}}

// {{{ zone_grid_shift_content
void zone_grid_shift_content(ZoneGrid* grid, int shift_rows) {
    if (!grid) return;
    if (shift_rows <= 0) return;
    if (shift_rows >= ZONE_GRID_MAX_ROWS) return;

    // Shift content down by moving rows
    // Start from bottom to avoid overwriting data
    for (int r = ZONE_GRID_MAX_ROWS - 1; r >= shift_rows; r--) {
        int src_row = r - shift_rows;
        memcpy(grid->cells[r], grid->cells[src_row], grid->cols);
        memcpy(grid->multipliers[r], grid->multipliers[src_row], grid->cols);
    }

    // Clear the newly exposed rows at top
    for (int r = 0; r < shift_rows; r++) {
        memset(grid->cells[r], DISPATCH_ZONE_BACKGROUND, grid->cols);
        memset(grid->multipliers[r], 0, grid->cols);
    }

    // Update active range
    grid->active_row_start += shift_rows;
    grid->active_row_end += shift_rows;

    printf("Zone grid content shifted down by %d rows\n", shift_rows);
}
// }}}

// =============================================================================
// Zone Grid Query
// =============================================================================

// {{{ zone_grid_get_type
DispatchZoneType zone_grid_get_type(ZoneGrid* grid, int col, int row) {
    if (!grid) return DISPATCH_ZONE_BACKGROUND;
    if (col < 0 || col >= grid->cols) return DISPATCH_ZONE_BACKGROUND;
    if (row < 0 || row >= grid->rows) return DISPATCH_ZONE_BACKGROUND;

    return (DispatchZoneType)grid->cells[row][col];
}
// }}}

// {{{ zone_grid_get_multiplier
int zone_grid_get_multiplier(ZoneGrid* grid, int col, int row) {
    if (!grid) return 0;
    if (col < 0 || col >= grid->cols) return 0;
    if (row < 0 || row >= grid->rows) return 0;

    return grid->multipliers[row][col];
}
// }}}

// {{{ zone_grid_get_points_for_type
int zone_grid_get_points_for_type(DispatchZoneType type) {
    switch (type) {
        case DISPATCH_ZONE_GATE_10:  return 10;
        case DISPATCH_ZONE_GATE_20:  return 20;
        case DISPATCH_ZONE_GATE_50:  return 50;
        case DISPATCH_ZONE_GATE_100: return 100;
        case DISPATCH_ZONE_GATE_200: return 200;
        case DISPATCH_ZONE_GATE_500: return 500;
        default: return 0;
    }
}
// }}}

// =============================================================================
// Debug Rendering
// =============================================================================

// {{{ zone_grid_render_debug
void zone_grid_render_debug(ZoneGrid* grid) {
    if (!grid) return;

    // Color scheme for different zone types
    static const Color zone_colors[DISPATCH_ZONE_TYPE_COUNT] = {
        [DISPATCH_ZONE_BACKGROUND]     = {0, 0, 0, 0},           // Transparent
        [DISPATCH_ZONE_GATE_10]        = {50, 200, 50, 60},      // Light green
        [DISPATCH_ZONE_GATE_20]        = {80, 200, 80, 60},
        [DISPATCH_ZONE_GATE_50]        = {120, 200, 120, 60},
        [DISPATCH_ZONE_GATE_100]       = {180, 220, 100, 60},    // Yellow-green
        [DISPATCH_ZONE_GATE_200]       = {220, 180, 80, 60},     // Orange
        [DISPATCH_ZONE_GATE_500]       = {220, 100, 100, 60},    // Red
        [DISPATCH_ZONE_WRAP_TO_BOTTOM] = {50, 100, 255, 80},     // Blue
        [DISPATCH_ZONE_WRAP_TO_TOP]    = {255, 100, 50, 80},     // Red-orange
        [DISPATCH_ZONE_WALL_LEFT]      = {100, 100, 100, 100},   // Gray
        [DISPATCH_ZONE_WALL_RIGHT]     = {100, 100, 100, 100},
        [DISPATCH_ZONE_PORTAL_ENTRY]   = {200, 50, 200, 60},     // Purple
        [DISPATCH_ZONE_PORTAL_EXIT]    = {200, 100, 200, 60},
        [DISPATCH_ZONE_ROTOR_AREA]     = {50, 200, 200, 60},     // Cyan
        [DISPATCH_ZONE_MOVER_AREA]     = {200, 200, 50, 60},     // Yellow
    };

    float cell_size = grid->cell_size;

    for (int r = 0; r < grid->rows; r++) {
        for (int c = 0; c < grid->cols; c++) {
            DispatchZoneType type = (DispatchZoneType)grid->cells[r][c];
            if (type == DISPATCH_ZONE_BACKGROUND) continue;

            Color color = zone_colors[type];
            float x = grid->origin_x + c * cell_size;
            float y = grid->origin_y + r * cell_size;

            DrawRectangle((int)x, (int)y, (int)cell_size, (int)cell_size, color);

            // Draw multiplier indicator for gate zones
            if (type >= DISPATCH_ZONE_GATE_10 && type <= DISPATCH_ZONE_GATE_500) {
                int mult = grid->multipliers[r][c];
                if (mult > 0) {
                    char mult_str[4];
                    snprintf(mult_str, sizeof(mult_str), "%dx", mult + 1);
                    DrawText(mult_str, (int)(x + 2), (int)(y + 2), 10, WHITE);
                }
            }
        }
    }
}
// }}}
