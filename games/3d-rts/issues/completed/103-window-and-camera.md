# 103 — Window & 3D Camera

## Status

DONE — completed 2026-04-27.

## Current behavior

The window from 101/102 renders a 2D placeholder. There is no 3D camera
and no way to look around the world.

## Intended behavior

A `Camera3D` looks down at the world from a slightly tilted angle,
similar to a typical RTS camera. The user can:

- Pan with WASD or middle-mouse drag.
- Zoom in and out with the scroll wheel.
- Rotate yaw with Q / E.

The camera state lives in `src/030-camera.c`. The render loop calls
`BeginMode3D(camera) ... EndMode3D()` so subsequent issues can render
3D content without re-engineering the framing.

The world coordinate convention is **Z-up**: X and Y are the
horizontal plane, Z is height. This matches the vision document's
language ("the point those X/Y values intersect with the terrain on
the Z axis"). raylib's Camera3D supports arbitrary up-vectors; setting
`up = (0, 0, 1)` makes the rest of raylib's 3D primitives render
correctly under this convention.

## Suggested implementation steps

1. Create `src/030-camera.c` / `.h` exposing `camera_init()`,
   `camera_update(dt)`, and `camera_get()`.
2. Initialize position high enough to see a 64×64 tile world (default
   distance 50, tilt ~54° from horizontal).
3. Implement WASD pan in the camera-local forward/right directions on
   the X/Y plane.
4. Implement scroll-wheel zoom by adjusting distance with an
   exponential factor so each click is a uniform proportional change.
5. Implement Q / E yaw rotation around the focus point.
6. Implement middle-mouse drag pan.
7. Update `src/001-main.c` to call `camera_update(GetFrameTime())` and
   wrap world rendering in `BeginMode3D` / `EndMode3D`.
8. Add a small placeholder 3D scene (ground grid + colored axis-marker
   cubes) so the camera has visible content to test against. This
   placeholder is scaffolding; it goes away in issues 104 (terrain)
   and 106 (units).

## Related documents

- `docs/004-architecture.md` — `030-camera.c` placement.
- `docs/balance-updates.md` — input feel tweaks landed during testing.

## Notes

Camera control is owned by the main thread, not the sim thread — it is
purely a viewer concern and never affects gameplay. Resist the urge to
push it through the snapshot pathway. The reason is that camera
updates should run at render rate, not at tick rate.

## Completion log

### What was implemented

- `src/030-camera.h` / `.c` — singleton camera with target / yaw /
  pitch / distance state, recomputed into a raylib `Camera3D` each
  frame. Functions wrapped in vimfolds per mono-repo convention.
- WASD pan, middle-mouse drag pan, scroll-wheel zoom, Q / E yaw.
- Pan and drag speeds scale with current zoom so the same input
  feels right at any distance.
- Placeholder 3D scene in `src/001-main.c`: a grid in the X/Y plane
  with the X=0 / Y=0 lines drawn darker, and a handful of colored
  axis-marker cubes (gray origin, red +X, green +Y, blue +Z, plus
  three larger spread-out markers for pan visibility).
- Window resized from 800×600 to 1024×768 to give the 3D scene more
  real estate.

### What was tested

- Visual confirmation by the user that the camera opens correctly,
  shows the placeholder grid and markers, and exits cleanly on
  window close.
- WASD pan, Q/E yaw, scroll-wheel zoom all confirmed felt-correct.
- Middle-mouse drag pan went through two rounds of input-feel
  adjustment before settling on `apply_pan(d.y, -d.x)`. The full
  log lives in `docs/balance-updates.md`.

### What was not tested

- Behavior at extreme zoom (the min/max distance clamps work but
  haven't been exercised at the boundaries by hand).
- Pitch adjustment — the camera tilt is fixed at the initial value;
  the issue did not call for a runtime tilt control and one was not
  added. If a future issue wants this it should be a small tweak,
  not a redesign.
- Camera under heavy frame-time variance — the scaling of pan / yaw
  by `dt` is straightforward, but a stutter-test wasn't run.

## Task pool integration (added retroactively)

**Not applicable.** Camera is main-thread-only, runs at render
rate, owned by viewer code. Any task-pool involvement here would
violate the architectural rule that the camera doesn't go through
the snapshot pathway.

The one mild exception: issue 108 (selection) wants the camera
state at the moment of a `SELECT_RECT` event for screen-to-world
projection on the sim side. That copy travels in the event
payload, not through any task. Camera lifecycle stays untouched.

### Lessons & caveats for later issues

- Z-up is now established as the world convention. Issue 104
  (terrain) inherits this directly: the heightmap stores Z values
  over an X/Y grid, not Y values over an X/Z grid. raylib's
  `GenMeshHeightmap` assumes Y-up internally, so terrain mesh
  generation should be hand-rolled rather than reusing that helper —
  noted here so 104 doesn't relearn it.
- raylib's `DrawGrid` is X/Z-plane only and so is **not** what we
  want; the hand-rolled `draw_ground_grid` in `001-main.c` is the
  right pattern for any future debug grid.
- The placeholder scaffolding (`draw_ground_grid` and
  `draw_axis_markers`) in `001-main.c` is explicitly temporary.
  Issue 104 removes the grid in favor of the heightmap mesh; issue
  106 removes the axis markers in favor of real units.
