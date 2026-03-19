# 406 - Editor Panel UI System

## Status: awaiting-work

## Depends on

None - foundational UI infrastructure.

## Dependents

- 409 (Collapsible drawer) depends on this for panel system

## Problem

The editor currently lacks a structured interface for tool selection and object inspection. UI elements are ad-hoc and there's no consistent widget system. Need a proper panel-based layout with reusable UI components.

## Current Behavior

- Tools selected via keyboard shortcuts only
- Object properties edited via modal dialogs or direct manipulation
- No persistent inspector panel
- No standardized UI widgets

## Intended Behavior

Two permanent panels flanking the board area:
- **Left Panel**: Tool palette for placing objects
- **Right Panel**: Inspector for selected object properties

Both panels:
- Occupy space outside the guard rails (no overlap with play area)
- Expand downward as content requires
- Use consistent, reusable UI widgets

## Layout Design

```
┌─────────────────────────────────────────────────────────────────┐
│                         EDITOR HEADER                           │
├────────────┬───────────────────────────────────┬────────────────┤
│            │                                   │                │
│   TOOLS    │                                   │   INSPECTOR    │
│   PANEL    │         BOARD AREA                │   PANEL        │
│            │      (with guard rails)           │                │
│  [Peg]     │    ┌───────────────────┐          │  Selected:     │
│  [Line]    │    │                   │          │  "Peg"         │
│  [Zone]    │    │                   │          │                │
│  [Portal]  │    │    Play Area      │          │  Position:     │
│  [Spawner] │    │                   │          │  Col: [5]      │
│            │    │                   │          │  Row: [3]      │
│  ───────   │    │                   │          │                │
│  [Select]  │    │                   │          │  Restitution:  │
│  [Delete]  │    │                   │          │  [====●===] 180│
│  [Pan]     │    │                   │          │                │
│            │    └───────────────────┘          │  Point Bonus:  │
│            │                                   │  [◄] 10 [►]    │
│            │                                   │                │
│            │                                   │  ☑ Visible     │
│            │                                   │  ☐ Bouncy      │
│            │                                   │                │
└────────────┴───────────────────────────────────┴────────────────┘
```

### Panel Dimensions

```c
#define PANEL_WIDTH 180.0f           // Width of each side panel
#define PANEL_PADDING 10.0f          // Inner padding
#define PANEL_ITEM_HEIGHT 32.0f      // Height per widget row
#define PANEL_ITEM_SPACING 8.0f      // Vertical gap between items
#define PANEL_SECTION_SPACING 16.0f  // Gap between sections
```

### Window Layout Calculation

```c
typedef struct EditorLayout {
    // Panels
    Rectangle left_panel;    // Tool palette
    Rectangle right_panel;   // Inspector

    // Board area (between panels)
    Rectangle board_area;
    float board_offset_x;    // Left edge of board
    float board_offset_y;    // Top edge of board

    // Scroll state (if panels overflow)
    float left_scroll_y;
    float right_scroll_y;
} EditorLayout;

void editor_calculate_layout(int window_width, int window_height) {
    layout.left_panel = (Rectangle){
        0, HEADER_HEIGHT,
        PANEL_WIDTH, window_height - HEADER_HEIGHT
    };

    layout.right_panel = (Rectangle){
        window_width - PANEL_WIDTH, HEADER_HEIGHT,
        PANEL_WIDTH, window_height - HEADER_HEIGHT
    };

    layout.board_area = (Rectangle){
        PANEL_WIDTH, HEADER_HEIGHT,
        window_width - (2 * PANEL_WIDTH),
        window_height - HEADER_HEIGHT
    };

    // Center board within board_area
    layout.board_offset_x = layout.board_area.x +
        (layout.board_area.width - BOARD_WIDTH) / 2;
    layout.board_offset_y = layout.board_area.y +
        (layout.board_area.height - BOARD_HEIGHT) / 2;
}
```

## UI Widget System

### Base Widget Structure

```c
typedef enum WidgetType {
    WIDGET_LABEL,
    WIDGET_BUTTON,
    WIDGET_CHECKBOX,
    WIDGET_SLIDER,
    WIDGET_DROPDOWN,
    WIDGET_NUMBER_FIELD,
    WIDGET_TEXT_FIELD,
    WIDGET_COLOR_PICKER,
    WIDGET_SEPARATOR,
} WidgetType;

typedef struct Widget {
    WidgetType type;
    char label[64];
    Rectangle bounds;       // Calculated during layout
    int enabled;
    int visible;

    // Type-specific data (union or separate structs)
    void* data;

    // Callbacks
    void (*on_change)(struct Widget* widget, void* user_data);
    void* user_data;
} Widget;
```

