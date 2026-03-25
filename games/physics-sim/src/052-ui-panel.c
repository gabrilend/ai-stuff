// src/052-ui-panel.c
// UI panel container implementation
// Handles widget layout, scrolling, and input dispatch
//
// Issue 406: Editor panel UI system

#include "051-ui-panel.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// =============================================================================
// Panel Lifecycle
// =============================================================================

// {{{ panel_create
Panel* panel_create(const char* title, Rectangle bounds) {
    Panel* panel = (Panel*)malloc(sizeof(Panel));
    if (!panel) {
        fprintf(stderr, "ERROR: Failed to allocate panel\n");
        return NULL;
    }

    strncpy(panel->title, title, 63);
    panel->title[63] = '\0';
    panel->bounds = bounds;
    panel->widget_count = 0;
    panel->scroll_y = 0;
    panel->content_height = 0;
    panel->scrollbar_dragging = 0;
    panel->background = PANEL_BG_COLOR;
    panel->border = PANEL_BORDER_COLOR;
    panel->visible = 1;

    return panel;
}
// }}}

// {{{ panel_destroy
void panel_destroy(Panel* panel) {
    if (panel) {
        free(panel);
    }
}
// }}}

// =============================================================================
// Widget Management
// =============================================================================

// {{{ panel_add_widget
int panel_add_widget(Panel* panel, Widget widget) {
    if (!panel) return -1;
    if (panel->widget_count >= PANEL_MAX_WIDGETS) {
        fprintf(stderr, "WARNING: Panel '%s' widget limit reached\n", panel->title);
        return -1;
    }

    int index = panel->widget_count;
    panel->widgets[index] = widget;
    panel->widget_count++;

    panel_recalculate_layout(panel);
    return index;
}
// }}}

// {{{ panel_clear
void panel_clear(Panel* panel) {
    if (!panel) return;
    panel->widget_count = 0;
    panel->scroll_y = 0;
    panel->content_height = 0;
}
// }}}

// {{{ panel_get_widget
Widget* panel_get_widget(Panel* panel, int index) {
    if (!panel) return NULL;
    if (index < 0 || index >= panel->widget_count) return NULL;
    return &panel->widgets[index];
}
// }}}

// =============================================================================
// Layout
// =============================================================================

// {{{ panel_recalculate_layout
void panel_recalculate_layout(Panel* panel) {
    if (!panel) return;

    // Content area (below header, with padding)
    float content_x = panel->bounds.x + PANEL_PADDING;
    float content_y = panel->bounds.y + PANEL_HEADER_HEIGHT + PANEL_PADDING;
    float content_width = panel->bounds.width - (2 * PANEL_PADDING) - PANEL_SCROLLBAR_WIDTH;

    float y = 0;  // Relative to content area

    for (int i = 0; i < panel->widget_count; i++) {
        Widget* w = &panel->widgets[i];

        // Calculate widget height based on type
        float widget_height = WIDGET_HEIGHT;
        if (w->type == WIDGET_SLIDER || w->type == WIDGET_NUMBER_FIELD) {
            widget_height = WIDGET_HEIGHT + 16;  // Extra space for label
        } else if (w->type == WIDGET_SEPARATOR) {
            widget_height = 12;
        }

        // Set widget bounds (accounting for scroll)
        w->bounds = (Rectangle){
            content_x,
            content_y + y - panel->scroll_y,
            content_width,
            widget_height
        };

        y += widget_height + WIDGET_SPACING;
    }

    panel->content_height = y;
}
// }}}

// {{{ panel_set_bounds
void panel_set_bounds(Panel* panel, Rectangle bounds) {
    if (!panel) return;
    panel->bounds = bounds;
    panel_recalculate_layout(panel);
}
// }}}

// =============================================================================
// Scrolling
// =============================================================================

