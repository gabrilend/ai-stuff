// src/022-grid.h
// Grid system for coordinate conversion and snap-to-grid functionality
// Provides mapping between grid cells and pixel positions

#ifndef GRID_H
#define GRID_H

#include "raylib.h"

// =============================================================================
// Grid Constants
// =============================================================================

// Fixed board dimensions (issue 838)
// All boards use same canvas size - cell size is calculated from grid density
// 602x946 is the standard board size (14x22 grid at 43px cells originally)
#define BOARD_WIDTH 602.0f
#define BOARD_HEIGHT 946.0f

// Default grid density (cells per board)
// Cell dimensions are calculated: cell_width = BOARD_WIDTH / cols, cell_height = BOARD_HEIGHT / rows
// With default 14x22 grid on 602x946 board: cell_width = 43px, cell_height = 43px (square)
// Other grid dimensions will have rectangular cells
#define DEFAULT_GRID_COLS 14
#define DEFAULT_GRID_ROWS 22

// Default cell dimensions for 14x22 grid (issue 1003)
// These are only equal because 602/14 = 946/22 = 43
#define DEFAULT_GRID_CELL_WIDTH (BOARD_WIDTH / DEFAULT_GRID_COLS)
#define DEFAULT_GRID_CELL_HEIGHT (BOARD_HEIGHT / DEFAULT_GRID_ROWS)

// Legacy constant for backwards compatibility during refactor (issue 1003)
// TODO: Remove once all code uses cell_width/cell_height
#define DEFAULT_GRID_CELL_SIZE 43.0f

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
// Issue 1003: Supports rectangular cells (cell_width != cell_height)
typedef struct Grid {
    float cell_width;     // Width of each grid cell in pixels (BOARD_WIDTH / cols)
    float cell_height;    // Height of each grid cell in pixels (BOARD_HEIGHT / rows)
    int cols;             // Number of columns
    int rows;             // Number of rows

    float origin_x;       // Pixel position of grid origin (top-left)
    float origin_y;

    float width;          // Total width in pixels (cols * cell_width)
    float height;         // Total height in pixels (rows * cell_height)
} Grid;
// }}}

// =============================================================================
// Grid Creation
// =============================================================================

// {{{ grid_create
// Creates a grid with the given dimensions.
// Origin is the top-left corner of the grid in pixel coordinates.
// Issue 1003: Takes separate cell_width and cell_height for rectangular cells
Grid grid_create(int cols, int rows, float cell_width, float cell_height,
                 float origin_x, float origin_y);
// }}}

// {{{ grid_create_default
// Creates a grid with default dimensions (12x20, 50px cells).
// Origin defaults to (0, 0).
Grid grid_create_default(void);
// }}}

// =============================================================================
// Coordinate Conversion
// =============================================================================

// {{{ grid_to_pixel_x
// Converts grid column to pixel X coordinate.
// Returns the grid line intersection point.
float grid_to_pixel_x(Grid* grid, int col, int row);
// }}}

// {{{ grid_to_pixel_y
// Converts grid row to pixel Y coordinate.
// Returns the grid line intersection point.
float grid_to_pixel_y(Grid* grid, int col, int row);
// }}}

// {{{ grid_to_pixel
// Converts grid coordinates to pixel position (intersection point).
// Returns Vector2 with x and y.
Vector2 grid_to_pixel(Grid* grid, int col, int row);
// }}}

// {{{ pixel_to_grid_col
// Converts pixel X coordinate to nearest grid intersection column.
// Clamps to valid range [0, cols].
int pixel_to_grid_col(Grid* grid, float x);
// }}}

// {{{ pixel_to_grid_row
// Converts pixel Y coordinate to nearest grid intersection row.
// Clamps to valid range [0, rows].
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
// Snaps a pixel position to the nearest grid intersection.
// Returns the snapped position.
Vector2 snap_to_grid(Grid* grid, float x, float y);
// }}}

// {{{ snap_to_grid_x
// Snaps a pixel X coordinate to the nearest grid intersection X.
float snap_to_grid_x(Grid* grid, float x);
// }}}

// {{{ snap_to_grid_y
// Snaps a pixel Y coordinate to the nearest grid intersection Y.
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
