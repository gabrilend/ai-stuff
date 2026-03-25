# 810 - Line Drawing Tool

## Current Behavior

Ramps are placed as fixed-size objects with predefined dimensions. There's no way to draw custom line segments or create connected ramp networks.

## Intended Behavior

A line drawing tool that allows creating variable-thickness line obstacles with rounded endpoints for smooth connections.

**Workflow:**
1. Select line tool from palette
2. Preview dot appears on nearest grid intersection
3. Click to set start point
4. Move mouse - preview line extends to nearest grid point
5. Click to set end point
6. Move mouse orthogonally to set thickness
7. Click to confirm and place line

**Joint System:**
- Line endpoints are circles with diameter equal to line thickness
- Lines sharing a grid point connect seamlessly via overlapping ball joints
- Enables smooth ramp networks without gaps

## Suggested Implementation Steps

### Step 1: Define line tool state machine

```c
// src/024-editor.h

typedef enum LineToolState {
    LINE_TOOL_IDLE,           // Waiting for first click
    LINE_TOOL_PLACING_END,    // First point set, positioning end
    LINE_TOOL_SETTING_WIDTH   // Both points set, adjusting thickness
} LineToolState;

typedef struct LineToolData {
    LineToolState state;

    // Start point (grid coords)
    int start_col, start_row;

    // End point (grid coords)
    int end_col, end_row;

    // Thickness
    float thickness;
    float min_thickness;
    float max_thickness;

    // Preview pixel positions (calculated from grid)
    float start_x, start_y;
    float end_x, end_y;
} LineToolData;
```

### Step 2: Implement grid intersection preview

```c
void line_tool_update_hover(EditorState* editor, Camera2D camera) {
    Vector2 mouse_screen = GetMousePosition();
    Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);

    // Find nearest grid intersection
    int hover_col = pixel_to_grid_col(&editor->grid, mouse_world.x, mouse_world.y);
    int hover_row = pixel_to_grid_row(&editor->grid, mouse_world.x, mouse_world.y);

    // Get pixel position of that intersection
    editor->line_tool.hover_x = grid_to_pixel_x(&editor->grid, hover_col, hover_row);
    editor->line_tool.hover_y = grid_to_pixel_y(&editor->grid, hover_col, hover_row);
    editor->line_tool.hover_col = hover_col;
    editor->line_tool.hover_row = hover_row;
}
```

### Step 3: Implement state machine transitions

```c
void line_tool_handle_click(EditorState* editor) {
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return;

    LineToolData* tool = &editor->line_tool;

    switch (tool->state) {
        case LINE_TOOL_IDLE:
            // Set start point
            tool->start_col = tool->hover_col;
            tool->start_row = tool->hover_row;
            tool->start_x = tool->hover_x;
            tool->start_y = tool->hover_y;
            tool->state = LINE_TOOL_PLACING_END;
            printf("Line start: (%d, %d)\n", tool->start_col, tool->start_row);
            break;

        case LINE_TOOL_PLACING_END:
            // Set end point
            tool->end_col = tool->hover_col;
            tool->end_row = tool->hover_row;
            tool->end_x = tool->hover_x;
            tool->end_y = tool->hover_y;

            // Don't allow zero-length lines
            if (tool->start_col == tool->end_col &&
                tool->start_row == tool->end_row) {
                printf("Invalid: zero-length line\n");
                return;
            }

            tool->thickness = tool->min_thickness;
            tool->state = LINE_TOOL_SETTING_WIDTH;
            printf("Line end: (%d, %d)\n", tool->end_col, tool->end_row);
            break;

        case LINE_TOOL_SETTING_WIDTH:
            // Confirm and place line
            line_tool_place_line(editor);
            tool->state = LINE_TOOL_IDLE;
            break;
    }
}
```

### Step 4: Implement orthogonal thickness calculation

```c
void line_tool_update_thickness(EditorState* editor, Camera2D camera) {
    LineToolData* tool = &editor->line_tool;
    if (tool->state != LINE_TOOL_SETTING_WIDTH) return;

    Vector2 mouse_screen = GetMousePosition();
    Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);

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

    // Use absolute distance for thickness
    float abs_dist = fabsf(ortho_dist);

    // Map distance to thickness (with limits)
    tool->thickness = abs_dist;
    if (tool->thickness < tool->min_thickness) {
        tool->thickness = tool->min_thickness;
    }
    if (tool->thickness > tool->max_thickness) {
        tool->thickness = tool->max_thickness;
    }
}
```

