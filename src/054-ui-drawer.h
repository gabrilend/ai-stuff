// src/054-ui-drawer.h
// Collapsible drawer UI system for responsive editor layout
// Panels collapse into slide-out drawers on narrow windows
//
// Issue 409: Collapsible drawer UI
//
// External functions: drawer_create, drawer_destroy, drawer_toggle, drawer_update,
//                     drawer_render, drawer_handle_input, get_layout_mode

#ifndef UI_DRAWER_H
#define UI_DRAWER_H

#include "raylib.h"
#include "051-ui-panel.h"

// =============================================================================
// Layout Constants
// =============================================================================

// Minimum width to show permanent side panels
// Below this, panels collapse into drawers
// ~602 (board) + 2*100 (panels) + 40 (margins) = ~842px
#define PANEL_COLLAPSE_THRESHOLD 842

// Bottom toolbar height when in collapsed mode
#define DRAWER_TOOLBAR_HEIGHT 40.0f

// Drawer animation speed (higher = faster)
#define DRAWER_ANIMATION_SPEED 8.0f

// =============================================================================
// Enumerations
// =============================================================================

// {{{ typedef enum LayoutMode
// Layout mode based on window dimensions
typedef enum LayoutMode {
    LAYOUT_FULL,        // Permanent side panels (wide window)
    LAYOUT_LANDSCAPE,   // Side drawers (narrow landscape)
    LAYOUT_PORTRAIT     // Bottom drawer with tabs (portrait)
} LayoutMode;
// }}}

// {{{ typedef enum DrawerDirection
// Direction from which drawer slides
typedef enum DrawerDirection {
    DRAWER_FROM_LEFT,
    DRAWER_FROM_RIGHT,
    DRAWER_FROM_BOTTOM
} DrawerDirection;
// }}}

// =============================================================================
// Structures
// =============================================================================

// {{{ typedef struct Drawer
// Animated slide-out drawer containing a panel
typedef struct Drawer {
    Panel* panel;               // The panel content
    DrawerDirection direction;  // Slide direction
    float open_amount;          // 0.0 = closed, 1.0 = fully open
    float target_open;          // Animation target
    int is_open;                // Logical open state
    float width;                // Drawer width (or height for bottom)
} Drawer;
// }}}

// {{{ typedef struct BottomToolbar
// Minimal toolbar shown when panels are collapsed
typedef struct BottomToolbar {
    Rectangle bounds;
    int tools_hovered;
    int inspector_hovered;
    int visible;
} BottomToolbar;
// }}}

// {{{ typedef struct DrawerLayout
// Complete drawer layout state
typedef struct DrawerLayout {
    LayoutMode mode;
    Drawer tools_drawer;
    Drawer inspector_drawer;
    BottomToolbar toolbar;
    int active_tab;  // For portrait mode: 0 = tools, 1 = inspector
} DrawerLayout;
// }}}

// =============================================================================
// Layout Detection
// =============================================================================

// {{{ get_layout_mode
// Determines layout mode based on window dimensions.
// Returns LAYOUT_FULL if window is wide enough for permanent panels.
// Returns LAYOUT_LANDSCAPE for narrow but landscape windows.
// Returns LAYOUT_PORTRAIT for portrait-oriented windows.
LayoutMode get_layout_mode(int width, int height);
// }}}

// =============================================================================
// Drawer Lifecycle
// =============================================================================

// {{{ drawer_layout_init
// Initializes drawer layout with tools and inspector panels.
// Panels are assigned but not modified.
void drawer_layout_init(DrawerLayout* layout, Panel* tools, Panel* inspector);
// }}}

// =============================================================================
// Drawer Control
// =============================================================================

// {{{ drawer_toggle
// Toggles drawer open/closed state.
void drawer_toggle(Drawer* drawer);
// }}}

// {{{ drawer_open
// Opens the drawer.
void drawer_open(Drawer* drawer);
// }}}

// {{{ drawer_close
// Closes the drawer.
void drawer_close(Drawer* drawer);
// }}}

// =============================================================================
// Update and Render
// =============================================================================

// {{{ drawer_layout_update
// Updates drawer animations and layout mode based on window size.
// Should be called each frame.
void drawer_layout_update(DrawerLayout* layout, int window_width, int window_height, float dt);
// }}}

// {{{ drawer_layout_render
// Renders drawers and toolbar.
// Should be called after main content but before dialogs.
void drawer_layout_render(DrawerLayout* layout, int window_width, int window_height);
// }}}

// =============================================================================
// Input Handling
// =============================================================================

// {{{ drawer_layout_handle_input
// Handles input for toolbar buttons and drawers.
// Returns 1 if input was consumed.
int drawer_layout_handle_input(DrawerLayout* layout, int window_width, int window_height);
// }}}

// {{{ drawer_get_bounds
// Returns current bounds of drawer based on animation state.
Rectangle drawer_get_bounds(Drawer* drawer, int window_width, int window_height);
// }}}

#endif // UI_DRAWER_H
