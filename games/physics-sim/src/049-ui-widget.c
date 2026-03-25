// src/049-ui-widget.c
// UI widget system implementation
// Provides rendering and input handling for UI components
//
// Issue 406: Editor panel UI system

#include "048-ui-widget.h"
#include <string.h>
#include <stdio.h>
#include <math.h>

// =============================================================================
// Widget Creation Functions
// =============================================================================

// {{{ widget_label
Widget widget_label(const char* text) {
    Widget w = {0};
    w.type = WIDGET_LABEL;
    strncpy(w.label, text, 63);
    w.enabled = 1;
    w.visible = 1;
    return w;
}
// }}}

// {{{ widget_button
Widget widget_button(const char* text, void (*on_click)(void*), void* user_data) {
    Widget w = {0};
    w.type = WIDGET_BUTTON;
    strncpy(w.label, text, 63);
    w.enabled = 1;
    w.visible = 1;
    w.data.button.on_click = on_click;
    w.data.button.click_user_data = user_data;
    w.data.button.pressed = 0;
    return w;
}
// }}}

// {{{ widget_checkbox
Widget widget_checkbox(const char* label, int* value) {
    Widget w = {0};
    w.type = WIDGET_CHECKBOX;
    strncpy(w.label, label, 63);
    w.enabled = 1;
    w.visible = 1;
    w.data.checkbox.value = value;
    return w;
}
// }}}

// {{{ widget_slider
Widget widget_slider(const char* label, float* value,
                     float min_val, float max_val, float step) {
    Widget w = {0};
    w.type = WIDGET_SLIDER;
    strncpy(w.label, label, 63);
    w.enabled = 1;
    w.visible = 1;
    w.data.slider.value = value;
    w.data.slider.min_value = min_val;
    w.data.slider.max_value = max_val;
    w.data.slider.step = step;
    w.data.slider.dragging = 0;
    return w;
}
// }}}

// {{{ widget_number_field
Widget widget_number_field(const char* label, float* value,
                           float min_val, float max_val,
                           float increment, int is_integer) {
    Widget w = {0};
    w.type = WIDGET_NUMBER_FIELD;
    strncpy(w.label, label, 63);
    w.enabled = 1;
    w.visible = 1;
    w.data.number_field.value = value;
    w.data.number_field.min_value = min_val;
    w.data.number_field.max_value = max_val;
    w.data.number_field.increment = increment;
    w.data.number_field.is_integer = is_integer;
    return w;
}
// }}}

// {{{ widget_separator
Widget widget_separator(void) {
    Widget w = {0};
    w.type = WIDGET_SEPARATOR;
    w.label[0] = '\0';
    w.enabled = 1;
    w.visible = 1;
    return w;
}
// }}}

// =============================================================================
// Internal Rendering Functions
// =============================================================================

// {{{ render_label
static void render_label(Widget* w) {
    DrawText(w->label, (int)w->bounds.x, (int)w->bounds.y + 6,
             WIDGET_LABEL_SIZE, WIDGET_TEXT_COLOR);
}
// }}}

// {{{ render_button
static void render_button(Widget* w) {
    Color bg = w->data.button.pressed ? WIDGET_ACTIVE_COLOR :
               (w->hovered ? WIDGET_HOVER_COLOR : WIDGET_BG_COLOR);

    DrawRectangleRec(w->bounds, bg);
    DrawRectangleLinesEx(w->bounds, 1, WIDGET_BORDER_COLOR);

    // Center text
    int text_width = MeasureText(w->label, WIDGET_BUTTON_SIZE);
    int text_x = (int)(w->bounds.x + (w->bounds.width - text_width) / 2);
    int text_y = (int)(w->bounds.y + (w->bounds.height - WIDGET_BUTTON_SIZE) / 2);
    DrawText(w->label, text_x, text_y, WIDGET_BUTTON_SIZE, WIDGET_TEXT_COLOR);
}
// }}}

