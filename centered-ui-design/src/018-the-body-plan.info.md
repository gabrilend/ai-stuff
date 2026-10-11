<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 018-the-body-plan

A unit's figure: six spheroids (body, head, two arms, two legs) in one mesh built once, and the formula that bends the limbs from a walking phase — limbs deform, never swing rigidly.

| Offers | Takes | Gives |
|---|---|---|
| `PARTS` | | list of parts: name, center {x, y, z} and radii {x, y, z} in figure heights, stride, lift, offset (radians), idle, bob |
| `figure_vertices(rings, segments)` | sphere detail | vertices {x, y, z, u, v, part} (six unit spheres, poles up and down) and triangle indices |
| `bend(part, x, y, z, walking_phase, moving, carrying)` | a unit-sphere point, phase, 0..1, 0 or 1 | the bent point in figure heights (the Lua twin of the shader) |
| `send(shader)`, `GLSL` | | the body plan as shader arrays; `bend_part` with the exact normal correction for the shear |
| `BOB_HEIGHT` | | how high each step lifts the upper body |
| `HOLD_FORWARD`, `HOLD_LIFT` | | the holding pose of parts marked `holds` (the arms) while carrying |