### Checkbox Widget

```c
typedef struct CheckboxData {
    int* value;             // Pointer to bound boolean
} CheckboxData;

void widget_checkbox_render(Widget* w) {
    CheckboxData* data = (CheckboxData*)w->data;
    Rectangle box = { w->bounds.x, w->bounds.y, 20, 20 };

    // Draw box outline
    DrawRectangleLinesEx(box, 2, GRAY);

    // Draw checkmark if checked
    if (*data->value) {
        DrawLine(box.x + 4, box.y + 10, box.x + 8, box.y + 16, DARKGRAY);
        DrawLine(box.x + 8, box.y + 16, box.x + 16, box.y + 4, DARKGRAY);
    }

    // Draw label
    DrawText(w->label, box.x + 28, box.y + 2, 16, DARKGRAY);
}

int widget_checkbox_handle_click(Widget* w, Vector2 mouse) {
    if (CheckCollisionPointRec(mouse, w->bounds)) {
        CheckboxData* data = (CheckboxData*)w->data;
        *data->value = !(*data->value);
        if (w->on_change) w->on_change(w, w->user_data);
        return 1;  // Consumed click
    }
    return 0;
}
```

### Slider Widget

```c
typedef struct SliderData {
    float* value;           // Pointer to bound float
    float min_value;
    float max_value;
    float step;             // Snap increment (0 for continuous)
    int dragging;           // Currently being dragged
} SliderData;

void widget_slider_render(Widget* w) {
    SliderData* data = (SliderData*)w->data;

    // Track
    Rectangle track = {
        w->bounds.x, w->bounds.y + 10,
        w->bounds.width - 40, 4
    };
    DrawRectangleRec(track, LIGHTGRAY);

    // Thumb position
    float t = (*data->value - data->min_value) / (data->max_value - data->min_value);
    float thumb_x = track.x + t * track.width;

    // Thumb
    DrawCircle(thumb_x, track.y + 2, 8, data->dragging ? BLUE : DARKGRAY);

    // Value display
    char value_str[16];
    snprintf(value_str, 16, "%.0f", *data->value);
    DrawText(value_str, track.x + track.width + 8, w->bounds.y + 4, 16, DARKGRAY);

    // Label above
    DrawText(w->label, w->bounds.x, w->bounds.y - 16, 14, GRAY);
}

void widget_slider_handle_drag(Widget* w, Vector2 mouse) {
    SliderData* data = (SliderData*)w->data;
    Rectangle track = { w->bounds.x, w->bounds.y + 10, w->bounds.width - 40, 4 };

    float t = (mouse.x - track.x) / track.width;
    t = fmaxf(0.0f, fminf(1.0f, t));

    float new_value = data->min_value + t * (data->max_value - data->min_value);

    // Snap to step if defined
    if (data->step > 0) {
        new_value = roundf(new_value / data->step) * data->step;
    }

    *data->value = new_value;
    if (w->on_change) w->on_change(w, w->user_data);
}
```

### Dropdown Widget

```c
typedef struct DropdownData {
    int* selected_index;    // Pointer to bound index
    const char** options;   // Array of option strings
    int option_count;
    int expanded;           // Dropdown is open
} DropdownData;

void widget_dropdown_render(Widget* w) {
    DropdownData* data = (DropdownData*)w->data;

    // Main button
    DrawRectangleRec(w->bounds, LIGHTGRAY);
    DrawRectangleLinesEx(w->bounds, 1, GRAY);

    // Selected text
    const char* selected_text = data->options[*data->selected_index];
    DrawText(selected_text, w->bounds.x + 8, w->bounds.y + 8, 16, DARKGRAY);

    // Arrow
    DrawTriangle(
        (Vector2){ w->bounds.x + w->bounds.width - 20, w->bounds.y + 10 },
        (Vector2){ w->bounds.x + w->bounds.width - 10, w->bounds.y + 10 },
        (Vector2){ w->bounds.x + w->bounds.width - 15, w->bounds.y + 20 },
        DARKGRAY
    );

    // Expanded options
    if (data->expanded) {
        for (int i = 0; i < data->option_count; i++) {
            Rectangle option_rect = {
                w->bounds.x,
                w->bounds.y + w->bounds.height + (i * PANEL_ITEM_HEIGHT),
                w->bounds.width,
                PANEL_ITEM_HEIGHT
            };

            Color bg = (i == *data->selected_index) ? SKYBLUE : WHITE;
            DrawRectangleRec(option_rect, bg);
            DrawRectangleLinesEx(option_rect, 1, GRAY);
            DrawText(data->options[i], option_rect.x + 8, option_rect.y + 8, 16, DARKGRAY);
        }
    }
}
```