// {{{ render_checkbox
static void render_checkbox(Widget* w) {
    float box_size = 18.0f;
    Rectangle box = {
        w->bounds.x,
        w->bounds.y + (w->bounds.height - box_size) / 2,
        box_size, box_size
    };

    // Box background
    DrawRectangleRec(box, w->hovered ? WIDGET_HOVER_COLOR : WIDGET_BG_COLOR);
    DrawRectangleLinesEx(box, 1, WIDGET_BORDER_COLOR);

    // Checkmark if checked
    if (w->data.checkbox.value && *w->data.checkbox.value) {
        // Draw checkmark lines
        float cx = box.x + box_size / 2;
        float cy = box.y + box_size / 2;
        DrawLine((int)(cx - 5), (int)(cy), (int)(cx - 1), (int)(cy + 4), WIDGET_ACTIVE_COLOR);
        DrawLine((int)(cx - 1), (int)(cy + 4), (int)(cx + 5), (int)(cy - 4), WIDGET_ACTIVE_COLOR);
        // Thicker checkmark
        DrawLine((int)(cx - 5), (int)(cy + 1), (int)(cx - 1), (int)(cy + 5), WIDGET_ACTIVE_COLOR);
        DrawLine((int)(cx - 1), (int)(cy + 5), (int)(cx + 5), (int)(cy - 3), WIDGET_ACTIVE_COLOR);
    }

    // Label
    DrawText(w->label, (int)(box.x + box_size + 8),
             (int)(w->bounds.y + (w->bounds.height - WIDGET_LABEL_SIZE) / 2),
             WIDGET_LABEL_SIZE, WIDGET_TEXT_COLOR);
}
// }}}

// {{{ render_slider
static void render_slider(Widget* w) {
    SliderData* data = &w->data.slider;

    // Label above slider
    DrawText(w->label, (int)w->bounds.x, (int)w->bounds.y,
             WIDGET_LABEL_SIZE - 2, WIDGET_LABEL_COLOR);

    // Track
    float track_y = w->bounds.y + 18;
    float track_width = w->bounds.width - 50;
    Rectangle track = { w->bounds.x, track_y, track_width, 6 };
    DrawRectangleRec(track, WIDGET_TRACK_COLOR);
    DrawRectangleLinesEx(track, 1, WIDGET_BORDER_COLOR);

    // Thumb position
    float range = data->max_value - data->min_value;
    float t = (range > 0) ? (*data->value - data->min_value) / range : 0;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    float thumb_x = track.x + t * track.width;

    // Thumb
    Color thumb_color = data->dragging ? WIDGET_ACTIVE_COLOR : WIDGET_THUMB_COLOR;
    DrawCircle((int)thumb_x, (int)(track_y + 3), 7, thumb_color);

    // Value display
    char value_str[16];
    if (data->step >= 1.0f) {
        snprintf(value_str, 16, "%.0f", *data->value);
    } else {
        snprintf(value_str, 16, "%.1f", *data->value);
    }
    DrawText(value_str, (int)(track.x + track.width + 8), (int)(track_y - 2),
             WIDGET_VALUE_SIZE, WIDGET_TEXT_COLOR);
}
// }}}

