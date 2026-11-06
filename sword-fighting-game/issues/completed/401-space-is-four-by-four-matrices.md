# 401 — Space Is Four By Four Matrices

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | none |
| Blocks | 402, 405, 406 |
| Files | `src/021-matrix.lua` |
| Reads | `docs/datapath-rendering.md` |

## Current behavior

Built in `src/021-matrix.lua`, plus a matrix that stretches a unit shape
between two points (arms, blades, darts). Tested in tests/034-seeing-it.lua.

## Intended behavior

Plain 4×4 matrices stored as flat arrays of 16 numbers in row-major order
(row 1 is entries 1..4), sent to the shader with the engine's "row" layout.
Operations: identity, multiply, translate, scale, rotate about the vertical
axis and about the sideways axis, perspective (vertical field of view, aspect,
near, far — OpenGL clip space), and look-at (eye, target, up).

World axes, fixed for the whole project: **x east, y up, z south.** A field
cell (cx, cy) has its centre at world (cx + 0.5, 0, cy + 0.5) in cell units;
one cell is 1.2 m, and the view scales a figure by that.

The 90 degree field of view the vision asks for is horizontal; the vertical
field of view is derived from it and the window's aspect.

## Suggested implementation steps

1. Write the operations, allocating once per call (the view does not run in
   the simulation's tick).
2. Test: perspective of a point on the centre line lands at the screen
   centre; look-at maps the target onto the forward axis; horizontal 90
   degrees puts a point at 45 degrees on the screen edge.
