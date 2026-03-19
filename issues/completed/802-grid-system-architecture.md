# 802 - Grid System Architecture

## Current Behavior

Objects are positioned using absolute pixel coordinates:

```c
// src/005-world.c:69-85 - Peg generation uses spacing directly
float y = start_y;
for (int row = 0; row < rows; row++) {
    float x = start_x;
    if (row % 2 == 1) {
        x += spacing / 2;  // Stagger odd rows
    }
    for (int col = 0; col < cols; col++) {
        pegs[index].x = x;
        pegs[index].y = y;
        x += spacing;
    }
    y += spacing;
}
```

There's no unified grid system - spacing is applied ad-hoc during generation.

## Intended Behavior

Create a grid system that:
1. Defines a consistent coordinate space for object placement
2. Provides snap-to-grid functionality for the editor
3. Handles coordinate conversion (grid <-> pixel)
4. Supports optional stagger for peg layouts
5. Is rendered as a visual overlay in editor mode

## Suggested Implementation Steps

### Step 1: Define grid constants

```c
// src/022-grid.h

#define DEFAULT_GRID_CELL_SIZE 60.0f
#define DEFAULT_GRID_COLS 14
#define DEFAULT_GRID_ROWS 12

// Grid rendering
#define GRID_LINE_COLOR (Color){60, 60, 80, 100}
#define GRID_MAJOR_LINE_COLOR (Color){80, 80, 100, 150}
#define GRID_MAJOR_INTERVAL 5  // Every 5th line is major
```

### Step 2: Define Grid struct

```c
typedef struct Grid {
    float cell_size;       // Size of each grid cell in pixels
    int cols;              // Number of columns
    int rows;              // Number of rows

    float origin_x;        // Pixel position of grid origin (top-left)
    float origin_y;

    int stagger_odd_rows;  // If 1, odd rows offset by half cell
} Grid;
```

### Step 3: Create grid functions

```c
// Create a grid with given dimensions
Grid grid_create(int cols, int rows, float cell_size,
                 float origin_x, float origin_y);

// Convert grid coordinates to pixel coordinates
// Returns center of the grid cell
float grid_to_pixel_x(Grid* grid, int col, int row);
float grid_to_pixel_y(Grid* grid, int col, int row);

// Convert pixel coordinates to grid coordinates
// Returns nearest grid cell
int pixel_to_grid_col(Grid* grid, float x, float y);
int pixel_to_grid_row(Grid* grid, float x, float y);

// Snap pixel coordinates to nearest grid intersection
float snap_to_grid_x(Grid* grid, float x, float y);
float snap_to_grid_y(Grid* grid, float x, float y);

// Check if grid coordinates are within bounds
int grid_in_bounds(Grid* grid, int col, int row);

// Render grid overlay (editor mode only)
void grid_render(Grid* grid, Camera2D camera);
```

### Step 4: Implement stagger logic

The stagger affects X position based on row:

```c
float grid_to_pixel_x(Grid* grid, int col, int row) {
    float x = grid->origin_x + (col * grid->cell_size) + (grid->cell_size / 2.0f);

    // Apply stagger for odd rows
    if (grid->stagger_odd_rows && (row % 2 == 1)) {
        x += grid->cell_size / 2.0f;
    }

    return x;
}

float grid_to_pixel_y(Grid* grid, int col, int row) {
    (void)col;  // Column doesn't affect Y
    return grid->origin_y + (row * grid->cell_size) + (grid->cell_size / 2.0f);
}
```

### Step 5: Implement snap-to-grid

```c
int pixel_to_grid_col(Grid* grid, float x, float y) {
    // Get row first (needed for stagger calculation)
    int row = pixel_to_grid_row(grid, x, y);

    float adjusted_x = x - grid->origin_x;

    // Reverse stagger offset for odd rows
    if (grid->stagger_odd_rows && (row % 2 == 1)) {
        adjusted_x -= grid->cell_size / 2.0f;
    }

    int col = (int)(adjusted_x / grid->cell_size);

    // Clamp to valid range
    if (col < 0) col = 0;
    if (col >= grid->cols) col = grid->cols - 1;

    return col;
}
```

### Step 6: Implement grid rendering

```c
void grid_render(Grid* grid, Camera2D camera) {
    // Vertical lines
    for (int col = 0; col <= grid->cols; col++) {
        float x = grid->origin_x + (col * grid->cell_size);
        float y1 = grid->origin_y;
        float y2 = grid->origin_y + (grid->rows * grid->cell_size);

        Color color = (col % GRID_MAJOR_INTERVAL == 0) ?
            GRID_MAJOR_LINE_COLOR : GRID_LINE_COLOR;
        DrawLine((int)x, (int)y1, (int)x, (int)y2, color);
    }

    // Horizontal lines
    for (int row = 0; row <= grid->rows; row++) {
        float x1 = grid->origin_x;
        float x2 = grid->origin_x + (grid->cols * grid->cell_size);
        float y = grid->origin_y + (row * grid->cell_size);

        Color color = (row % GRID_MAJOR_INTERVAL == 0) ?
            GRID_MAJOR_LINE_COLOR : GRID_LINE_COLOR;
        DrawLine((int)x1, (int)y, (int)x2, (int)y, color);
    }
}
```

### Step 7: Add stagger visualization (optional)

For staggered grids, show offset dots at staggered positions:

```c
void grid_render_stagger_hints(Grid* grid) {
    if (!grid->stagger_odd_rows) return;

    for (int row = 1; row < grid->rows; row += 2) {  // Odd rows only
        for (int col = 0; col < grid->cols; col++) {
            float x = grid_to_pixel_x(grid, col, row);
            float y = grid_to_pixel_y(grid, col, row);
            DrawCircle((int)x, (int)y, 2, (Color){100, 100, 150, 100});
        }
    }
}
```

## Grid Coordinate System

```
Origin (0,0)
    +-----+-----+-----+-----+
    | 0,0 | 1,0 | 2,0 | 3,0 |  Row 0
    +-----+-----+-----+-----+
      | 0,1 | 1,1 | 2,1 |      Row 1 (staggered)
    +-----+-----+-----+-----+
    | 0,2 | 1,2 | 2,2 | 3,2 |  Row 2
    +-----+-----+-----+-----+
```

With stagger enabled, odd rows are offset by half a cell width. This matches the current pachinko peg layout.

## Files to Create

- `src/022-grid.h` - Grid struct and function declarations
- `src/023-grid.c` - Grid implementation

## Testing

1. Create grid with default dimensions
2. Convert (0,0) to pixels - should return cell center
3. Convert (0,1) to pixels with stagger - should be offset
4. Convert pixel near cell corner - should snap to nearest cell
5. Verify grid renders correctly overlaid on existing board
6. Test boundary conditions (negative coords, out of bounds)

## Related Issues

- 1101-board-data-format.md (uses grid for coordinate storage)
- 1106-object-placement.md (uses grid for snapping)
