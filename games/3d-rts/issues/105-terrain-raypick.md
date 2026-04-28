# 105 — Terrain Ray-Pick

## Status

TODO

## Current behavior

The mouse position is in screen space only. There is no way to translate
a click into a world point on the terrain.

## Intended behavior

A function `terrain_pick(camera, mouse_x, mouse_y) -> Vector3` returns
the world-space point where the ray from the camera through the cursor
intersects the terrain heightmap. If the ray does not intersect, the
function returns a sentinel that callers must check for (an explicit
"miss" return code, *not* a NaN or a magic vector).

A small visual aid: when no UI element is hovered, a small marker is
drawn at the picked terrain point each frame. This makes the picking
function visibly correct.

## Suggested implementation steps

1. Add `terrain_pick` to `src/020-terrain.c` / `.h`.
2. Get the world-space ray from the camera using raylib's `GetMouseRay`.
3. March the ray in steps starting near the camera, sampling
   `terrain_height_at(x, y)` at each step.
4. When the ray's Z drops below the terrain Z, refine with binary
   search between the last two samples.
5. Return both the hit point and a boolean for "did hit".
6. Wire up a debug marker rendered at the picked point each frame,
   gated by a debug flag in `src/010-config.h`.

## Related documents

- `docs/002-mechanics.md` — terrain rules.
- `docs/004-architecture.md` — module placement.

## Notes

Picking is a read-only query against the immutable terrain array, so it
runs on the main thread without locks. It is used by selection
(issue 108), move orders (issue 109), factory placement (issue 115),
and rally point dragging (issues 116/117). Keep the return type
designed for those callers.
