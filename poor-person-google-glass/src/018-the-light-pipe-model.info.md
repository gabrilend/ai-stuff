<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 105 (the light pipe in 3D): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 018-the-light-pipe-model

The light pipe's inside, made by formula, as a room to stand in (issue 105). Millimetres, y up, +x forward out of the face; sizes are placeholders.

| Offers | Takes | Gives |
|---|---|---|
| `build()` | | a finished shape record "light-pipe" with 19 parts (contributing facets, recycling facets, facet steps, cladding, back mirror, red and green emitters and beams, tabs, tab hinges, lever motors, levers, three vortex strands, output aperture, store, store slit; beams and strands glow), `stations` (15, each { name, eye, look, fov }) and `filling` |
| `at(s, up, out)` | s 0 (back mirror) .. 1 (output aperture); up and out as shares of the pipe's radius at s | a point {x,y,z} in the pipe |
| `radius_at(s)` | | the pipe's radius at s: constant, then narrowing through the concentrator to a third |
| `recycling_tilt(s, phi)` | | degrees a recycling facet faces backward: 2 to 6 along a spiral |
| `forward(s)` | | the direction light travels at s |

Written to output/models/light-pipe.gltf by scripts/make-light-pipe.