### Number Field Widget

```c
typedef struct NumberFieldData {
    float* value;           // Pointer to bound float (or cast from int*)
    float min_value;
    float max_value;
    float increment;        // Arrow button step
    int is_integer;         // Display as int, no decimals
    int editing;            // Text input active
    char edit_buffer[32];   // Temporary input buffer
} NumberFieldData;

void widget_number_field_render(Widget* w) {
    NumberFieldData* data = (NumberFieldData*)w->data;

    // Label
    DrawText(w->label, w->bounds.x, w->bounds.y, 14, GRAY);

    // Decrement button [◄]
    Rectangle dec_btn = {
        w->bounds.x, w->bounds.y + 18,
        24, 24
    };
    DrawRectangleRec(dec_btn, LIGHTGRAY);
    DrawText("<", dec_btn.x + 8, dec_btn.y + 4, 16, DARKGRAY);

    // Value display / edit field
    Rectangle value_rect = {
        dec_btn.x + dec_btn.width + 4, w->bounds.y + 18,
        w->bounds.width - 56, 24
    };
    DrawRectangleRec(value_rect, data->editing ? WHITE : RAYWHITE);
    DrawRectangleLinesEx(value_rect, 1, data->editing ? BLUE : GRAY);

    char value_str[32];
    if (data->editing) {
        snprintf(value_str, 32, "%s|", data->edit_buffer);  // Show cursor
    } else if (data->is_integer) {
        snprintf(value_str, 32, "%d", (int)*data->value);
    } else {
        snprintf(value_str, 32, "%.2f", *data->value);
    }
    DrawText(value_str, value_rect.x + 4, value_rect.y + 4, 16, DARKGRAY);

    // Increment button [►]
    Rectangle inc_btn = {
        value_rect.x + value_rect.width + 4, w->bounds.y + 18,
        24, 24
    };
    DrawRectangleRec(inc_btn, LIGHTGRAY);
    DrawText(">", inc_btn.x + 8, inc_btn.y + 4, 16, DARKGRAY);
}

void widget_number_field_increment(Widget* w, int direction) {
    NumberFieldData* data = (NumberFieldData*)w->data;
    float new_value = *data->value + (direction * data->increment);
    new_value = fmaxf(data->min_value, fminf(data->max_value, new_value));
    *data->value = new_value;
    if (w->on_change) w->on_change(w, w->user_data);
}
```

### Text Field Widget

```c
typedef struct TextFieldData {
    char* value;            // Pointer to bound string buffer
    int max_length;
    int editing;
    int cursor_pos;
    int numeric_only;       // Restrict to digits, -, .
} TextFieldData;

void widget_text_field_handle_key(Widget* w, int key) {
    TextFieldData* data = (TextFieldData*)w->data;
    int len = strlen(data->value);

    if (key == KEY_BACKSPACE && data->cursor_pos > 0) {
        memmove(&data->value[data->cursor_pos - 1],
                &data->value[data->cursor_pos],
                len - data->cursor_pos + 1);
        data->cursor_pos--;
    }
    else if (key == KEY_LEFT && data->cursor_pos > 0) {
        data->cursor_pos--;
    }
    else if (key == KEY_RIGHT && data->cursor_pos < len) {
        data->cursor_pos++;
    }
    else if (key == KEY_ENTER || key == KEY_ESCAPE) {
        data->editing = 0;
        if (w->on_change) w->on_change(w, w->user_data);
    }
    else if (key >= 32 && key < 127 && len < data->max_length - 1) {
        // Character input
        if (data->numeric_only) {
            if (!((key >= '0' && key <= '9') || key == '-' || key == '.')) {
                return;  // Reject non-numeric
            }
        }
        memmove(&data->value[data->cursor_pos + 1],
                &data->value[data->cursor_pos],
                len - data->cursor_pos + 1);
        data->value[data->cursor_pos] = (char)key;
        data->cursor_pos++;
    }
}
```

