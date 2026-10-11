<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 013-the-world-renderer

The ground (flat map on a folded disc) and the units (one spheroid, instanced from the shared-memory block, Blinn-Phong specular, texture-mapped skin, a glow on the named unit).

| Offers | Takes |
|---|---|
| `new(settings, camera, fold, unit_count)` | builds shaders, meshes, textures |
| `draw(renderer, front_block, flip_y)` | the front block's byte data, uploaded whole; draws into the current canvas (needs depth) |
| `OWNER_COLORS`, `UNIT_WORLD_SCALE` | seat paints 1–4 and the foe's color; unit size factor |