// {{{ render_number_field
static void render_number_field(Widget* w) {
    NumberFieldData* data = &w->data.number_field;

    // Label
    DrawText(w->label, (int)w->bounds.x, (int)w->bounds.y,
             WIDGET_LABEL_SIZE - 2, WIDGET_LABEL_COLOR);

    float field_y = w->bounds.y + 16;
    float btn_size = 22;

    // Decrement button [-]
    Rectangle dec_btn = { w->bounds.x, field_y, btn_size, btn_size };
    DrawRectangleRec(dec_btn, WIDGET_BG_COLOR);
    DrawRectangleLinesEx(dec_btn, 1, WIDGET_BORDER_COLOR);
    DrawText("-", (int)(dec_btn.x + 7), (int)(dec_btn.y + 3), 16, WIDGET_TEXT_COLOR);

    // Value field
    float value_width = w->bounds.width - (btn_size * 2) - 8;
    Rectangle value_rect = { dec_btn.x + dec_btn.width + 4, field_y, value_width, btn_size };
    DrawRectangleRec(value_rect, WIDGET_TRACK_COLOR);
    DrawRectangleLinesEx(value_rect, 1, WIDGET_BORDER_COLOR);

    char value_str[32];
    if (data->is_integer) {
        snprintf(value_str, 32, "%d", (int)*data->value);
    } else {
        snprintf(value_str, 32, "%.2f", *data->value);
    }
    int text_width = MeasureText(value_str, WIDGET_VALUE_SIZE);
    DrawText(value_str, (int)(value_rect.x + (value_rect.width - text_width) / 2),
             (int)(value_rect.y + 4), WIDGET_VALUE_SIZE, WIDGET_TEXT_COLOR);

    // Increment button [+]
    Rectangle inc_btn = { value_rect.x + value_rect.width + 4, field_y, btn_size, btn_size };
    DrawRectangleRec(inc_btn, WIDGET_BG_COLOR);
    DrawRectangleLinesEx(inc_btn, 1, WIDGET_BORDER_COLOR);
    DrawText("+", (int)(inc_btn.x + 5), (int)(inc_btn.y + 3), 16, WIDGET_TEXT_COLOR);
}
// }}}

// {{{ render_separator
static void render_separator(Widget* w) {
    float y = w->bounds.y + w->bounds.height / 2;
    DrawLine((int)w->bounds.x, (int)y,
             (int)(w->bounds.x + w->bounds.width), (int)y,
             WIDGET_BORDER_COLOR);
}
// }}}

// =============================================================================
// Widget Rendering
// =============================================================================

// {{{ widget_render
void widget_render(Widget* widget) {
    if (!widget || !widget->visible) return;

    switch (widget->type) {
        case WIDGET_LABEL:
            render_label(widget);
            break;
        case WIDGET_BUTTON:
            render_button(widget);
            break;
        case WIDGET_CHECKBOX:
            render_checkbox(widget);
            break;
        case WIDGET_SLIDER:
            render_slider(widget);
            break;
        case WIDGET_NUMBER_FIELD:
            render_number_field(widget);
            break;
        case WIDGET_SEPARATOR:
            render_separator(widget);
            break;
        default:
            break;
    }
}
// }}}

// =============================================================================
// Widget Input Handling
// =============================================================================

// {{{ widget_update_hover
void widget_update_hover(Widget* widget, Vector2 mouse) {
    if (!widget || !widget->visible || !widget->enabled) {
        if (widget) widget->hovered = 0;
        return;
    }
    widget->hovered = CheckCollisionPointRec(mouse, widget->bounds);
}
// }}}

// {{{ handle_button_click
static int handle_button_click(Widget* w, Vector2 mouse, int pressed, int released) {
    if (!CheckCollisionPointRec(mouse, w->bounds)) {
        w->data.button.pressed = 0;
        return 0;
    }

    if (pressed) {
        w->data.button.pressed = 1;
        return 1;
    }

    if (released && w->data.button.pressed) {
        w->data.button.pressed = 0;
        if (w->data.button.on_click) {
            w->data.button.on_click(w->data.button.click_user_data);
        }
        if (w->on_change) {
            w->on_change(w, w->user_data);
        }
        return 1;
    }

    return 0;
}
// }}}

// {{{ handle_checkbox_click
static int handle_checkbox_click(Widget* w, Vector2 mouse, int pressed, int released) {
    (void)pressed;
    if (!released) return 0;
    if (!CheckCollisionPointRec(mouse, w->bounds)) return 0;

    if (w->data.checkbox.value) {
        *w->data.checkbox.value = !(*w->data.checkbox.value);
        if (w->on_change) {
            w->on_change(w, w->user_data);
        }
    }
    return 1;
}
// }}}