## Panel System

### Panel Structure

```c
typedef struct Panel {
    char title[64];
    Rectangle bounds;

    Widget* widgets;
    int widget_count;
    int widget_capacity;

    float scroll_y;
    float content_height;   // Total height of all widgets

    Color background;
    Color border;
} Panel;

Panel* panel_create(const char* title, Rectangle bounds) {
    Panel* panel = malloc(sizeof(Panel));
    strncpy(panel->title, title, 63);
    panel->bounds = bounds;
    panel->widgets = malloc(sizeof(Widget) * 32);
    panel->widget_count = 0;
    panel->widget_capacity = 32;
    panel->scroll_y = 0;
    panel->content_height = 0;
    panel->background = (Color){ 40, 40, 45, 255 };
    panel->border = (Color){ 60, 60, 65, 255 };
    return panel;
}

void panel_add_widget(Panel* panel, Widget widget) {
    if (panel->widget_count >= panel->widget_capacity) {
        panel->widget_capacity *= 2;
        panel->widgets = realloc(panel->widgets,
            sizeof(Widget) * panel->widget_capacity);
    }
    panel->widgets[panel->widget_count++] = widget;
    panel_recalculate_layout(panel);
}

void panel_recalculate_layout(Panel* panel) {
    float y = PANEL_PADDING;

    for (int i = 0; i < panel->widget_count; i++) {
        Widget* w = &panel->widgets[i];

        float widget_height = PANEL_ITEM_HEIGHT;
        if (w->type == WIDGET_SLIDER) {
            widget_height = PANEL_ITEM_HEIGHT + 16;  // Extra for label
        }

        w->bounds = (Rectangle){
            panel->bounds.x + PANEL_PADDING,
            panel->bounds.y + y - panel->scroll_y,
            panel->bounds.width - (2 * PANEL_PADDING),
            widget_height
        };

        y += widget_height + PANEL_ITEM_SPACING;

        if (w->type == WIDGET_SEPARATOR) {
            y += PANEL_SECTION_SPACING - PANEL_ITEM_SPACING;
        }
    }

    panel->content_height = y;
}
```

### Tool Panel (Left Side)

```c
void editor_setup_tool_panel(Panel* panel) {
    // Object placement tools
    panel_add_widget(panel, widget_button("Peg", tool_select_peg));
    panel_add_widget(panel, widget_button("Line", tool_select_line));
    panel_add_widget(panel, widget_button("Zone", tool_select_zone));
    panel_add_widget(panel, widget_button("Portal", tool_select_portal));
    panel_add_widget(panel, widget_button("Spawner", tool_select_spawner));

    panel_add_widget(panel, widget_separator());

    // Edit tools
    panel_add_widget(panel, widget_button("Select", tool_select_mode));
    panel_add_widget(panel, widget_button("Delete", tool_delete_mode));
    panel_add_widget(panel, widget_button("Pan", tool_pan_mode));

    panel_add_widget(panel, widget_separator());

    // View options
    panel_add_widget(panel, widget_checkbox("Show Grid", &editor.show_grid));
    panel_add_widget(panel, widget_checkbox("Snap to Grid", &editor.snap_to_grid));
}
```

### Inspector Panel (Right Side)

