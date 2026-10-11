<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 013-the-world-renderer

The ground (earth with the flat map and sections on a folded disc), the units (one figure mesh, instanced from shared memory, limbs bent by the body plan, arms in the holding pose when carrying), and the cuboids (a sphere pushed toward a cube, glazed). No light direction anywhere: each surface looks its light up on its material's light dial (metal, glaze, earth) through a window, by which way it faces the viewer; the dials turn with the hour (issue 213). Under the hub camera far things fade into haze; figures stand upright or, to compare, lean away from the hub (issue 214).

| Offers | Takes |
|---|---|
| `new(settings, camera, fold, unit_count, cuboid_count, sections)` | builds shaders, meshes, textures, the three light dials |
| `draw(renderer, front_units, front_cuboids, flip_y, look)` | the two front blocks' byte data; `look`: hour_angle (0 noon), standing ("upright"/"outward") |
| `OWNER_COLORS`, `UNIT_WORLD_SCALE`, `FULL_PACE`, `CUBOID_ROUNDNESS`, `WINDOW_CENTER`, `WINDOW_RADIUS`, `HAZE_COLOR`, `OUTWARD_LEAN` | tuning knobs |

`set_terrain(renderer, points)`: hands it the land's points (026's `build`); drawn as flat circles facing the camera, each only turned toward the sun (no lighting on its pixels), nearest first, ordered by distance from the centre (`look.ground == "dots"`), or the painted map instead (`"map"`). Knob: `DOT_SIZE`.
