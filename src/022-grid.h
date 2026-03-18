// src/022-grid.h
// Grid system for coordinate conversion and snap-to-grid functionality
// Provides mapping between grid cells and pixel positions

#ifndef GRID_H
#define GRID_H

#include "raylib.h"

// =============================================================================
// Grid Constants
// =============================================================================

#define DEFAULT_GRID_CELL_SIZE 60.0f
#define DEFAULT_GRID_COLS 14
#define DEFAULT_GRID_ROWS 12

// Grid rendering colors
#define GRID_LINE_COLOR (Color){60, 60, 80, 100}
#define GRID_MAJOR_LINE_COLOR (Color){80, 80, 100, 150}
#define GRID_MAJOR_INTERVAL 5

// =============================================================================
// Grid Structure
// =============================================================================

// {{{ typedef struct Grid
// Grid defines the coordinate space for object placement.
// Provides conversion between grid cells and pixel coordinates.
typedef struct Grid {
    float cell_size;      // Size of each grid cell in pixels
    int cols;             // Number of columns
    int rows;             // Number of rows

    float origin_x;       // Pixel position of grid origin (top-left)
    float origin_y;

    float width;          // Total width in pixels (cols * cell_size)
    float height;         // Total height in pixels (rows * cell_size)
} Grid;
// }}}

// =============================================================================
// Grid Creation
// =============================================================================

// {{{ grid_create
// Creates a grid with the given dimensions.
// Origin is the top-left corner of the grid in pixel coordinates.
Grid grid_create(int cols, int rows, float cell_size,
                 float origin_x, float origin_y);
// }}}

// {{{ grid_create_default
// Creates a grid with default dimensions (14x12, 60px cells).
// Origin defaults to (0, 0).
Grid grid_create_default(void);
// }}}

// =============================================================================
// Coordinate Conversion
// =============================================================================

// {{{ grid_to_pixel_x
// Converts grid column to pixel X coordinate.
// Returns the center of the grid cell.
float grid_to_pixel_x(Grid* grid, int col, int row);
// }}}

// {{{ grid_to_pixel_y
// Converts grid row to pixel Y coordinate.
// Returns the center of the grid cell.
float grid_to_pixel_y(Grid* grid, int col, int row);
// }}}

// {{{ grid_to_pixel
// Converts grid coordinates to pixel position (cell center).
// Returns Vector2 with x and y.
Vector2 grid_to_pixel(Grid* grid, int col, int row);
// }}}

// {{{ pixel_to_grid_col
// Converts pixel X coordinate to nearest grid column.
// Clamps to valid range [0, cols-1].
int pixel_to_grid_col(Grid* grid, float x);
// }}}

// {{{ pixel_to_grid_row
// Converts pixel Y coordinate to nearest grid row.
// Clamps to valid range [0, rows-1].
int pixel_to_grid_row(Grid* grid, float y);
// }}}

// {{{ pixel_to_grid
// Converts pixel position to nearest grid coordinates.
// Returns col in x, row in y as integers via pointers.
void pixel_to_grid(Grid* grid, float x, float y, int* out_col, int* out_row);
// }}}

// =============================================================================
// Snap-to-Grid
// =============================================================================

// {{{ snap_to_grid
// Snaps a pixel position to the nearest grid cell center.
// Returns the snapped position.
Vector2 snap_to_grid(Grid* grid, float x, float y);
// }}}

// {{{ snap_to_grid_x
// Snaps a pixel X coordinate to the nearest grid cell center X.
float snap_to_grid_x(Grid* grid, float x);
// }}}

// {{{ snap_to_grid_y
// Snaps a pixel Y coordinate to the nearest grid cell center Y.
float snap_to_grid_y(Grid* grid, float y);
// }}}

// =============================================================================
// Bounds Checking
// =============================================================================

// {{{ grid_in_bounds
// Checks if grid coordinates are within valid range.
// Returns 1 if valid, 0 if out of bounds.
int grid_in_bounds(Grid* grid, int col, int row);
// }}}

// {{{ grid_pixel_in_bounds
// Checks if pixel coordinates are within grid area.
// Returns 1 if within grid, 0 if outside.
int grid_pixel_in_bounds(Grid* grid, float x, float y);
// }}}

// =============================================================================
// Grid Rendering
// =============================================================================

// {{{ grid_render
// Renders the grid as an overlay.
// Should be called in editor mode only.
void grid_render(Grid* grid);
// }}}

// {{{ grid_render_cell_highlight
// Highlights a specific grid cell.
// Useful for showing hover position in editor.
void grid_render_cell_highlight(Grid* grid, int col, int row, Color color);
// }}}

#endif // GRID_H
