// src/055-ui-drawer.c
// Collapsible drawer UI implementation
// Provides responsive layout with animated slide-out panels
//
// Issue 409: Collapsible drawer UI

#include <stdio.h>
#include <math.h>
#include "054-ui-drawer.h"

// =============================================================================
// Internal Constants
// =============================================================================

#define TOOLBAR_BUTTON_WIDTH 100
#define TOOLBAR_BUTTON_HEIGHT 30
#define TOOLBAR_BUTTON_MARGIN 10

// Toolbar colors
#define TOOLBAR_BG_COLOR       (Color){ 35, 35, 40, 255 }
#define TOOLBAR_BUTTON_COLOR   (Color){ 55, 55, 60, 255 }
#define TOOLBAR_HOVER_COLOR    (Color){ 70, 70, 80, 255 }
#define TOOLBAR_TEXT_COLOR     (Color){ 200, 200, 200, 255 }

// Drawer overlay color (semi-transparent background)
#define DRAWER_OVERLAY_COLOR   (Color){ 0, 0, 0, 100 }

// =============================================================================
// Layout Detection
// =============================================================================

// {{{ get_layout_mode
LayoutMode get_layout_mode(int width, int height) {
    if (width >= PANEL_COLLAPSE_THRESHOLD) {
        return LAYOUT_FULL;
    } else if (width > height) {
        return LAYOUT_LANDSCAPE;
    } else {
        return LAYOUT_PORTRAIT;
    }
}
// }}}

// =============================================================================
// Drawer Lifecycle
// =============================================================================

// {{{ drawer_layout_init
void drawer_layout_init(DrawerLayout* layout, Panel* tools, Panel* inspector) {
    if (!layout) return;

    layout->mode = LAYOUT_FULL;

    // Tools drawer (left side)
    layout->tools_drawer.panel = tools;
    layout->tools_drawer.direction = DRAWER_FROM_LEFT;
    layout->tools_drawer.open_amount = 0.0f;
    layout->tools_drawer.target_open = 0.0f;
    layout->tools_drawer.is_open = 0;
    layout->tools_drawer.width = tools ? tools->bounds.width : 100.0f;

    // Inspector drawer (right side)
    layout->inspector_drawer.panel = inspector;
    layout->inspector_drawer.direction = DRAWER_FROM_RIGHT;
    layout->inspector_drawer.open_amount = 0.0f;
    layout->inspector_drawer.target_open = 0.0f;
    layout->inspector_drawer.is_open = 0;
    layout->inspector_drawer.width = inspector ? inspector->bounds.width : 100.0f;

    // Bottom toolbar
    layout->toolbar.visible = 0;
    layout->toolbar.tools_hovered = 0;
    layout->toolbar.inspector_hovered = 0;

    // Portrait mode tab
    layout->active_tab = 0;
}
// }}}

// =============================================================================
// Drawer Control
// =============================================================================

// {{{ drawer_toggle
void drawer_toggle(Drawer* drawer) {
    if (!drawer) return;
    drawer->is_open = !drawer->is_open;
    drawer->target_open = drawer->is_open ? 1.0f : 0.0f;
}
// }}}

// {{{ drawer_open
void drawer_open(Drawer* drawer) {
    if (!drawer) return;
    drawer->is_open = 1;
    drawer->target_open = 1.0f;
}
// }}}

// {{{ drawer_close
void drawer_close(Drawer* drawer) {
    if (!drawer) return;
    drawer->is_open = 0;
    drawer->target_open = 0.0f;
}
// }}}

// =============================================================================
// Animation
// =============================================================================

// {{{ drawer_update_animation
static void drawer_update_animation(Drawer* drawer, float dt) {
    if (!drawer) return;

    // Smooth interpolation toward target
    float diff = drawer->target_open - drawer->open_amount;
    drawer->open_amount += diff * DRAWER_ANIMATION_SPEED * dt;

    // Snap when close enough
    if (fabsf(diff) < 0.01f) {
        drawer->open_amount = drawer->target_open;
    }
}
// }}}

// =============================================================================
// Bounds Calculation
// =============================================================================

// {{{ drawer_get_bounds
Rectangle drawer_get_bounds(Drawer* drawer, int window_width, int window_height) {
    if (!drawer) return (Rectangle){0, 0, 0, 0};

    float panel_width = drawer->width;
    float content_height = (float)window_height - DRAWER_TOOLBAR_HEIGHT;

    switch (drawer->direction) {
        case DRAWER_FROM_LEFT: {
            float x = -panel_width + (drawer->open_amount * panel_width);
            return (Rectangle){ x, 0, panel_width, content_height };
        }
        case DRAWER_FROM_RIGHT: {
            float x = (float)window_width - (drawer->open_amount * panel_width);
            return (Rectangle){ x, 0, panel_width, content_height };
        }
        case DRAWER_FROM_BOTTOM: {
            float y = (float)window_height - DRAWER_TOOLBAR_HEIGHT -
                      (drawer->open_amount * content_height * 0.6f);
            return (Rectangle){ 0, y, (float)window_width, content_height * 0.6f };
        }
    }
    return (Rectangle){0, 0, 0, 0};
}
// }}}

