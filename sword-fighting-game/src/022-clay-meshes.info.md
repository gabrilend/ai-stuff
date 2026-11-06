<!-- made by scripts/build-info-pages from the comments in 022-clay-meshes.lua; change the comments and rebuild, not this page -->
# 022-clay-meshes


The shapes everything is pressed from, as plain vertex data: lists of
triangles whose vertices are rows { x, y, z, nx, ny, nz }. No engine call
is made here, so the shapes can be built and checked without a window.

Each shape is unit-sized and centred, built once at start-up, and drawn at
any size and place by its model matrix:

  blob      a sphere of radius 1: clay heads, bodies, limbs, stones, clouds
  box       a cube from -1 to 1: blades, fences, the ground
  brick     a box with four studs on top: armor plates
  cylinder  radius 1, height -1..1: studs, pommels, shields, puddles

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.blob` | `rings, segments` | Latitude rings by longitude segments; the normal of a unit sphere is its position. |
| `M.box` | nothing | (no comment in the source) |
| `M.cylinder` | `segments` | (no comment in the source) |
| `M.brick` | nothing | A box with a two-by-two grid of studs on its top face, the way the bricks in the vision's armor are made. |
| `M.all` | nothing | Every shape, by name, built once. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `FACES` | The six faces of a cube: the normal, then two axes spanning the face. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `push` | `out, x, y, z, nx, ny, nz` | (no comment in the source) |
| `add_box` | `out, cx, cy, cz, hx, hy, hz` | A box centred at (cx, cy, cz) with half-sizes (hx, hy, hz). |
| `add_cylinder` | `out, cx, cy, cz, r, h, segments` | (no comment in the source) |
