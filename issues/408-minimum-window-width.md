# 408 - Minimum Window Width Constraint

## Status: awaiting-work

## Depends on

None - can be implemented independently.

## Dependents

- 409 (Collapsible drawer) depends on this for window handling

## Problem

Users can resize the window below the board width, causing balls to go off-screen and making the game unplayable. Need to enforce a minimum width while respecting tiled window manager behavior.

## Current Behavior

- Window can be resized to any dimensions
- Board and balls can be clipped off-screen
- No minimum size enforcement

## Intended Behavior

- **Windowed mode**: Prevent resizing below minimum board width
- **Tiled WM mode (i3, sway, etc.)**: Allow any size - user knows what they're doing
- **Height**: No restriction, user can make it as short/tall as they want

### Minimum Width Calculation

```c
// Minimum width = board width (guard rails)
#define MIN_WINDOW_WIDTH BOARD_WIDTH  // 602px with current grid

// Or with side panels in editor:
#define MIN_WINDOW_WIDTH_EDITOR (BOARD_WIDTH + 2 * PANEL_WIDTH)
```

## Implementation

### Detecting Window Manager Type

Tiled window managers typically set specific window properties or resize windows programmatically. Detection approaches:

```c
// Option 1: Check if window was resized externally (not by user drag)
// Tiled WMs resize instantly, user drag is gradual
int was_external_resize(void) {
    // If resize happened without mouse button down, it's external
    return !IsMouseButtonDown(MOUSE_LEFT_BUTTON);
}

// Option 2: Check X11 window properties (Linux-specific)
// Tiled WMs often set _NET_WM_STATE or similar hints

// Option 3: Just allow any resize that makes window smaller than min
// but immediately resize back up in windowed mode
// Tiled WM resizes won't trigger the callback the same way
```

### Raylib Window Size Handling

```c
void handle_window_resize(void) {
    int width = GetScreenWidth();
    int height = GetScreenHeight();

    // Check if this is a tiled WM resize (external)
    if (was_external_resize()) {
        // Trust the WM, don't fight it
        return;
    }

    // Windowed mode: enforce minimum width
    if (width < MIN_WINDOW_WIDTH) {
        SetWindowSize(MIN_WINDOW_WIDTH, height);
    }
}
```

### Alternative: SetWindowMinSize

Raylib provides `SetWindowMinSize()` which may work for standard windowed mode:

```c
void init_window(void) {
    InitWindow(DEFAULT_WIDTH, DEFAULT_HEIGHT, "Physics Sim");
    SetWindowMinSize(MIN_WINDOW_WIDTH, 100);  // Min width, allow any height
}
```

Note: This may conflict with tiled WMs. Need to test behavior.

## Files to Modify

- `src/001-main.c` - Add minimum size enforcement
- `src/030-editor-main.c` - Same for editor with panel width included

## Edge Cases

### Tiled WM Detection
- i3, sway, bspwm, dwm, etc. all behave differently
- Some set window hints, some don't
- May need to just accept any externally-triggered resize

### Multi-Monitor
- User might have small secondary monitor
- Should still allow tiled WM to place window there

### Startup Size
- If saved window size is below minimum, use minimum
- Or use default size on first launch

## Notes

- Height has no minimum - very short windows are fine (just clips the board)
- This primarily protects against accidental resize making game unplayable
- Tiled WM users are power users who can handle edge cases