// {{{ panel_scroll
void panel_scroll(Panel* panel, float delta) {
    if (!panel) return;

    float visible_height = panel->bounds.height - PANEL_HEADER_HEIGHT - (2 * PANEL_PADDING);
    float max_scroll = panel->content_height - visible_height;
    if (max_scroll < 0) max_scroll = 0;

    panel->scroll_y += delta;

    // Clamp scroll
    if (panel->scroll_y < 0) panel->scroll_y = 0;
    if (panel->scroll_y > max_scroll) panel->scroll_y = max_scroll;

    panel_recalculate_layout(panel);
}
// }}}

// {{{ panel_scroll_to_top
void panel_scroll_to_top(Panel* panel) {
    if (!panel) return;
    panel->scroll_y = 0;
    panel_recalculate_layout(panel);
}
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ panel_render
void panel_render(Panel* panel) {
    if (!panel || !panel->visible) return;

    // Panel background
    DrawRectangleRec(panel->bounds, panel->background);

    // Header
    Rectangle header = {
        panel->bounds.x, panel->bounds.y,
        panel->bounds.width, PANEL_HEADER_HEIGHT
    };
    DrawRectangleRec(header, PANEL_HEADER_COLOR);
    DrawText(panel->title,
             (int)(header.x + PANEL_PADDING),
             (int)(header.y + (PANEL_HEADER_HEIGHT - 16) / 2),
             16, PANEL_TITLE_COLOR);

    // Content area scissor
    Rectangle content_area = {
        panel->bounds.x,
        panel->bounds.y + PANEL_HEADER_HEIGHT,
        panel->bounds.width,
        panel->bounds.height - PANEL_HEADER_HEIGHT
    };
    BeginScissorMode(
        (int)content_area.x, (int)content_area.y,
        (int)content_area.width, (int)content_area.height
    );

    // Render widgets
    for (int i = 0; i < panel->widget_count; i++) {
        Widget* w = &panel->widgets[i];
        if (w->visible) {
            // Only render if widget is in visible area
            if (w->bounds.y + w->bounds.height > content_area.y &&
                w->bounds.y < content_area.y + content_area.height) {
                widget_render(w);
            }
        }
    }

    EndScissorMode();

    // Scrollbar (if content exceeds visible area)
    float visible_height = panel->bounds.height - PANEL_HEADER_HEIGHT - (2 * PANEL_PADDING);
    if (panel->content_height > visible_height) {
        Rectangle scrollbar_bg = {
            panel->bounds.x + panel->bounds.width - PANEL_SCROLLBAR_WIDTH - 2,
            panel->bounds.y + PANEL_HEADER_HEIGHT + 2,
            PANEL_SCROLLBAR_WIDTH,
            panel->bounds.height - PANEL_HEADER_HEIGHT - 4
        };
        DrawRectangleRec(scrollbar_bg, PANEL_SCROLLBAR_BG);

        // Scrollbar thumb
        float thumb_ratio = visible_height / panel->content_height;
        float thumb_height = scrollbar_bg.height * thumb_ratio;
        if (thumb_height < 20) thumb_height = 20;

        float max_scroll = panel->content_height - visible_height;
        float scroll_ratio = (max_scroll > 0) ? panel->scroll_y / max_scroll : 0;
        float thumb_y = scrollbar_bg.y + scroll_ratio * (scrollbar_bg.height - thumb_height);

        Rectangle thumb = { scrollbar_bg.x, thumb_y, PANEL_SCROLLBAR_WIDTH, thumb_height };
        Color thumb_color = panel->scrollbar_dragging ? WIDGET_ACTIVE_COLOR : PANEL_SCROLLBAR_FG;
        DrawRectangleRec(thumb, thumb_color);
    }

    // Border
    DrawRectangleLinesEx(panel->bounds, 1, panel->border);
}
// }}}

// =============================================================================
// Input Handling
// =============================================================================

// {{{ panel_contains_point
int panel_contains_point(Panel* panel, Vector2 point) {
    if (!panel || !panel->visible) return 0;
    return CheckCollisionPointRec(point, panel->bounds);
}
// }}}