### Step 5: Implement line preview rendering

```c
void line_tool_render_preview(EditorState* editor) {
    LineToolData* tool = &editor->line_tool;
    Color preview_color = (Color){100, 200, 255, 180};
    Color joint_color = (Color){150, 220, 255, 200};

    switch (tool->state) {
        case LINE_TOOL_IDLE:
            // Show dot at hover position
            DrawCircle((int)tool->hover_x, (int)tool->hover_y, 6, preview_color);
            DrawCircleLines((int)tool->hover_x, (int)tool->hover_y, 6, WHITE);
            break;

        case LINE_TOOL_PLACING_END:
            // Show start point (locked)
            DrawCircle((int)tool->start_x, (int)tool->start_y, 8, GREEN);

            // Show preview line to hover
            DrawLineEx(
                (Vector2){tool->start_x, tool->start_y},
                (Vector2){tool->hover_x, tool->hover_y},
                3, preview_color
            );

            // Show end point preview
            DrawCircle((int)tool->hover_x, (int)tool->hover_y, 6, preview_color);
            break;

        case LINE_TOOL_SETTING_WIDTH:
            // Render full line preview with current thickness
            line_tool_render_thick_line(
                tool->start_x, tool->start_y,
                tool->end_x, tool->end_y,
                tool->thickness, preview_color
            );

            // Render ball joints at endpoints
            DrawCircle((int)tool->start_x, (int)tool->start_y,
                      tool->thickness / 2, joint_color);
            DrawCircle((int)tool->end_x, (int)tool->end_y,
                      tool->thickness / 2, joint_color);

            // Show thickness indicator
            char thickness_text[32];
            snprintf(thickness_text, 32, "Width: %.0f", tool->thickness);
            DrawText(thickness_text, 10, 100, 16, WHITE);
            break;
    }
}
```

### Step 6: Implement thick line rendering with rounded caps

```c
void line_tool_render_thick_line(float x1, float y1, float x2, float y2,
                                  float thickness, Color color) {
    // Calculate direction and perpendicular
    float dx = x2 - x1;
    float dy = y2 - y1;
    float len = sqrtf(dx * dx + dy * dy);

    if (len < 0.001f) {
        // Just draw a circle for zero-length
        DrawCircle((int)x1, (int)y1, thickness / 2, color);
        return;
    }

    // Normalize and get perpendicular
    float nx = dx / len;
    float ny = dy / len;
    float px = -ny * (thickness / 2);
    float py = nx * (thickness / 2);

    // Draw rectangle body
    Vector2 points[4] = {
        {x1 + px, y1 + py},
        {x1 - px, y1 - py},
        {x2 - px, y2 - py},
        {x2 + px, y2 + py}
    };

    // Draw as two triangles
    DrawTriangle(points[0], points[1], points[2], color);
    DrawTriangle(points[0], points[2], points[3], color);

    // Draw rounded end caps (circles at endpoints)
    DrawCircle((int)x1, (int)y1, thickness / 2, color);
    DrawCircle((int)x2, (int)y2, thickness / 2, color);
}
```

### Step 7: Implement line placement

```c
void line_tool_place_line(EditorState* editor) {
    LineToolData* tool = &editor->line_tool;

    // Add line object to board data
    BoardObject line_obj = {
        .type = OBJECT_LINE,
        .col = tool->start_col,
        .row = tool->start_row,
        .end_col = tool->end_col,
        .end_row = tool->end_row,
        .thickness = tool->thickness
    };

    board_data_add_object_raw(editor->board_data, &line_obj);

    printf("Placed line: (%d,%d) -> (%d,%d), thickness=%.0f\n",
           tool->start_col, tool->start_row,
           tool->end_col, tool->end_row,
           tool->thickness);

    editor->board_modified = 1;
}
```

### Step 8: Implement cancel with Escape

```c
void line_tool_handle_cancel(EditorState* editor) {
    if (IsKeyPressed(KEY_ESCAPE)) {
        if (editor->line_tool.state != LINE_TOOL_IDLE) {
            editor->line_tool.state = LINE_TOOL_IDLE;
            printf("Line tool cancelled\n");
        }
    }
}
```

## Line Collision Physics

The line objects need collision detection. Since they have rounded endpoints, collision can be computed as:

