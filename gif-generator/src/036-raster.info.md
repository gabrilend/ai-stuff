# 036-raster — the painter

Draws one moment of a shape film through the view it is handed: depth
buffer, banded lighting, glowing edges, 2x2 smoothing, soft blobs. Knows
shapes and a view, not scenes. Its output is palette indices for the
encoder in `004-gif.lua`.

## Usable surface

- **new(size, camera, meshes) → canvas**, **set_view(canvas, view)**,
  **clear(canvas)**
- **draw_stars / draw_item / draw_stroke / draw_blobs (canvas, ...)**
- **project_point(canvas, x, y, z) → fx, fy, depth** — the projection the
  framing test reuses.
- **finish(canvas, index_of) → uint8 indices**

Details in `039-shape-films.info.md`, under "The parts".

- **SUPERSAMPLE, NEAR, view_basis(canvas)** — the painter's measures, exposed for the frame composer (`052-frame.lua`), which lays panes of light into this canvas's depth.
