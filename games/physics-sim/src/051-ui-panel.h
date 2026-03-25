// src/051-ui-panel.h
// UI panel container system for editor
// Panels contain widgets and handle scrolling, layout, and input dispatch
//
// Issue 406: Editor panel UI system
//
// External functions: panel_create, panel_destroy, panel_add_widget,
//                     panel_clear, panel_render, panel_handle_input

#ifndef UI_PANEL_H
#define UI_PANEL_H

#include "raylib.h"
#include "048-ui-widget.h"

// =============================================================================
// Panel Constants
// =============================================================================

#define PANEL_MAX_WIDGETS 64
#define PANEL_PADDING 10.0f
#define PANEL_HEADER_HEIGHT 30.0f
#define PANEL_SCROLLBAR_WIDTH 8.0f

// Panel colors
#define PANEL_BG_COLOR       (Color){ 35, 35, 40, 255 }
#define PANEL_HEADER_COLOR   (Color){ 45, 45, 50, 255 }
#define PANEL_BORDER_COLOR   (Color){ 60, 60, 65, 255 }
#define PANEL_TITLE_COLOR    (Color){ 180, 180, 180, 255 }
#define PANEL_SCROLLBAR_BG   (Color){ 30, 30, 35, 255 }
#define PANEL_SCROLLBAR_FG   (Color){ 80, 80, 90, 200 }

// =============================================================================
// Panel Structure
// =============================================================================

// {{{ typedef struct Panel
typedef struct Panel {
    char title[64];
    Rectangle bounds;

    // Widget storage
    Widget widgets[PANEL_MAX_WIDGETS];
    int widget_count;

    // Scroll state
    float scroll_y;
    float content_height;
    int scrollbar_dragging;
    float drag_start_y;
    float drag_start_scroll;

    // Visual
    Color background;
    Color border;
    int visible;
} Panel;
// }}}

// =============================================================================
// Panel Lifecycle
// =============================================================================

// {{{ panel_create
// Creates a new panel with given title and bounds.
// Returns allocated panel or NULL on failure.
Panel* panel_create(const char* title, Rectangle bounds);
// }}}

// {{{ panel_destroy
// Frees panel memory.
void panel_destroy(Panel* panel);
// }}}

// =============================================================================
// Widget Management
// =============================================================================

// {{{ panel_add_widget
// Adds a widget to the panel.
// Returns widget index, or -1 if panel is full.
int panel_add_widget(Panel* panel, Widget widget);
// }}}

// {{{ panel_clear
// Removes all widgets from the panel.
void panel_clear(Panel* panel);
// }}}

// {{{ panel_get_widget
// Returns pointer to widget at index, or NULL if invalid.
Widget* panel_get_widget(Panel* panel, int index);
// }}}

// =============================================================================
// Layout
// =============================================================================

// {{{ panel_recalculate_layout
// Recalculates widget positions based on scroll offset.
// Call after adding/removing widgets or changing scroll.
void panel_recalculate_layout(Panel* panel);
// }}}

// {{{ panel_set_bounds
// Updates panel bounds and recalculates layout.
void panel_set_bounds(Panel* panel, Rectangle bounds);
// }}}

// =============================================================================
// Scrolling
// =============================================================================

// {{{ panel_scroll
// Scrolls panel by delta pixels.
// Positive delta scrolls down (content moves up).
void panel_scroll(Panel* panel, float delta);
// }}}

// {{{ panel_scroll_to_top
// Resets scroll position to top.
void panel_scroll_to_top(Panel* panel);
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ panel_render
// Renders the panel and all visible widgets.
// Uses scissor mode for clipping.
void panel_render(Panel* panel);
// }}}

// =============================================================================
// Input Handling
// =============================================================================

// {{{ panel_handle_input
// Handles mouse input for the panel and its widgets.
// Returns 1 if input was consumed, 0 otherwise.
int panel_handle_input(Panel* panel, Vector2 mouse, int pressed, int released, float wheel);
// }}}

// {{{ panel_contains_point
// Returns 1 if point is within panel bounds.
int panel_contains_point(Panel* panel, Vector2 point);
// }}}

#endif // UI_PANEL_H
