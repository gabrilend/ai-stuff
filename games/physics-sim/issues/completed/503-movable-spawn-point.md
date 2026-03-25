# Issue 801: Movable Spawn Point

## Current Behavior

The spawn point is fixed at SPAWN_X (400) and SPAWN_Y (50), defined as constants
in src/006-ball.h. Balls always spawn at the same horizontal position.

## Intended Behavior

Allow the user to move the spawn point horizontally:
1. Mouse movement snaps spawn point to mouse X position (clamped to table bounds)
2. Left/right arrow keys nudge spawn point horizontally
3. Mouse takes priority - any mouse movement overrides keyboard position
4. Spawn point visual (pulsing circle) updates to show current position
5. Vertical position (Y) remains fixed

## Suggested Implementation Steps

1. Convert SPAWN_X constant to a variable `spawn_x` in main.c
2. Track mouse position each frame with GetMouseX()
3. Clamp spawn_x to table bounds (world->table_x to world->table_x + table_width)
4. Add arrow key handling (KEY_LEFT, KEY_RIGHT) for nudge movement
5. On any mouse movement, snap spawn_x to clamped mouse position
6. Update spawn visual and spawn calls to use spawn_x variable
7. Update spawn blocking check to use spawn_x

## Design Notes

Nudge speed: ~5-10 pixels per frame or scaled by dt
Mouse priority: Set spawn_x = mouse_x whenever mouse moves
Bounds: Keep spawn_x within table rails (world->table_x + margin to
        world->table_x + table_width - margin)

## Success Criteria

- Spawn point follows mouse horizontally
- Arrow keys nudge spawn point when mouse not moving
- Spawn point stays within table bounds
- Visual indicator shows current spawn position
- Balls spawn at selected position
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Added movable spawn point system (src/001-main.c:152-196).

Variables added:
- `spawn_x`: Current spawn position (starts at SPAWN_X center)
- `spawn_nudge_speed`: 200 pixels/second for keyboard movement
- `last_mouse_x`: Tracks mouse to detect movement

Movement logic:
- If mouse moved: snap spawn_x to mouse X position
- Else: check arrow keys for nudge (LEFT/RIGHT)
- Clamp to table bounds with margin for ball radius

Updated spawn calls and visuals to use spawn_x variable.
Console message added to explain controls.
