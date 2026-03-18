// src/023-grid.c
// Grid system implementation
// Handles coordinate conversion between grid cells and pixels

#include "022-grid.h"
#include <math.h>

// =============================================================================
// Grid Creation
// =============================================================================

// {{{ grid_create
Grid grid_create(int cols, int rows, float cell_size,
                 float origin_x, float origin_y) {
    Grid grid;
    grid.cols = cols;
    grid.rows = rows;
    grid.cell_size = cell_size;
    grid.origin_x = origin_x;
    grid.origin_y = origin_y;
    grid.width = cols * cell_size;
    grid.height = rows * cell_size;
    return grid;
}
// }}}

// {{{ grid_create_default
Grid grid_create_default(void) {
    return grid_create(DEFAULT_GRID_COLS, DEFAULT_GRID_ROWS,
                       DEFAULT_GRID_CELL_SIZE, 0.0f, 0.0f);
}
// }}}

// =============================================================================
// Coordinate Conversion
// =============================================================================

// {{{ grid_to_pixel_x
float grid_to_pixel_x(Grid* grid, int col, int row) {
    (void)row;  // Row doesn't affect X in this simple grid
    // Return grid line intersection (not cell center)
    return grid->origin_x + (col * grid->cell_size);
}
// }}}

// {{{ grid_to_pixel_y
float grid_to_pixel_y(Grid* grid, int col, int row) {
    (void)col;  // Col doesn't affect Y in this simple grid
    // Return grid line intersection (not cell center)
    return grid->origin_y + (row * grid->cell_size);
}
// }}}

// {{{ grid_to_pixel
Vector2 grid_to_pixel(Grid* grid, int col, int row) {
    Vector2 result;
    result.x = grid_to_pixel_x(grid, col, row);
    result.y = grid_to_pixel_y(grid, col, row);
    return result;
}
// }}}

// {{{ pixel_to_grid_col
int pixel_to_grid_col(Grid* grid, float x) {
    float relative_x = x - grid->origin_x;
    // Round to nearest intersection (not floor to cell)
    int col = (int)roundf(relative_x / grid->cell_size);

    // Clamp to valid range (0 to cols inclusive for intersections)
    if (col < 0) col = 0;
    if (col > grid->cols) col = grid->cols;

    return col;
}
// }}}

// {{{ pixel_to_grid_row
int pixel_to_grid_row(Grid* grid, float y) {
    float relative_y = y - grid->origin_y;
    // Round to nearest intersection (not floor to cell)
    int row = (int)roundf(relative_y / grid->cell_size);

    // Clamp to valid range (0 to rows inclusive for intersections)
    if (row < 0) row = 0;
    if (row > grid->rows) row = grid->rows;

    return row;
}
// }}}

// {{{ pixel_to_grid
void pixel_to_grid(Grid* grid, float x, float y, int* out_col, int* out_row) {
    *out_col = pixel_to_grid_col(grid, x);
    *out_row = pixel_to_grid_row(grid, y);
}
// }}}

// =============================================================================
// Snap-to-Grid
// =============================================================================

// {{{ snap_to_grid_x
float snap_to_grid_x(Grid* grid, float x) {
    int col = pixel_to_grid_col(grid, x);
    return grid_to_pixel_x(grid, col, 0);
}
// }}}

// {{{ snap_to_grid_y
float snap_to_grid_y(Grid* grid, float y) {
    int row = pixel_to_grid_row(grid, y);
    return grid_to_pixel_y(grid, 0, row);
}
// }}}

// {{{ snap_to_grid
Vector2 snap_to_grid(Grid* grid, float x, float y) {
    Vector2 result;
    int col = pixel_to_grid_col(grid, x);
    int row = pixel_to_grid_row(grid, y);
    result.x = grid_to_pixel_x(grid, col, row);
    result.y = grid_to_pixel_y(grid, col, row);
    return result;
}
// }}}

// =============================================================================
// Bounds Checking
// =============================================================================

// {{{ grid_in_bounds
int grid_in_bounds(Grid* grid, int col, int row) {
    return (col >= 0 && col < grid->cols &&
            row >= 0 && row < grid->rows);
}
// }}}

// {{{ grid_pixel_in_bounds
int grid_pixel_in_bounds(Grid* grid, float x, float y) {
    return (x >= grid->origin_x && x < grid->origin_x + grid->width &&
            y >= grid->origin_y && y < grid->origin_y + grid->height);
}
// }}}

// =============================================================================
// Grid Rendering
// =============================================================================

// {{{ grid_render
void grid_render(Grid* grid) {
    // Draw vertical lines
    for (int col = 0; col <= grid->cols; col++) {
        float x = grid->origin_x + (col * grid->cell_size);
        float y1 = grid->origin_y;
        float y2 = grid->origin_y + grid->height;

        Color color = (col % GRID_MAJOR_INTERVAL == 0) ?
            GRID_MAJOR_LINE_COLOR : GRID_LINE_COLOR;

        DrawLineV((Vector2){x, y1}, (Vector2){x, y2}, color);
    }

    // Draw horizontal lines
    for (int row = 0; row <= grid->rows; row++) {
        float x1 = grid->origin_x;
        float x2 = grid->origin_x + grid->width;
        float y = grid->origin_y + (row * grid->cell_size);

        Color color = (row % GRID_MAJOR_INTERVAL == 0) ?
            GRID_MAJOR_LINE_COLOR : GRID_LINE_COLOR;

        DrawLineV((Vector2){x1, y}, (Vector2){x2, y}, color);
    }

    // Draw cell center dots (subtle)
    Color dot_color = (Color){80, 80, 100, 50};
    for (int col = 0; col < grid->cols; col++) {
        for (int row = 0; row < grid->rows; row++) {
            float x = grid_to_pixel_x(grid, col, row);
            float y = grid_to_pixel_y(grid, col, row);
            DrawCircleV((Vector2){x, y}, 2, dot_color);
        }
    }
}
// }}}

// {{{ grid_render_cell_highlight
void grid_render_cell_highlight(Grid* grid, int col, int row, Color color) {
    if (!grid_in_bounds(grid, col, row)) return;

    float x = grid->origin_x + (col * grid->cell_size);
    float y = grid->origin_y + (row * grid->cell_size);

    // Draw filled rectangle with transparency
    DrawRectangle((int)x, (int)y, (int)grid->cell_size, (int)grid->cell_size, color);

    // Draw border
    Color border = color;
    border.a = 200;
    DrawRectangleLines((int)x, (int)y, (int)grid->cell_size, (int)grid->cell_size, border);
}
// }}}
