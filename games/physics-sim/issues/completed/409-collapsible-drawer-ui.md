# 409 - Collapsible Drawer UI

## Status: completed

## Depends on

- 406 (Editor panel UI system) - completed
- 408 (Minimum window width) - completed

## Implementation Notes

Created responsive drawer layout system in `src/054-ui-drawer.h` and `src/055-ui-drawer.c`:

- **LayoutMode detection**: LAYOUT_FULL (842px+), LAYOUT_LANDSCAPE (narrow+wide), LAYOUT_PORTRAIT (tall)
- **Drawer animation**: Smooth lerp animation (8.0 speed) for slide in/out
- **Bottom toolbar**: Tools/Inspector buttons with hover states, visible in collapsed modes
- **DrawerLayout struct**: Manages both tools and inspector drawers, plus toolbar state
- **Input handling**: T/I keybinds, button clicks, click-outside-to-close
- **Panel visibility**: Panels shown/hidden automatically based on mode
- **Overlay rendering**: Semi-transparent overlay when drawer is open

Integration in `src/032-editor-app.c`:
- DrawerLayout field added to EditorApp struct
- drawer_layout_init called in editor_app_create
- drawer_layout_update called early in update (before main input)
- drawer_layout_handle_input intercepts input in collapsed mode
- drawer_layout_render called before dialogs
- editor_app_resize adjusts canvas bounds based on layout mode

Files created:
- `src/054-ui-drawer.h` - Drawer structures and API
- `src/055-ui-drawer.c` - Drawer implementation

## Problem

When the window is too narrow to fit the side panels (tool palette + inspector), the UI becomes cramped or overlaps the board. Need a responsive layout that collapses panels into slide-out drawers.

## Current Behavior

- Panels are always visible at fixed positions
- Small windows cause overlap or clipping
- No responsive layout

## Intended Behavior

### Collapse Threshold

```c
// Minimum width to show permanent side panels
#define PANEL_COLLAPSE_THRESHOLD (BOARD_WIDTH + 2 * PANEL_WIDTH + 40)
// ~602 + 2*180 + 40 = ~1002px

// Below this width, panels become drawers
```

### Drawer Slide Direction

Based on window aspect ratio:

| Condition | Drawer Direction |
|-----------|------------------|
| Width > Height (landscape) | Slide from left/right |
| Height > Width (portrait) | Slide from bottom |
| Width == Height (square) | Slide from bottom |

```c
typedef enum DrawerDirection {
    DRAWER_FROM_LEFT,
    DRAWER_FROM_RIGHT,
    DRAWER_FROM_BOTTOM
} DrawerDirection;

DrawerDirection get_drawer_direction(int width, int height) {
    if (width > height) {
        return DRAWER_FROM_LEFT;  // Or DRAWER_FROM_RIGHT for inspector
    } else {
        return DRAWER_FROM_BOTTOM;
    }
}
```

### Bottom Toolbar

When panels are collapsed, show a minimal toolbar at the bottom:

```
┌─────────────────────────────────────┐
│                                     │
│            BOARD AREA               │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  [🔧 Tools]              [🔍 Inspector] │  ← Bottom toolbar
└─────────────────────────────────────┘
```

```c
#define TOOLBAR_HEIGHT 40.0f

typedef struct BottomToolbar {
    Rectangle bounds;
    int tools_button_hovered;
    int inspector_button_hovered;
} BottomToolbar;

void toolbar_render(BottomToolbar* toolbar) {
    DrawRectangleRec(toolbar->bounds, (Color){ 45, 45, 50, 255 });

    // Tools button (left side)
    Rectangle tools_btn = {
        toolbar->bounds.x + 10,
        toolbar->bounds.y + 5,
        100, 30
    };
    DrawRectangleRec(tools_btn, toolbar->tools_button_hovered ? DARKGRAY : GRAY);
    DrawText("Tools", tools_btn.x + 25, tools_btn.y + 7, 16, WHITE);

    // Inspector button (right side)
    Rectangle inspector_btn = {
        toolbar->bounds.x + toolbar->bounds.width - 110,
        toolbar->bounds.y + 5,
        100, 30
    };
    DrawRectangleRec(inspector_btn, toolbar->inspector_button_hovered ? DARKGRAY : GRAY);
    DrawText("Inspector", inspector_btn.x + 15, inspector_btn.y + 7, 16, WHITE);
}
```

### Drawer Animation

```c
typedef struct Drawer {
    Panel* panel;              // The panel content
    DrawerDirection direction;
    float open_amount;         // 0.0 = closed, 1.0 = fully open
    float target_open;         // Animation target
    int is_open;
} Drawer;

void drawer_update(Drawer* drawer, float dt) {
    // Smooth animation toward target
    float speed = 8.0f;
    drawer->open_amount += (drawer->target_open - drawer->open_amount) * speed * dt;

    // Snap when close enough
    if (fabsf(drawer->target_open - drawer->open_amount) < 0.01f) {
        drawer->open_amount = drawer->target_open;
    }
}

void drawer_toggle(Drawer* drawer) {
    drawer->is_open = !drawer->is_open;
    drawer->target_open = drawer->is_open ? 1.0f : 0.0f;
}

Rectangle drawer_get_bounds(Drawer* drawer, int window_width, int window_height) {
    float panel_size = PANEL_WIDTH;

    switch (drawer->direction) {
        case DRAWER_FROM_LEFT: {
            float x = -panel_size + (drawer->open_amount * panel_size);
            return (Rectangle){ x, 0, panel_size, window_height - TOOLBAR_HEIGHT };
        }
        case DRAWER_FROM_RIGHT: {
            float x = window_width - (drawer->open_amount * panel_size);
            return (Rectangle){ x, 0, panel_size, window_height - TOOLBAR_HEIGHT };
        }
        case DRAWER_FROM_BOTTOM: {
            // For bottom drawers, stack them or use tabs
            float y = window_height - TOOLBAR_HEIGHT - (drawer->open_amount * panel_size);
            return (Rectangle){ 0, y, window_width, panel_size };
        }
    }
}
```

