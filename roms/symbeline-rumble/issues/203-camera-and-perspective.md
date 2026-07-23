# 203 — Camera and perspective

**Phase:** 2
**Blocked by:** 201 (camera_t typedef), 202 (viewport setup).
**Blocks:** 207, 208, 209.

## Current behavior

There is no notion of a camera. The render seam declares `camera_t`
(from issue 201) but no scene assigns one or submits it.

## Intended behavior

A scene declares a `camera_t` per frame. The platform layer translates
the camera into the view+projection matrices its 3D engine expects:

- **Position and target** in `fxw_t` world coordinates.
- **Up vector** (default `(0, 1, 0)` since the world is vertical-leaning).
- **Vertical FOV** in `fxa_t` turns (default 12°/360° ≈ a narrow
  perspective consistent with the tilt-shift miniature aesthetic).
- **Near and far** clip planes in `fxw_t`.

The camera is positioned high and tilted slightly downward, looking
along the vertical extent of the half-map. The framing has the visible
play area occupying the central band; ground extends into blur above
and below.

### libnds interop

On NDS, `glMatrixMode(GL_PROJECTION)` + `glPerspectivef32(fov, aspect,
near, far)` consume Q20.12 directly. View matrix is built from the
camera position/target/up using `gluLookAt`-equivalent math
implemented from our fixed-point trig.

### Native

raylib's `BeginMode3D(camera)` accepts a `Camera3D` struct in floats.
We convert at the platform seam (the *only* sanctioned float
conversion outside the asset pipeline).

## Suggested implementation steps

1. Define `camera_t` in `src/03-render-types.h`.
2. Author `src/05-camera.h` and `.c` with helpers: build view matrix
   from camera; build projection matrix from camera; clamp camera to
   sensible bounds.
3. NDS platform: implement `platform_render_set_camera` using libnds
   matrix-stack APIs.
4. Native platform: implement `platform_render_set_camera` by
   constructing a raylib `Camera3D` and calling `BeginMode3D`.
5. Test fixture: a simple scene with three cubes at known world
   positions. The camera frames them in the sharp band. Compare
   screenshot from each target — same composition, allowing
   resolution differences.

## Deliverable artifacts

- `src/05-camera.h`, `src/05-camera.c`, `src/05-camera.info.md`.
- NDS and native `platform_render_set_camera` impls.
- `tests/05-camera-framing.c` (cross-target screenshot fixture).

## Related documents

- `docs/006-art-direction.md` — vertical extent, sharp band, miniature
  aesthetic.
- `docs/008-fixed-point-math.md` — `fxw_t` for world coords, `fxa_t`
  for angles, fixed-point trig.