```c
void editor_setup_inspector_for_peg(Panel* panel, Peg* peg) {
    panel_clear_widgets(panel);

    panel_add_widget(panel, widget_label("Peg Properties"));
    panel_add_widget(panel, widget_separator());

    // Position
    panel_add_widget(panel, widget_number_field("Column", &peg->col,
        0, GRID_COLS - 1, 1, 1));  // min, max, increment, is_integer
    panel_add_widget(panel, widget_number_field("Row", &peg->row,
        0, GRID_ROWS - 1, 1, 1));

    panel_add_widget(panel, widget_separator());

    // Physics
    panel_add_widget(panel, widget_slider("Restitution", &peg->restitution,
        0, 255, 1));  // min, max, step
    panel_add_widget(panel, widget_number_field("Point Bonus", &peg->point_bonus,
        0, 1000, 10, 1));

    panel_add_widget(panel, widget_separator());

    // Visual
    panel_add_widget(panel, widget_checkbox("Visible", &peg->visible));
    panel_add_widget(panel, widget_color_picker("Color", &peg->color));
}

void editor_setup_inspector_for_line(Panel* panel, Line* line) {
    panel_clear_widgets(panel);

    panel_add_widget(panel, widget_label("Line Properties"));
    panel_add_widget(panel, widget_separator());

    // Start point
    panel_add_widget(panel, widget_label("Start Point"));
    panel_add_widget(panel, widget_number_field("Col", &line->start_col, 0, 14, 1, 1));
    panel_add_widget(panel, widget_number_field("Row", &line->start_row, 0, 22, 1, 1));

    // End point
    panel_add_widget(panel, widget_label("End Point"));
    panel_add_widget(panel, widget_number_field("Col", &line->end_col, 0, 14, 1, 1));
    panel_add_widget(panel, widget_number_field("Row", &line->end_row, 0, 22, 1, 1));

    panel_add_widget(panel, widget_separator());

    // Properties
    panel_add_widget(panel, widget_slider("Thickness", &line->thickness, 1, 20, 1));
    panel_add_widget(panel, widget_slider("Restitution", &line->restitution, 0, 255, 1));

    panel_add_widget(panel, widget_separator());

    // Material dropdown
    static const char* materials[] = { "Stone", "Rubber", "Ice", "Sticky", "Bouncy" };
    panel_add_widget(panel, widget_dropdown("Material", &line->material_index,
        materials, 5));

    panel_add_widget(panel, widget_color_picker("Color", &line->color));
}

void editor_setup_inspector_for_polygon(Panel* panel, Polygon* poly) {
    panel_clear_widgets(panel);

    panel_add_widget(panel, widget_label("Polygon Properties"));
    panel_add_widget(panel, widget_separator());

    // Fill (visual only)
    panel_add_widget(panel, widget_label("Fill (Visual Only)"));
    panel_add_widget(panel, widget_color_picker("Fill Color", &poly->fill_color));
    panel_add_widget(panel, widget_checkbox("Fill Visible", &poly->fill_visible));

    panel_add_widget(panel, widget_separator());

    // Line (affects physics)
    panel_add_widget(panel, widget_label("Edges (Affects Physics)"));
    panel_add_widget(panel, widget_color_picker("Line Color", &poly->line_color));

    static const char* materials[] = { "Stone", "Rubber", "Ice", "Sticky", "Bouncy" };
    panel_add_widget(panel, widget_dropdown("Material", &poly->material_index,
        materials, 5));

    panel_add_widget(panel, widget_slider("Restitution", &poly->restitution, 0, 255, 1));
    panel_add_widget(panel, widget_slider("Friction", &poly->friction, 0, 255, 1));

    panel_add_widget(panel, widget_separator());

    // Physics
    panel_add_widget(panel, widget_checkbox("Physics Solid", &poly->physics_solid));
}

void editor_setup_inspector_for_zone(Panel* panel, Zone* zone) {
    panel_clear_widgets(panel);

    panel_add_widget(panel, widget_label("Zone Properties"));
    panel_add_widget(panel, widget_separator());

    // Position and size
    panel_add_widget(panel, widget_number_field("Column", &zone->col, 0, 13, 1, 1));
    panel_add_widget(panel, widget_number_field("Row", &zone->row, 0, 21, 1, 1));
    panel_add_widget(panel, widget_number_field("Width", &zone->width, 1, 14, 1, 1));
    panel_add_widget(panel, widget_number_field("Height", &zone->height, 1, 22, 1, 1));

    panel_add_widget(panel, widget_separator());

    // Zone type
    static const char* zone_types[] = { "Score", "Wrap", "Portal", "Spawn" };
    panel_add_widget(panel, widget_dropdown("Type", &zone->type, zone_types, 4));

    // Type-specific properties
    if (zone->type == ZONE_SCORE) {
        panel_add_widget(panel, widget_number_field("Points", &zone->points,
            0, 10000, 10, 1));
        panel_add_widget(panel, widget_number_field("Multiplier", &zone->multiplier,
            1, 10, 1, 1));
    }
}
```

## Scrolling Support

