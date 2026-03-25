// src/048-ui-widget.h
// UI widget system for editor panels
// Provides reusable UI components: labels, buttons, checkboxes, sliders, etc.
//
// Issue 406: Foundational widget system for editor panel UI.
// Widgets are data-bound and self-rendering, with callback support.
//
// External functions: widget_*, see individual declarations below

#ifndef UI_WIDGET_H
#define UI_WIDGET_H

#include "raylib.h"

// =============================================================================
// Widget Type Enumeration
// =============================================================================

// {{{ WidgetType enum
typedef enum WidgetType {
    WIDGET_LABEL,         // Static text display
    WIDGET_BUTTON,        // Clickable button
    WIDGET_CHECKBOX,      // Toggle with bound boolean
    WIDGET_SLIDER,        // Horizontal slider with bound float
    WIDGET_NUMBER_FIELD,  // Number with +/- buttons
    WIDGET_SEPARATOR,     // Horizontal divider line
    WIDGET_DROPDOWN,      // Dropdown selection (future)
    WIDGET_COLOR_PICKER,  // RGB color selector (future)
    WIDGET_TYPE_COUNT
} WidgetType;
// }}}

// =============================================================================
// Widget Constants
// =============================================================================

#define WIDGET_HEIGHT 28.0f
#define WIDGET_SPACING 6.0f
#define WIDGET_LABEL_SIZE 14
#define WIDGET_VALUE_SIZE 14
#define WIDGET_BUTTON_SIZE 16

// Colors
#define WIDGET_BG_COLOR      (Color){ 50, 50, 55, 255 }
#define WIDGET_BORDER_COLOR  (Color){ 70, 70, 75, 255 }
#define WIDGET_TEXT_COLOR    (Color){ 200, 200, 200, 255 }
#define WIDGET_LABEL_COLOR   (Color){ 150, 150, 150, 255 }
#define WIDGET_HOVER_COLOR   (Color){ 70, 70, 80, 255 }
#define WIDGET_ACTIVE_COLOR  (Color){ 80, 120, 180, 255 }
#define WIDGET_TRACK_COLOR   (Color){ 40, 40, 45, 255 }
#define WIDGET_THUMB_COLOR   (Color){ 100, 140, 200, 255 }

// =============================================================================
// Widget Data Structures
// =============================================================================

// Forward declaration
typedef struct Widget Widget;

// {{{ Widget callback typedef
// Called when widget value changes
typedef void (*WidgetCallback)(Widget* widget, void* user_data);
// }}}

// {{{ ButtonData
typedef struct ButtonData {
    void (*on_click)(void* user_data);
    void* click_user_data;
    int pressed;  // Visual state
} ButtonData;
// }}}

// {{{ CheckboxData
typedef struct CheckboxData {
    int* value;   // Pointer to bound boolean
} CheckboxData;
// }}}

// {{{ SliderData
typedef struct SliderData {
    float* value;
    float min_value;
    float max_value;
    float step;       // Snap increment (0 = continuous)
    int dragging;
} SliderData;
// }}}

// {{{ NumberFieldData
typedef struct NumberFieldData {
    float* value;
    float min_value;
    float max_value;
    float increment;
    int is_integer;
} NumberFieldData;
// }}}

// {{{ DropdownData
typedef struct DropdownData {
    int* selected_index;
    const char** options;
    int option_count;
    int expanded;
} DropdownData;
// }}}

// =============================================================================
// Widget Structure
// =============================================================================

// {{{ Widget struct
typedef struct Widget {
    WidgetType type;
    char label[64];
    Rectangle bounds;
    int enabled;
    int visible;
    int hovered;

    // Type-specific data
    union {
        ButtonData button;
        CheckboxData checkbox;
        SliderData slider;
        NumberFieldData number_field;
        DropdownData dropdown;
    } data;

    // Change callback
    WidgetCallback on_change;
    void* user_data;
} Widget;
// }}}

// =============================================================================
// Widget Creation Functions
// =============================================================================

// {{{ widget_label
// Creates a static text label widget.
Widget widget_label(const char* text);
// }}}

// {{{ widget_button
// Creates a clickable button widget.
Widget widget_button(const char* text, void (*on_click)(void*), void* user_data);
// }}}

// {{{ widget_checkbox
// Creates a checkbox bound to a boolean value.
Widget widget_checkbox(const char* label, int* value);
// }}}

// {{{ widget_slider
// Creates a horizontal slider bound to a float value.
Widget widget_slider(const char* label, float* value,
                     float min_val, float max_val, float step);
// }}}

// {{{ widget_number_field
// Creates a number field with +/- buttons.
Widget widget_number_field(const char* label, float* value,
                           float min_val, float max_val,
                           float increment, int is_integer);
// }}}

// {{{ widget_separator
// Creates a horizontal separator line.
Widget widget_separator(void);
// }}}

// =============================================================================
// Widget Rendering
// =============================================================================

// {{{ widget_render
// Renders a widget to the screen.
// Widget bounds must be set before calling.
void widget_render(Widget* widget);
// }}}

// =============================================================================
// Widget Input Handling
// =============================================================================

// {{{ widget_handle_mouse
// Handles mouse input for a widget.
// Returns 1 if input was consumed, 0 otherwise.
int widget_handle_mouse(Widget* widget, Vector2 mouse, int pressed, int released);
// }}}

// {{{ widget_update_hover
// Updates widget hover state based on mouse position.
void widget_update_hover(Widget* widget, Vector2 mouse);
// }}}

// {{{ widget_handle_drag
// Handles drag input for slider widgets.
// Call each frame while mouse is held.
void widget_handle_drag(Widget* widget, Vector2 mouse);
// }}}

// =============================================================================
// Widget Utility
// =============================================================================

// {{{ widget_set_bounds
// Sets the widget bounds rectangle.
void widget_set_bounds(Widget* widget, float x, float y, float width, float height);
// }}}

// {{{ widget_set_callback
// Sets the change callback for a widget.
void widget_set_callback(Widget* widget, WidgetCallback callback, void* user_data);
// }}}

#endif // UI_WIDGET_H