// {{{ handle_slider_click
static int handle_slider_click(Widget* w, Vector2 mouse, int pressed, int released) {
    SliderData* data = &w->data.slider;

    // Track bounds
    float track_y = w->bounds.y + 18;
    float track_width = w->bounds.width - 50;
    Rectangle track = { w->bounds.x, track_y - 5, track_width, 16 };

    if (pressed && CheckCollisionPointRec(mouse, track)) {
        data->dragging = 1;
    }

    if (released) {
        data->dragging = 0;
    }

    return data->dragging;
}
// }}}

// {{{ handle_number_field_click
static int handle_number_field_click(Widget* w, Vector2 mouse, int pressed, int released) {
    (void)pressed;
    if (!released) return 0;

    NumberFieldData* data = &w->data.number_field;
    float field_y = w->bounds.y + 16;
    float btn_size = 22;

    // Decrement button
    Rectangle dec_btn = { w->bounds.x, field_y, btn_size, btn_size };
    if (CheckCollisionPointRec(mouse, dec_btn)) {
        float new_val = *data->value - data->increment;
        if (new_val < data->min_value) new_val = data->min_value;
        *data->value = new_val;
        if (w->on_change) w->on_change(w, w->user_data);
        return 1;
    }

    // Increment button
    float value_width = w->bounds.width - (btn_size * 2) - 8;
    Rectangle inc_btn = { w->bounds.x + btn_size + 4 + value_width + 4, field_y, btn_size, btn_size };
    if (CheckCollisionPointRec(mouse, inc_btn)) {
        float new_val = *data->value + data->increment;
        if (new_val > data->max_value) new_val = data->max_value;
        *data->value = new_val;
        if (w->on_change) w->on_change(w, w->user_data);
        return 1;
    }

    return 0;
}
// }}}

// {{{ widget_handle_mouse
int widget_handle_mouse(Widget* widget, Vector2 mouse, int pressed, int released) {
    if (!widget || !widget->visible || !widget->enabled) return 0;

    switch (widget->type) {
        case WIDGET_BUTTON:
            return handle_button_click(widget, mouse, pressed, released);
        case WIDGET_CHECKBOX:
            return handle_checkbox_click(widget, mouse, pressed, released);
        case WIDGET_SLIDER:
            return handle_slider_click(widget, mouse, pressed, released);
        case WIDGET_NUMBER_FIELD:
            return handle_number_field_click(widget, mouse, pressed, released);
        default:
            return 0;
    }
}
// }}}

// {{{ widget_handle_drag
void widget_handle_drag(Widget* widget, Vector2 mouse) {
    if (!widget || !widget->visible || !widget->enabled) return;
    if (widget->type != WIDGET_SLIDER) return;

    SliderData* data = &widget->data.slider;
    if (!data->dragging) return;

    // Track bounds
    float track_x = widget->bounds.x;
    float track_width = widget->bounds.width - 50;

    // Calculate new value
    float t = (mouse.x - track_x) / track_width;
    if (t < 0) t = 0;
    if (t > 1) t = 1;

    float range = data->max_value - data->min_value;
    float new_val = data->min_value + t * range;

    // Snap to step
    if (data->step > 0) {
        new_val = roundf(new_val / data->step) * data->step;
    }

    // Clamp
    if (new_val < data->min_value) new_val = data->min_value;
    if (new_val > data->max_value) new_val = data->max_value;

    if (*data->value != new_val) {
        *data->value = new_val;
        if (widget->on_change) {
            widget->on_change(widget, widget->user_data);
        }
    }
}
// }}}

// =============================================================================
// Widget Utility
// =============================================================================

// {{{ widget_set_bounds
void widget_set_bounds(Widget* widget, float x, float y, float width, float height) {
    if (!widget) return;
    widget->bounds = (Rectangle){ x, y, width, height };
}
// }}}

// {{{ widget_set_callback
void widget_set_callback(Widget* widget, WidgetCallback callback, void* user_data) {
    if (!widget) return;
    widget->on_change = callback;
    widget->user_data = user_data;
}
// }}}
