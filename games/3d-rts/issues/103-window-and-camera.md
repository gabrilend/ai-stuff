# 103 — Window & 3D Camera

## Status

TODO

## Current behavior

The window from 101/102 renders a 2D placeholder. There is no 3D camera
and no way to look around the world.

## Intended behavior

A `Camera3D` looks down at the world from a slightly tilted angle,
similar to a typical RTS camera. The user can:

- Pan with WASD or middle-mouse drag.
- Zoom in and out with the scroll wheel.
- Optionally rotate yaw with a held key (Q/E or middle-mouse + modifier).

The camera state lives in `src/030-camera.c`. The render loop calls
`BeginMode3D(camera) ... EndMode3D()` so subsequent issues can render
3D content without re-engineering the framing.

## Suggested implementation steps

1. Create `src/030-camera.c` / `.h` exposing a singleton
   `camera_get()`/`camera_update(dt)`.
2. Initialize position high enough to see a 64×64 tile world.
3. Implement WASD pan in the camera's local X/Y plane.
4. Implement scroll-wheel zoom by adjusting the camera's distance/height.
5. Optional: yaw rotation around the focus point.
6. Update `src/001-main.c` to call `camera_update(GetFrameTime())` and
   wrap world rendering in `BeginMode3D` / `EndMode3D`.

## Related documents

- `docs/004-architecture.md` — `030-camera.c` placement.

## Notes

Camera control is owned by the main thread, not the sim thread — it is
purely a viewer concern and never affects gameplay. Resist the urge to
push it through the snapshot pathway. The reason is that camera updates
should run at render rate, not at tick rate.
