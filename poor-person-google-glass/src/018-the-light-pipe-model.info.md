<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 105 (the light pipe in 3D): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 018-the-light-pipe-model

The light pipe's inside, made by formula, as a room to stand in (issue 105). Millimetres, y up, +x forward out of the face; sizes are placeholders.

| Offers | Takes | Gives |
|---|---|---|
| `build()` | | a finished shape record "light-pipe" with 14 parts (wall, wall ridges, back mirror, red and green emitters and beams, tabs, tab hinges, lever motors, levers, light vortex, store, aperture), `stations` (12, each { name, eye {x,y,z}, look {x,y,z} }) and `filling` ({ colour {r,g,b}, density }) |
| `at(s, up, out)` | s 0 (back mirror) .. 1 (store); up and out as shares of the pipe's radius | a point {x,y,z} in the pipe |
| `forward(s)` | | the direction light travels at s |

Written to output/models/light-pipe.gltf by scripts/make-light-pipe.
