# libs/see-in-3d-render.lua — info

A software renderer for see-in-3d models (issue A08). No graphics card, no
library.

| | |
|---|---|
| `M.views` | the four cameras in sheet order: `{ name, label, azimuth, elevation }` (degrees; azimuth 0 = front, 90 = right; elevation 90 = above) |
| `M.render(model, view, size)` | one view: a string of size×size RGB bytes, rows from the top |
| `M.sheet(rendered, size)` | four views (in `M.views` order) as a 2size×2size sheet, labelled, with dividing lines |

How: the camera looks at the middle of everything (floor included) from far
enough to fit it, 40° field of view. A chequered floor at height 0 (or under
the lowest shape) is found per pixel by following the ray down. Triangles fill
a depth buffer (nearest wins, depth as 1/distance). One light from above-left;
both sides of a face lit alike; glowing faces unshaded. Buffers are flat
arrays allocated once per view.
