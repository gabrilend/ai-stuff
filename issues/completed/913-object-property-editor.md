# 1113 - Object Property Editor

## Current Behavior

Pegs and ramps have fixed physics properties defined as constants:

```c
// src/007-ball.c
#define RESTITUTION 0.7f

// src/016-ramp.h
#define RAMP_RESTITUTION 0.1f
```

All objects of the same type behave identically. There's no way to customize individual object properties.

## Intended Behavior

Allow per-object property customization with visual RGB encoding:

1. Click on any peg or line in editor to open property panel
2. Adjust three properties via sliders or number inputs
3. Object color updates live to reflect property values
4. Properties saved to JSON and applied at runtime

**RGB Property Mapping:**

| Channel | Property | Range | Effect |
|---------|----------|-------|--------|
| R | Restitution | 0-255 → 0.0-1.0 | Bounciness (0 = dead stop, 255 = super bounce) |
| G | Friction | 0-255 → 0.0-1.0 | Surface grip (0 = ice, 255 = sticky) |
| B | Point Bonus | 0-255 → 0-255 pts | Score awarded on hit |

## Suggested Implementation Steps

### Step 1: Add properties to BoardObject

```c
// src/020-board-data.h

typedef struct BoardObject {
    int type;              // OBJECT_PEG, OBJECT_LINE
    int col, row;
    float radius;          // For pegs

    // For lines
    int end_col, end_row;
    float thickness;

    // RGB Properties (all objects)
    unsigned char restitution;  // 0-255, maps to 0.0-1.0
    unsigned char friction;     // 0-255, maps to 0.0-1.0
    unsigned char point_bonus;  // 0-255, direct point value
} BoardObject;

// Default property values
#define DEFAULT_RESTITUTION 178  // ~0.7
#define DEFAULT_FRICTION 51      // ~0.2
#define DEFAULT_POINT_BONUS 0
```

### Step 2: Add properties to runtime Peg struct

```c
// src/004-world.h

typedef struct Peg {
    float x, y;
    float radius;

    // Physics properties
    float restitution;     // 0.0 - 1.0
    float friction;        // 0.0 - 1.0
    int point_bonus;       // Points awarded on hit

    // Derived color (for rendering)
    Color color;
} Peg;
```

### Step 3: Implement property-to-color conversion

```c
// src/021-board-data.c

Color properties_to_color(unsigned char restitution, unsigned char friction,
                          unsigned char point_bonus) {
    return (Color){ restitution, friction, point_bonus, 255 };
}

// Convert 0-255 to 0.0-1.0
float property_to_float(unsigned char value) {
    return (float)value / 255.0f;
}

// Convert 0.0-1.0 to 0-255
unsigned char float_to_property(float value) {
    if (value < 0.0f) value = 0.0f;
    if (value > 1.0f) value = 1.0f;
    return (unsigned char)(value * 255.0f);
}
```

### Step 4: Apply properties during board loading

```c
// In board_data_apply_to_world()

for (int i = 0; i < data->object_count; i++) {
    BoardObject* obj = &data->objects[i];
    if (obj->type == OBJECT_PEG) {
        world->pegs[peg_index].x = grid_to_pixel_x(&grid, obj->col, obj->row);
        world->pegs[peg_index].y = grid_to_pixel_y(&grid, obj->col, obj->row);
        world->pegs[peg_index].radius = PEG_RADIUS;

        // Apply custom properties
        world->pegs[peg_index].restitution = property_to_float(obj->restitution);
        world->pegs[peg_index].friction = property_to_float(obj->friction);
        world->pegs[peg_index].point_bonus = obj->point_bonus;
        world->pegs[peg_index].color = properties_to_color(
            obj->restitution, obj->friction, obj->point_bonus);

        peg_index++;
    }
}
```

### Step 5: Use properties in collision response

```c
// src/007-ball.c - ball_collide_with_pegs()

void ball_collide_with_peg(Ball* ball, Peg* peg) {
    // ... collision detection ...

    if (collision) {
        // Use peg's custom restitution instead of constant
        float restitution = peg->restitution;

        // Apply friction to tangential velocity
        float friction = peg->friction;
        // ... friction calculation ...

        // Award point bonus
        if (peg->point_bonus > 0) {
            // Need to track this for scoring
            ball->pending_points += peg->point_bonus;
        }

        // ... rest of collision response using restitution ...
    }
}
```