### Drawer Triggers

Three ways to open a drawer:

1. **Click toolbar button** - Toggle drawer
2. **Tap/touch** - Same as click (mobile/touchscreen support)
3. **Keybind** - `T` for tools, `I` for inspector

```c
void editor_handle_drawer_input(void) {
    // Keybinds
    if (IsKeyPressed(KEY_T)) {
        drawer_toggle(&tools_drawer);
    }
    if (IsKeyPressed(KEY_I)) {
        drawer_toggle(&inspector_drawer);
    }

    // Toolbar button clicks
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        Vector2 mouse = GetMousePosition();

        if (CheckCollisionPointRec(mouse, tools_button_rect)) {
            drawer_toggle(&tools_drawer);
        }
        if (CheckCollisionPointRec(mouse, inspector_button_rect)) {
            drawer_toggle(&inspector_drawer);
        }
    }

    // Click outside drawer to close
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        Vector2 mouse = GetMousePosition();

        if (tools_drawer.is_open &&
            !CheckCollisionPointRec(mouse, drawer_get_bounds(&tools_drawer, ...))) {
            drawer_toggle(&tools_drawer);
        }
        // Same for inspector
    }
}
```

### Portrait Mode: Bottom Drawers

When in portrait mode, both panels slide up from the bottom. They could:

**Option A: Tabbed interface**
```
┌─────────────────┐
│                 │
│   BOARD AREA    │
│                 │
├─────────────────┤
│ [Tools|Inspector]│  ← Tab bar
│                 │
│  Panel Content  │
│                 │
└─────────────────┘
```

**Option B: Separate drawers that overlay**
- Tools drawer on left half of bottom
- Inspector drawer on right half of bottom
- Can be open simultaneously

Recommend Option A for cleaner UX in portrait.

```c
typedef struct TabbedDrawer {
    Panel* panels[2];       // Tools and Inspector
    int active_tab;         // 0 = tools, 1 = inspector
    float open_amount;
    int is_open;
} TabbedDrawer;
```

### Layout Decision Logic

```c
typedef enum LayoutMode {
    LAYOUT_FULL,        // Permanent side panels
    LAYOUT_LANDSCAPE,   // Side drawers
    LAYOUT_PORTRAIT     // Bottom drawer with tabs
} LayoutMode;

LayoutMode get_layout_mode(int width, int height) {
    if (width >= PANEL_COLLAPSE_THRESHOLD) {
        return LAYOUT_FULL;
    } else if (width > height) {
        return LAYOUT_LANDSCAPE;
    } else {
        return LAYOUT_PORTRAIT;
    }
}

void editor_update_layout(void) {
    int width = GetScreenWidth();
    int height = GetScreenHeight();

    LayoutMode mode = get_layout_mode(width, height);

    switch (mode) {
        case LAYOUT_FULL:
            // Show permanent panels, hide toolbar
            tools_panel.visible = 1;
            inspector_panel.visible = 1;
            bottom_toolbar.visible = 0;
            break;

        case LAYOUT_LANDSCAPE:
            // Hide panels, show toolbar, drawers slide from sides
            tools_panel.visible = 0;
            inspector_panel.visible = 0;
            bottom_toolbar.visible = 1;
            tools_drawer.direction = DRAWER_FROM_LEFT;
            inspector_drawer.direction = DRAWER_FROM_RIGHT;
            break;

        case LAYOUT_PORTRAIT:
            // Hide panels, show toolbar, use tabbed bottom drawer
            tools_panel.visible = 0;
            inspector_panel.visible = 0;
            bottom_toolbar.visible = 1;
            tabbed_drawer.direction = DRAWER_FROM_BOTTOM;
            break;
    }
}
```

## Implementation Steps

1. Add collapse threshold constant
2. Create LayoutMode enum and detection function
3. Implement BottomToolbar with two buttons
4. Create Drawer struct with animation state
5. Implement drawer slide animation (lerp toward target)
6. Implement LAYOUT_LANDSCAPE with side drawers
7. Implement LAYOUT_PORTRAIT with tabbed bottom drawer
8. Add keybinds (T for tools, I for inspector)
9. Add click-outside-to-close behavior
10. Handle window resize events to switch modes
11. Test transitions between layout modes
12. Polish animations and visual styling

## Files to Create

- `src/048-ui-drawer.h` - Drawer structures and API
- `src/049-ui-drawer.c` - Drawer implementation

## Files to Modify

- `src/032-editor-app.c` - Integrate responsive layout system
- `src/046-ui-panel.h` - Add visibility flag to panels

## Notes

- Drawers render on top of board (with slight transparency or shadow)
- Consider swipe gestures for mobile/touchscreen
- Toolbar could also collapse on very small windows (just show icons)
- Remember drawer state between sessions? Or always start closed?
- Keyboard shortcuts should work regardless of drawer state
