# 410 - Reticle Toggle Mouse Control

## Current Behavior

The reticle (spawn point indicator) continuously tracks the mouse position:

```c
// src/001-main.c:233-249
Vector2 mouse_screen = { (float)GetMouseX(), (float)GetMouseY() };
Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);
int current_mouse_x = (int)mouse_world.x;
if (current_mouse_x != last_mouse_x) {
    // Mouse moved - snap spawn_x to mouse world position (clamped)
    spawn_x = mouse_world.x;
    last_mouse_x = current_mouse_x;
} else {
    // No mouse movement - check arrow keys for nudge
    if (IsKeyDown(KEY_LEFT)) {
        spawn_x -= spawn_nudge_speed * dt;
    }
    if (IsKeyDown(KEY_RIGHT)) {
        spawn_x += spawn_nudge_speed * dt;
    }
}
```

Problems:
- Reticle always follows mouse, which can be distracting
- Arrow keys only work when mouse is stationary (else branch)
- No way to "lock" the reticle position while still moving the mouse

## Intended Behavior

Toggle-based mouse control for the reticle:

1. **Default state:** Reticle starts centered (SPAWN_X = 400.0f) and frozen
2. **Click to enable:** Left mouse click enables mouse tracking - reticle follows mouse
3. **Click to disable:** Another click freezes reticle at current position
4. **Arrow keys always work:** Arrow key nudging operates independently of toggle state

This gives the player deliberate control over when the reticle moves, preventing accidental repositioning while still allowing quick mouse-based aiming when desired.

## Suggested Implementation Steps

### Step 1: Add toggle state variable

Near the spawn_x initialization in main():

```c
float spawn_x = SPAWN_X;  // Start at center (movable)
int mouse_controls_reticle = 0;  // 0 = frozen, 1 = follows mouse
```

### Step 2: Handle click to toggle

Before the mouse tracking logic, check for left click:

```c
if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
    mouse_controls_reticle = !mouse_controls_reticle;
}
```

### Step 3: Refactor mouse/arrow key logic

Replace the current if-else structure with:

```c
// Mouse tracking (only when enabled)
if (mouse_controls_reticle) {
    Vector2 mouse_screen = { (float)GetMouseX(), (float)GetMouseY() };
    Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);
    spawn_x = mouse_world.x;
}

// Arrow keys always work (independent of mouse toggle)
if (IsKeyDown(KEY_LEFT)) {
    spawn_x -= spawn_nudge_speed * dt;
}
if (IsKeyDown(KEY_RIGHT)) {
    spawn_x += spawn_nudge_speed * dt;
}
```

### Step 4: Remove stale tracking variable

The `last_mouse_x` variable is no longer needed for the mouse-movement detection logic. It can be removed unless used elsewhere.

### Step 5: Visual feedback (optional)

Consider adding a visual indicator of the toggle state - perhaps a different reticle color or a small icon when mouse control is enabled.

## Files to Modify

- `src/001-main.c` - Main input handling loop

## Testing

1. Launch game - reticle should be centered and not move with mouse
2. Move mouse around - reticle stays put
3. Press arrow keys - reticle moves
4. Click - reticle should now follow mouse
5. Move mouse - reticle tracks mouse position
6. Press arrow keys while moving mouse - both inputs should work
7. Click again - reticle freezes at current position
8. Move mouse - reticle stays frozen
9. Repeat toggle several times to verify state consistency

## Related Issues

- 701-spawn-point-control.md (original spawn point movement implementation)
- 702-arrow-key-nudge.md (arrow key nudging feature)

## Completion Notes

**Status:** Completed

**Implementation:**
1. Added `mouse_controls_reticle` toggle variable (default 0 = frozen)
2. Left click toggles mouse tracking (guarded by menu state)
3. Refactored input: mouse tracking conditional, arrow keys always work
4. Removed `last_mouse_x` variable (no longer needed)
5. Added visual indicator `[MOUSE AIM]` in controls panel when enabled
6. Updated controls panel with "CLICK - Toggle mouse aim" hint
7. Updated console startup message

**Files Changed:**
- `src/001-main.c:197-257` - Input handling refactored
- `src/001-main.c:561-579` - Controls panel updated
