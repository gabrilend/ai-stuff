# 1009 — Modeller UI: perspective view and inspector

## Current behavior

The modeller's data (vertices, faces, properties) exists but
has no on-screen representation. The user has nothing to look
at.

## Intended behavior

The modeller's two surfaces:

- **Top screen — perspective view.** A 3D rendering of the
  current model from the user's chosen viewpoint. The view
  shows: placed vertices as small dots, the cursor as a bright
  cross, edges of faces as lines, faces themselves as filled
  polygons (in their color, with the roughness affecting how
  the simple shading model paints them). The right stick X
  rotates the view's yaw; Y of the right stick is reserved for
  cursor Y, so the view's pitch lives on a drawer option that
  takes over Y temporarily.
- **Bottom screen — inspector.** A panel that shows the
  currently-relevant object's properties. When the cursor is
  on an empty cell: "empty cell at (x, y, z); A to place". When
  on a vertex: "vertex at (x, y, z); part of N faces; A to
  remove". When a face is highlighted: "triangle/quad with
  these N vertices; color=color, roughness=value; properties
  drawer to edit".

The perspective view uses a simple software renderer: project
3D vertices to 2D screen positions, rasterize triangle and
quad faces with flat shading derived from each face's color
and normal, draw edges as bright lines. Hidden-surface
elimination uses a per-pixel depth buffer the size of the
screen — small enough to fit in the per-app region.

The rendering happens once per frame on the modeller's per-app
queue. With a few hundred vertices the per-frame cost is well
inside the 60Hz budget.

## Suggested implementation steps

1. `perspective_render_box()` — the software renderer.
2. `inspector_render_box()` — the bottom-screen panel.
3. Depth buffer allocation from per-app memory.
4. Yaw rotation on right stick X; pitch on a drawer option.

## Related documents

- `docs/010-modeller.md`.
- `docs/005-display-and-compositor.md`.

## Blocked by

601, 603, 1001, 1002, 1003, 1004.

## Blocks

1010, 1011.