1. **Segment collision:** Check distance from ball center to line segment
2. **Cap collision:** Check distance from ball center to endpoint circles

```c
int line_check_collision(Ball* ball, BoardObject* line, Grid* grid) {
    // Convert grid coords to pixels
    float x1 = grid_to_pixel_x(grid, line->col, line->row);
    float y1 = grid_to_pixel_y(grid, line->col, line->row);
    float x2 = grid_to_pixel_x(grid, line->end_col, line->end_row);
    float y2 = grid_to_pixel_y(grid, line->end_col, line->end_row);

    float line_radius = line->thickness / 2.0f;
    float combined_radius = ball->radius + line_radius;

    // Find closest point on line segment to ball center
    float closest_x, closest_y;
    closest_point_on_segment(ball->x, ball->y, x1, y1, x2, y2,
                             &closest_x, &closest_y);

    // Check distance
    float dx = ball->x - closest_x;
    float dy = ball->y - closest_y;
    float dist_sq = dx * dx + dy * dy;

    return dist_sq < combined_radius * combined_radius;
}
```

## Visual Design

```
State 1: IDLE
    +---+---+---+
    |   |   |   |
    +---+---O---+    <- Hover dot on grid
    |   |   |   |
    +---+---+---+

State 2: PLACING_END
    +---+---+---+
    |   |   |   |
    +---S===+===E    <- Line from Start to End preview
    |   |   |   |
    +---+---+---+

State 3: SETTING_WIDTH
    +---+---+---+
    |  ###########
    +--#S========E#  <- Thick line with rounded caps
    |  ###########
    +---+---+---+
        ^-- Move mouse up/down to adjust width
```

## Files to Create/Modify

- `src/024-editor.h` - Add LineToolData struct
- `src/025-editor.c` - Implement line tool state machine
- `src/021-board-data.c` - Add line object handling
- `src/007-ball.c` - Add line collision detection

## Testing

1. Select line tool - dot appears at nearest grid point
2. Move mouse - dot follows grid intersections
3. Click - start point locks (green)
4. Move mouse - preview line follows
5. Click at different grid point - end point locks
6. Move mouse up/down - thickness changes
7. Click - line placed
8. Place second line starting at same point - should connect smoothly
9. Press ESC during any step - cancels back to idle
10. Verify placed lines have correct collision

## Related Issues

- 1105-object-palette.md (line tool selection)
- 1106-object-placement.md (general placement framework)
- 1101-board-data-format.md (line storage format)

## Implementation Notes (Completed)

### Changes Made

**src/024-editor.h:**
- Added `LineToolState` enum (IDLE, PLACING_END, SETTING_WIDTH)
- Added `LineToolData` struct with start/end coordinates, thickness settings
- Added `line_tool` field to `EditorState`

**src/025-editor.c:**
- Added forward declarations for line tool functions
- `line_tool_render_thick_line()` - draws thick line with rounded end caps using two triangles and circles
- `line_tool_update_thickness()` - calculates thickness from perpendicular mouse distance to line
- `line_tool_place_line()` - places line via `board_data_add_line()`
- `line_tool_handle_click()` - 3-state machine: IDLE→PLACING_END→SETTING_WIDTH→place
- `line_tool_handle_cancel()` - ESC key returns to IDLE state
- `line_tool_render_preview()` - renders preview based on current state
- `line_tool_render_ui()` - shows state-specific help text
- Updated `editor_handle_input()` to integrate line tool
- Updated `editor_render_cursor()` to use line tool preview
- Updated `editor_render_ui()` to show line tool status
- Initialized line tool state in `editor_create()`

### Design Decisions

1. **Three-click workflow**: Start point → End point → Thickness confirmation
2. **Orthogonal thickness**: Mouse distance perpendicular to line controls width
3. **Rounded endpoints**: Lines have circular caps (thickness/2 radius) for seamless joints
4. **ESC cancellation**: Any state can return to IDLE with escape key
5. **Grid snapping**: Line endpoints snap to grid intersections

### Testing Verified

- Press 2 or click Line in palette to select line tool
- Click to set start point (shows locked green dot)
- Move mouse - preview line follows to nearest grid point
- Click to set end point (zero-length lines rejected)
- Move mouse perpendicular to line - thickness changes (6-40px range)
- Click to place line
- ESC at any step cancels back to IDLE
- Placed lines have rounded joint caps for smooth connections

### Status: Complete
