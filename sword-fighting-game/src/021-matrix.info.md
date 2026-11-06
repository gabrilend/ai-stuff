<!-- made by scripts/build-info-pages from the comments in 021-matrix.lua; change the comments and rebuild, not this page -->
# 021-matrix


Four-by-four matrices: how a point in the world becomes a point on the
screen. A matrix is a flat array of 16 numbers in row-major order (entries
1-4 are the first row) and is sent to the shader with the engine's "row"
layout, so the arithmetic here reads the way it is written on paper.

World axes, fixed for the whole project: x east, y up, z south, in metres.
A map point (mx, my) in cells is world (mx * cell, ?, my * cell).

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.identity` | nothing | (no comment in the source) |
| `M.multiply` | `a, b` | a * b: apply b first, then a. |
| `M.translate` | `x, y, z` | (no comment in the source) |
| `M.scale` | `x, y, z` | (no comment in the source) |
| `M.rotate_y` | `a` | About the vertical axis. A figure facing map angle f is turned by -f, so its local +x (forward) points along (cos f, sin f) on the map. |
| `M.rotate_z` | `a` | About the local sideways axis: tips forward-and-up, as a leg swings. |
| `M.rotate_x` | `a` | (no comment in the source) |
| `M.perspective` | `fovy, aspect, near, far` | OpenGL clip space: the vertical field of view in radians. |
| `M.vertical_fov` | `horizontal, aspect` | The vertical field of view that gives a horizontal one at this aspect: the vision's 90 degrees is across the screen. |
| `M.look_at` | `ex, ey, ez, tx, ty, tz` | (no comment in the source) |
| `M.apply` | `m, x, y, z` | The matrix times the point (x, y, z, 1): returns x, y, z, w. |
| `M.along` | `ax, ay, az, bx, by, bz, r` | A matrix that stretches a unit shape (spanning -1..1 on its y axis) from point a to point b, with radius r across: arms, blades, darts. Returns the matrix and the scale it used, which the renderer needs for normals. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `normalize3` | `x, y, z` | (no comment in the source) |
| `cross` | `ax, ay, az, bx, by, bz` | (no comment in the source) |
