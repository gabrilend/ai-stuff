# 105 — Terrain Ray-Pick

## Status

DONE — completed 2026-04-27.

## Current behavior

The mouse position is in screen space only. There is no way to
translate a click into a world point on the terrain.

## Intended behavior

A function `terrain_pick(camera, mouse, out)` casts the cursor ray
into the world and finds the world-space point where it intersects
the terrain heightmap. On hit, it fills `*out` with a point on the
surface and returns `true`. On miss (ray points away from the
world), returns `false`. The miss channel is the explicit return
value, not a sentinel value inside `*out`.

A small visual aid: when the cursor is over the world, a marker is
drawn at the picked terrain point each frame. This makes the
picking function visibly correct.

## Suggested implementation steps

1. Add `terrain_pick` to `src/020-terrain.c` / `.h`.
2. Get the world-space ray from the camera using raylib's
   `GetMouseRay`.
3. March the ray in fixed steps starting from the camera, sampling
   `terrain_height_at(x, y)` at each step.
4. When the ray's Z transitions from above terrain to below,
   binary-search between the two samples to refine the crossing.
5. Snap the final Y/Z onto the terrain so the result lies on the
   surface even though bilinear interpolation only converges
   approximately.
6. Return `bool` for hit/miss with the hit point in an out-parameter.
7. Wire up a debug marker rendered at the picked point each frame.
   (A config flag was discussed; `010-config.h` is owned by issue
   102 which is in progress elsewhere — left ungated for now.)

## Related documents

- `docs/002-mechanics.md` — terrain rules.
- `docs/004-architecture.md` — module placement.

## Notes

Picking is a read-only query against the immutable terrain array,
so it runs on the main thread without locks. It is used by
selection (issue 108), move orders (issue 109), factory placement
(issue 116), and rally point dragging (issues 117 / 118). Keep the
return type designed for those callers.

## Completion log

### What was implemented

- `terrain_pick(Camera3D, Vector2, Vector3 *)` in
  `src/020-terrain.{h,c}`.
- Ray-march at 0.5 world-unit steps from the camera, capped at 500
  units (comfortably past the camera's max zoom plus the world's
  diagonal).
- Binary search at 24 iterations on the crossing interval — this
  is overkill for a heightmap of this size but it is essentially
  free and avoids needing to think about precision later.
- Final X/Y from the search, Z snapped to `terrain_height_at(x, y)`
  so the result lies exactly on the surface.
- Debug marker in `src/001-main.c`: a flat wireframe yellow circle
  + a small floating wireframe sphere. Both render only when the
  cursor is over the world.

### What was tested

- Visual: user confirmed the marker tracks the cursor smoothly,
  hugs the terrain on hills and in valleys, and disappears when
  the cursor points off the world.

### What was not tested

- Performance under unusual conditions (very low frame rate, very
  high resolution, very long ray paths). The march is O(distance /
  step), which at 500 / 0.5 = 1000 max samples per frame is
  trivial. If profiling later shows it on the hot path, the easy
  optimizations are: adaptive step size based on ray.z vs current
  terrain.z, and short-circuit on ray pointing upward.
- Numerical edge cases (cursor right at the horizon, camera
  clipping into terrain). The min-distance clamp on the camera
  should keep us out of the second case in practice.

### Lessons & caveats for later issues

- raylib's `DrawCircle3D` draws in the local **X/Y plane** —
  perfect for our Z-up world without rotation. Rotating with a
  90° angle around the X axis (the obvious-looking choice) tips
  the circle onto its edge. This is now documented near the call
  site so 116/117/118's rally markers don't relearn it.
- The pick returns a point exactly on the surface. Callers that
  want to drop a marker visually should add a small Z lift (we
  used 0.05) to avoid z-fighting.
- The march start at `r.position` and step forward works fine even
  when `r.position` is far from any terrain — the cap handles
  that. Callers don't need to constrain the ray themselves.

## Task pool integration (added retroactively)

`terrain_pick` runs on the **main thread on demand** (each frame
when the cursor is over the world, plus per input event). It does
not currently fit the task pool model: it's always called from
input/render code that lives on the main thread, and the call
itself is cheap enough (1000-sample march cap) that handing it
off to a worker would cost more than running it inline.

If a future feature wants to run *many* picks per tick (e.g. a
"check picked points for hundreds of UI cursor anchors") that
would be a slice-batched task at priority 2-3 reading the read-
only heightmap. The function is already safe for concurrent
callers.