// {{{ panel_handle_input
int panel_handle_input(Panel* panel, Vector2 mouse, int pressed, int released, float wheel) {
    if (!panel || !panel->visible) return 0;
    if (!panel_contains_point(panel, mouse)) {
        // End any dragging if mouse leaves panel
        panel->scrollbar_dragging = 0;
        // Reset slider dragging for all widgets
        for (int i = 0; i < panel->widget_count; i++) {
            if (panel->widgets[i].type == WIDGET_SLIDER) {
                panel->widgets[i].data.slider.dragging = 0;
            }
        }
        return 0;
    }

    // Check if in header area (not interactive beyond panel drag)
    Rectangle header = {
        panel->bounds.x, panel->bounds.y,
        panel->bounds.width, PANEL_HEADER_HEIGHT
    };
    if (CheckCollisionPointRec(mouse, header)) {
        // Could implement panel drag here in future
        return 1;  // Consume input
    }

    // Scrollbar handling
    float visible_height = panel->bounds.height - PANEL_HEADER_HEIGHT - (2 * PANEL_PADDING);
    if (panel->content_height > visible_height) {
        Rectangle scrollbar_area = {
            panel->bounds.x + panel->bounds.width - PANEL_SCROLLBAR_WIDTH - 4,
            panel->bounds.y + PANEL_HEADER_HEIGHT,
            PANEL_SCROLLBAR_WIDTH + 4,
            panel->bounds.height - PANEL_HEADER_HEIGHT
        };

        if (CheckCollisionPointRec(mouse, scrollbar_area)) {
            if (pressed) {
                panel->scrollbar_dragging = 1;
                panel->drag_start_y = mouse.y;
                panel->drag_start_scroll = panel->scroll_y;
                return 1;
            }
        }

        if (panel->scrollbar_dragging) {
            if (released) {
                panel->scrollbar_dragging = 0;
            } else {
                // Calculate scroll from drag
                float drag_delta = mouse.y - panel->drag_start_y;
                float max_scroll = panel->content_height - visible_height;
                float scroll_per_pixel = max_scroll / (scrollbar_area.height - 20);
                panel->scroll_y = panel->drag_start_scroll + drag_delta * scroll_per_pixel;

                // Clamp
                if (panel->scroll_y < 0) panel->scroll_y = 0;
                if (panel->scroll_y > max_scroll) panel->scroll_y = max_scroll;

                panel_recalculate_layout(panel);
            }
            return 1;
        }
    }

    // Mouse wheel scrolling
    if (wheel != 0) {
        panel_scroll(panel, -wheel * 30);
        return 1;
    }

    // Update hover state for all widgets
    for (int i = 0; i < panel->widget_count; i++) {
        widget_update_hover(&panel->widgets[i], mouse);
    }

    // Handle slider dragging
    for (int i = 0; i < panel->widget_count; i++) {
        Widget* w = &panel->widgets[i];
        if (w->type == WIDGET_SLIDER && w->data.slider.dragging) {
            widget_handle_drag(w, mouse);
            if (released) {
                w->data.slider.dragging = 0;
            }
            return 1;
        }
    }

    // Widget click handling
    if (pressed || released) {
        for (int i = 0; i < panel->widget_count; i++) {
            Widget* w = &panel->widgets[i];
            // Check if widget is in visible area
            float content_top = panel->bounds.y + PANEL_HEADER_HEIGHT;
            float content_bottom = panel->bounds.y + panel->bounds.height;
            if (w->bounds.y + w->bounds.height < content_top ||
                w->bounds.y > content_bottom) {
                continue;  // Widget is scrolled out of view
            }

            if (widget_handle_mouse(w, mouse, pressed, released)) {
                return 1;
            }
        }
    }

    return 1;  // Panel consumes all input within its bounds
}
// }}}