### Step 6: Implement editor selection

```c
// src/025-editor.c

typedef struct EditorState {
    // ... existing fields ...

    // Selection state
    int selected_object_index;  // -1 if none selected
    int show_property_panel;
} EditorState;

void editor_handle_selection(EditorState* editor, Camera2D camera) {
    if (!IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) return;
    if (editor->mode != EDITOR_MODE_SELECT) return;

    Vector2 mouse_screen = GetMousePosition();
    Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);

    // Find object under cursor
    for (int i = 0; i < editor->board_data->object_count; i++) {
        BoardObject* obj = &editor->board_data->objects[i];
        float obj_x = grid_to_pixel_x(&editor->grid, obj->col, obj->row);
        float obj_y = grid_to_pixel_y(&editor->grid, obj->col, obj->row);

        float dx = mouse_world.x - obj_x;
        float dy = mouse_world.y - obj_y;
        float dist = sqrtf(dx * dx + dy * dy);

        float click_radius = (obj->type == OBJECT_PEG) ? PEG_RADIUS : 20.0f;

        if (dist <= click_radius) {
            editor->selected_object_index = i;
            editor->show_property_panel = 1;
            printf("Selected object %d\n", i);
            return;
        }
    }

    // Clicked empty space - deselect
    editor->selected_object_index = -1;
    editor->show_property_panel = 0;
}
```

### Step 7: Implement property panel UI

```c
void editor_render_property_panel(EditorState* editor, int screen_width) {
    if (!editor->show_property_panel) return;
    if (editor->selected_object_index < 0) return;

    BoardObject* obj = &editor->board_data->objects[editor->selected_object_index];

    int panel_width = 200;
    int panel_height = 180;
    int panel_x = screen_width - panel_width - 10;
    int panel_y = 100;

    // Background
    DrawRectangle(panel_x, panel_y, panel_width, panel_height,
                  (Color){40, 40, 50, 240});
    DrawRectangleLines(panel_x, panel_y, panel_width, panel_height,
                       (Color){100, 100, 120, 255});

    // Title
    const char* type_name = (obj->type == OBJECT_PEG) ? "Peg" : "Line";
    DrawText(type_name, panel_x + 10, panel_y + 10, 16, WHITE);

    // Color preview
    Color preview = properties_to_color(obj->restitution, obj->friction,
                                        obj->point_bonus);
    DrawRectangle(panel_x + panel_width - 40, panel_y + 8, 30, 20, preview);
    DrawRectangleLines(panel_x + panel_width - 40, panel_y + 8, 30, 20, WHITE);

    int y = panel_y + 40;

    // Restitution slider (R)
    DrawText("Restitution (R)", panel_x + 10, y, 12, (Color){255, 100, 100, 255});
    editor_render_slider(panel_x + 10, y + 15, panel_width - 20, &obj->restitution);
    y += 45;

    // Friction slider (G)
    DrawText("Friction (G)", panel_x + 10, y, 12, (Color){100, 255, 100, 255});
    editor_render_slider(panel_x + 10, y + 15, panel_width - 20, &obj->friction);
    y += 45;

    // Point Bonus slider (B)
    DrawText("Point Bonus (B)", panel_x + 10, y, 12, (Color){100, 100, 255, 255});
    editor_render_slider(panel_x + 10, y + 15, panel_width - 20, &obj->point_bonus);

    // Close hint
    DrawText("Click elsewhere to close", panel_x + 10, panel_y + panel_height - 20,
             10, GRAY);
}

void editor_render_slider(int x, int y, int width, unsigned char* value) {
    int height = 16;
    float ratio = (float)(*value) / 255.0f;
    int fill_width = (int)(width * ratio);

    // Background
    DrawRectangle(x, y, width, height, (Color){30, 30, 40, 255});

    // Fill
    DrawRectangle(x, y, fill_width, height, (Color){100, 150, 200, 255});

    // Border
    DrawRectangleLines(x, y, width, height, (Color){80, 80, 100, 255});

    // Value text
    char val_text[8];
    snprintf(val_text, 8, "%d", *value);
    DrawText(val_text, x + width + 5, y + 2, 12, WHITE);
}
```

### Step 8: Implement slider interaction