```c
void panel_handle_scroll(Panel* panel, float scroll_delta) {
    float max_scroll = fmaxf(0, panel->content_height - panel->bounds.height);
    panel->scroll_y = fmaxf(0, fminf(max_scroll, panel->scroll_y - scroll_delta * 30));
    panel_recalculate_layout(panel);
}

void panel_render(Panel* panel) {
    // Background
    DrawRectangleRec(panel->bounds, panel->background);

    // Enable scissor mode for clipping
    BeginScissorMode(
        panel->bounds.x, panel->bounds.y,
        panel->bounds.width, panel->bounds.height
    );

    // Render widgets
    for (int i = 0; i < panel->widget_count; i++) {
        Widget* w = &panel->widgets[i];
        if (w->visible) {
            widget_render(w);
        }
    }

    EndScissorMode();

    // Scrollbar if needed
    if (panel->content_height > panel->bounds.height) {
        float scrollbar_height = (panel->bounds.height / panel->content_height)
                                * panel->bounds.height;
        float scrollbar_y = (panel->scroll_y / panel->content_height)
                           * panel->bounds.height;

        Rectangle scrollbar = {
            panel->bounds.x + panel->bounds.width - 8,
            panel->bounds.y + scrollbar_y,
            6, scrollbar_height
        };
        DrawRectangleRec(scrollbar, (Color){ 100, 100, 110, 200 });
    }

    // Border
    DrawRectangleLinesEx(panel->bounds, 1, panel->border);
}
```

## Input Handling

```c
void editor_handle_input(void) {
    Vector2 mouse = GetMousePosition();

    // Determine which panel (if any) mouse is over
    Panel* active_panel = NULL;
    if (CheckCollisionPointRec(mouse, layout.left_panel)) {
        active_panel = &tool_panel;
    } else if (CheckCollisionPointRec(mouse, layout.right_panel)) {
        active_panel = &inspector_panel;
    }

    // Mouse wheel scrolling for panels
    if (active_panel) {
        float wheel = GetMouseWheelMove();
        if (wheel != 0) {
            panel_handle_scroll(active_panel, wheel);
        }
    }

    // Click handling
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        if (active_panel) {
            for (int i = 0; i < active_panel->widget_count; i++) {
                if (widget_handle_click(&active_panel->widgets[i], mouse)) {
                    break;  // Click consumed
                }
            }
        } else if (CheckCollisionPointRec(mouse, layout.board_area)) {
            // Board interaction
            editor_handle_board_click(mouse);
        }
    }

    // Keyboard input for active text field
    if (active_text_widget) {
        int key = GetCharPressed();
        while (key > 0) {
            widget_text_field_handle_key(active_text_widget, key);
            key = GetCharPressed();
        }

        // Special keys
        if (IsKeyPressed(KEY_BACKSPACE)) {
            widget_text_field_handle_key(active_text_widget, KEY_BACKSPACE);
        }
        // ... etc
    }
}
```

## Implementation Steps

1. Create widget base system (Widget struct, type enum)
2. Implement Label widget
3. Implement Button widget with click detection
4. Implement Checkbox widget with bound value
5. Implement Slider widget with drag handling
6. Implement Number Field with increment/decrement buttons
7. Implement Text Field with keyboard input
8. Implement Dropdown with expand/collapse
9. Create Panel container with widget list
10. Implement panel scrolling and scissor clipping
11. Create EditorLayout system for window division
12. Setup Tool Panel with placement tools
13. Setup Inspector Panel with dynamic content
14. Add inspector content for each object type (peg, line, zone, polygon)
15. Integrate with existing editor selection system
16. Add color picker widget
17. Test all widget interactions
18. Polish visual styling

## Files to Create

- `src/044-ui-widget.h` - Widget types and base API
- `src/045-ui-widget.c` - Widget implementations
- `src/046-ui-panel.h` - Panel container API
- `src/047-ui-panel.c` - Panel implementation

## Files to Modify

- `src/032-editor-app.c` - Integrate panel system, update layout
- `src/030-editor-main.c` - Update window handling for panels

## Notes

- Consider dark theme for editor (easier on eyes during extended use)
- Tool buttons could have icons instead of text
- Inspector should update in real-time as values change
- Undo/redo should work with inspector edits
- Color picker could be a separate popup or inline HSV sliders
- Keyboard shortcuts should still work (not blocked by panel focus)
