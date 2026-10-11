<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 013-the-world-renderer

The ground (flat map with sections on a folded disc), the units (one figure mesh from 018, instanced from the shared-memory block, limbs bent by the body plan from each unit's walking phase and ground speed, arms in the holding pose when carrying; Blinn-Phong specular, code-drawn skin, a glow on the named unit), and the cuboids (one unit sphere pushed toward a cube in the shader — a superellipsoid with its exact normal — glazed like ceramic).

| Offers | Takes |
|---|---|
| `new(settings, camera, fold, unit_count, cuboid_count, sections)` | builds shaders, meshes, textures |
| `draw(renderer, front_units, front_cuboids, flip_y)` | the two front blocks' byte data, uploaded whole; draws into the current canvas (needs depth) |
| `OWNER_COLORS`, `UNIT_WORLD_SCALE`, `FULL_PACE`, `CUBOID_ROUNDNESS` | seat paints (also the cuboid colors) and the foe's; figure height scale; full-stride ground speed; how square cuboids are |