// =============================================================================
// Update
// =============================================================================

// {{{ drawer_layout_update
void drawer_layout_update(DrawerLayout* layout, int window_width, int window_height, float dt) {
    if (!layout) return;

    LayoutMode new_mode = get_layout_mode(window_width, window_height);

    // Handle mode transition
    if (new_mode != layout->mode) {
        layout->mode = new_mode;

        if (new_mode == LAYOUT_FULL) {
            // Expanding to full: close drawers, show panels
            drawer_close(&layout->tools_drawer);
            drawer_close(&layout->inspector_drawer);
            layout->toolbar.visible = 0;

            if (layout->tools_drawer.panel) {
                layout->tools_drawer.panel->visible = 1;
            }
            if (layout->inspector_drawer.panel) {
                layout->inspector_drawer.panel->visible = 1;
            }
        } else {
            // Collapsing: hide panels, show toolbar
            layout->toolbar.visible = 1;

            if (layout->tools_drawer.panel) {
                layout->tools_drawer.panel->visible = 0;
            }
            if (layout->inspector_drawer.panel) {
                layout->inspector_drawer.panel->visible = 0;
            }

            // Set direction based on mode
            if (new_mode == LAYOUT_LANDSCAPE) {
                layout->tools_drawer.direction = DRAWER_FROM_LEFT;
                layout->inspector_drawer.direction = DRAWER_FROM_RIGHT;
            } else {
                // Portrait: both from bottom
                layout->tools_drawer.direction = DRAWER_FROM_BOTTOM;
                layout->inspector_drawer.direction = DRAWER_FROM_BOTTOM;
            }
        }
    }

    // Update toolbar bounds
    layout->toolbar.bounds = (Rectangle){
        0, (float)window_height - DRAWER_TOOLBAR_HEIGHT,
        (float)window_width, DRAWER_TOOLBAR_HEIGHT
    };

    // Update drawer animations
    drawer_update_animation(&layout->tools_drawer, dt);
    drawer_update_animation(&layout->inspector_drawer, dt);

    // Update drawer panel bounds if drawer is open
    if (layout->mode != LAYOUT_FULL) {
        if (layout->tools_drawer.panel && layout->tools_drawer.open_amount > 0.01f) {
            Rectangle bounds = drawer_get_bounds(&layout->tools_drawer, window_width, window_height);
            panel_set_bounds(layout->tools_drawer.panel, bounds);
            layout->tools_drawer.panel->visible = 1;
        } else if (layout->tools_drawer.panel) {
            layout->tools_drawer.panel->visible = 0;
        }

        if (layout->inspector_drawer.panel && layout->inspector_drawer.open_amount > 0.01f) {
            Rectangle bounds = drawer_get_bounds(&layout->inspector_drawer, window_width, window_height);
            panel_set_bounds(layout->inspector_drawer.panel, bounds);
            layout->inspector_drawer.panel->visible = 1;
        } else if (layout->inspector_drawer.panel) {
            layout->inspector_drawer.panel->visible = 0;
        }
    }
}
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ render_toolbar
static void render_toolbar(DrawerLayout* layout) {
    if (!layout || !layout->toolbar.visible) return;

    // Toolbar background
    DrawRectangleRec(layout->toolbar.bounds, TOOLBAR_BG_COLOR);
    DrawLine(
        (int)layout->toolbar.bounds.x,
        (int)layout->toolbar.bounds.y,
        (int)(layout->toolbar.bounds.x + layout->toolbar.bounds.width),
        (int)layout->toolbar.bounds.y,
        (Color){ 60, 60, 65, 255 }
    );

    // Tools button (left side)
    Rectangle tools_btn = {
        layout->toolbar.bounds.x + TOOLBAR_BUTTON_MARGIN,
        layout->toolbar.bounds.y + (DRAWER_TOOLBAR_HEIGHT - TOOLBAR_BUTTON_HEIGHT) / 2,
        TOOLBAR_BUTTON_WIDTH,
        TOOLBAR_BUTTON_HEIGHT
    };
    Color tools_color = layout->toolbar.tools_hovered ? TOOLBAR_HOVER_COLOR : TOOLBAR_BUTTON_COLOR;
    if (layout->tools_drawer.is_open) {
        tools_color = (Color){ 80, 120, 80, 255 };  // Green when open
    }
    DrawRectangleRec(tools_btn, tools_color);
    DrawRectangleLinesEx(tools_btn, 1, (Color){ 80, 80, 90, 255 });
    DrawText("Tools", (int)(tools_btn.x + 28), (int)(tools_btn.y + 8), 14, TOOLBAR_TEXT_COLOR);

    // Inspector button (right side)
    Rectangle inspector_btn = {
        layout->toolbar.bounds.x + layout->toolbar.bounds.width - TOOLBAR_BUTTON_WIDTH - TOOLBAR_BUTTON_MARGIN,
        layout->toolbar.bounds.y + (DRAWER_TOOLBAR_HEIGHT - TOOLBAR_BUTTON_HEIGHT) / 2,
        TOOLBAR_BUTTON_WIDTH,
        TOOLBAR_BUTTON_HEIGHT
    };
    Color insp_color = layout->toolbar.inspector_hovered ? TOOLBAR_HOVER_COLOR : TOOLBAR_BUTTON_COLOR;
    if (layout->inspector_drawer.is_open) {
        insp_color = (Color){ 80, 120, 80, 255 };  // Green when open
    }
    DrawRectangleRec(inspector_btn, insp_color);
    DrawRectangleLinesEx(inspector_btn, 1, (Color){ 80, 80, 90, 255 });
    DrawText("Inspector", (int)(inspector_btn.x + 12), (int)(inspector_btn.y + 8), 14, TOOLBAR_TEXT_COLOR);
}
// }}}