```c
void editor_handle_slider_input(EditorState* editor) {
    if (!editor->show_property_panel) return;
    if (editor->selected_object_index < 0) return;
    if (!IsMouseButtonDown(MOUSE_LEFT_BUTTON)) return;

    BoardObject* obj = &editor->board_data->objects[editor->selected_object_index];
    Vector2 mouse = GetMousePosition();

    int panel_x = GetScreenWidth() - 210;
    int slider_width = 180;

    // Check each slider
    int slider_y[] = { 155, 200, 245 };  // Y positions of sliders
    unsigned char* values[] = { &obj->restitution, &obj->friction, &obj->point_bonus };

    for (int i = 0; i < 3; i++) {
        Rectangle slider_rect = { panel_x, slider_y[i], slider_width, 16 };
        if (CheckCollisionPointRec(mouse, slider_rect)) {
            float ratio = (mouse.x - panel_x) / slider_width;
            if (ratio < 0) ratio = 0;
            if (ratio > 1) ratio = 1;
            *values[i] = (unsigned char)(ratio * 255);
            editor->board_modified = 1;
            break;
        }
    }
}
```

### Step 9: Update JSON format

```json
{
  "objects": [
    {
      "type": "peg",
      "col": 2,
      "row": 1,
      "restitution": 178,
      "friction": 51,
      "point_bonus": 0
    },
    {
      "type": "peg",
      "col": 4,
      "row": 1,
      "restitution": 255,
      "friction": 0,
      "point_bonus": 50
    }
  ]
}
```

### Step 10: Render pegs with custom colors

```c
// src/005-world.c

void world_render_pegs(World* world) {
    for (int i = 0; i < world->peg_count; i++) {
        Peg* peg = &world->pegs[i];

        // Use custom color from properties
        DrawCircle((int)peg->x, (int)peg->y, peg->radius, peg->color);

        // Highlight outline
        DrawCircleLines((int)peg->x, (int)peg->y, peg->radius,
                        (Color){255, 255, 255, 100});
    }
}
```

## Visual Examples

```
Default peg:         High bounce peg:     Scoring peg:
R=178, G=51, B=0     R=255, G=0, B=0      R=178, G=51, B=200
[brownish-red]       [bright red]          [purple]

Sticky peg:          Ice peg:             Jackpot peg:
R=100, G=255, B=0    R=178, G=0, B=0      R=255, G=100, B=255
[lime green]         [dark red]            [pink/magenta]
```

## Files to Modify

- `src/020-board-data.h` - Add properties to BoardObject
- `src/004-world.h` - Add properties to Peg struct
- `src/021-board-data.c` - Property conversion functions
- `src/007-ball.c` - Use properties in collision
- `src/005-world.c` - Render with custom colors
- `src/025-editor.c` - Property panel UI

## Testing

1. Place peg, select it - property panel appears
2. Drag restitution slider - peg turns redder
3. Drag friction slider - peg turns greener
4. Drag point bonus slider - peg turns bluer
5. Save board, reload - verify properties preserved
6. Test physics: high restitution peg should bounce more
7. Test physics: high friction peg should slow ball
8. Test scoring: high point bonus peg should award points on hit

## Related Issues

- 1101-board-data-format.md (property storage)
- 1106-object-placement.md (default property values)
- 1110-line-drawing-tool.md (lines also have properties)

## Implementation Notes (Complete)

**Status:** Complete

**Changes Made:**
1. Added property editor state to EditorState (selected_object_index, show_property_panel)
2. Implemented right-click object selection in editor_handle_object_selection()
3. Added property panel UI with RGB sliders in editor_render_property_panel()
4. Implemented slider dragging in editor_handle_property_panel_input()
5. Added selection highlight ring (pulsing yellow) for selected objects
6. Updated editor_is_over_ui() to include property panel bounds
7. Modified ball_resolve_peg_collision() to use per-peg restitution/friction
8. Updated help text to include "RClick=Props"

**RGB Encoding:**
- Restitution (R): Controls bounciness 0-255 → 0.0-1.0
- Friction (G): Controls surface grip 0-255 → 0.0-1.0
- Point Bonus (B): Points awarded on hit 0-255

**Workflow:**
1. Right-click on any peg or line in editor
2. Property panel appears on right side
3. Drag sliders to adjust RGB values
4. See live color preview in swatch
5. Changes sync to world immediately for live preview
6. ESC or right-click elsewhere to close panel
7. Properties saved to JSON automatically