// {{{ drawer_layout_render
void drawer_layout_render(DrawerLayout* layout, int window_width, int window_height) {
    if (!layout) return;

    // Skip rendering in full mode (panels render themselves)
    if (layout->mode == LAYOUT_FULL) return;

    // Draw overlay if any drawer is open
    if (layout->tools_drawer.open_amount > 0.01f ||
        layout->inspector_drawer.open_amount > 0.01f) {
        DrawRectangle(0, 0, window_width, window_height - (int)DRAWER_TOOLBAR_HEIGHT,
                      DRAWER_OVERLAY_COLOR);
    }

    // Render open drawers (panels render via panel_render)
    // Note: Panels are already set to visible in update, they render in main loop

    // Render toolbar
    render_toolbar(layout);
}
// }}}

// =============================================================================
// Input Handling
// =============================================================================

// {{{ drawer_layout_handle_input
int drawer_layout_handle_input(DrawerLayout* layout, int window_width, int window_height) {
    if (!layout) return 0;
    if (layout->mode == LAYOUT_FULL) return 0;

    Vector2 mouse = GetMousePosition();

    // Update hover states for toolbar buttons
    Rectangle tools_btn = {
        layout->toolbar.bounds.x + TOOLBAR_BUTTON_MARGIN,
        layout->toolbar.bounds.y + (DRAWER_TOOLBAR_HEIGHT - TOOLBAR_BUTTON_HEIGHT) / 2,
        TOOLBAR_BUTTON_WIDTH,
        TOOLBAR_BUTTON_HEIGHT
    };
    Rectangle inspector_btn = {
        layout->toolbar.bounds.x + layout->toolbar.bounds.width - TOOLBAR_BUTTON_WIDTH - TOOLBAR_BUTTON_MARGIN,
        layout->toolbar.bounds.y + (DRAWER_TOOLBAR_HEIGHT - TOOLBAR_BUTTON_HEIGHT) / 2,
        TOOLBAR_BUTTON_WIDTH,
        TOOLBAR_BUTTON_HEIGHT
    };

    layout->toolbar.tools_hovered = CheckCollisionPointRec(mouse, tools_btn);
    layout->toolbar.inspector_hovered = CheckCollisionPointRec(mouse, inspector_btn);

    // Handle keybinds
    if (IsKeyPressed(KEY_T)) {
        drawer_toggle(&layout->tools_drawer);
        // In portrait mode, close other drawer
        if (layout->mode == LAYOUT_PORTRAIT && layout->tools_drawer.is_open) {
            drawer_close(&layout->inspector_drawer);
        }
        return 1;
    }
    if (IsKeyPressed(KEY_I)) {
        drawer_toggle(&layout->inspector_drawer);
        // In portrait mode, close other drawer
        if (layout->mode == LAYOUT_PORTRAIT && layout->inspector_drawer.is_open) {
            drawer_close(&layout->tools_drawer);
        }
        return 1;
    }

    // Handle toolbar button clicks
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        if (layout->toolbar.tools_hovered) {
            drawer_toggle(&layout->tools_drawer);
            if (layout->mode == LAYOUT_PORTRAIT && layout->tools_drawer.is_open) {
                drawer_close(&layout->inspector_drawer);
            }
            return 1;
        }
        if (layout->toolbar.inspector_hovered) {
            drawer_toggle(&layout->inspector_drawer);
            if (layout->mode == LAYOUT_PORTRAIT && layout->inspector_drawer.is_open) {
                drawer_close(&layout->tools_drawer);
            }
            return 1;
        }

        // Click outside drawer to close
        if (layout->tools_drawer.is_open) {
            Rectangle tools_bounds = drawer_get_bounds(&layout->tools_drawer, window_width, window_height);
            if (!CheckCollisionPointRec(mouse, tools_bounds) &&
                !CheckCollisionPointRec(mouse, layout->toolbar.bounds)) {
                drawer_close(&layout->tools_drawer);
                return 1;
            }
        }
        if (layout->inspector_drawer.is_open) {
            Rectangle insp_bounds = drawer_get_bounds(&layout->inspector_drawer, window_width, window_height);
            if (!CheckCollisionPointRec(mouse, insp_bounds) &&
                !CheckCollisionPointRec(mouse, layout->toolbar.bounds)) {
                drawer_close(&layout->inspector_drawer);
                return 1;
            }
        }
    }

    return 0;
}
// }}}
