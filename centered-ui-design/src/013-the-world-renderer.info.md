<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 013-the-world-renderer

The ground (flat map on a folded disc) and the units: one figure mesh (018), instanced from the shared-memory block; each vertex bent by its part of the body plan from the unit's walking phase and ground speed; Blinn-Phong specular, code-drawn skin, a glow on the named unit.

| Offers | Takes |
|---|---|
| `new(settings, camera, fold, unit_count)` | builds shaders, meshes, textures |
| `draw(renderer, front_block, flip_y)` | the front block's byte data, uploaded whole; draws into the current canvas (needs depth) |
| `OWNER_COLORS`, `UNIT_WORLD_SCALE`, `FULL_PACE` | seat paints 1–4 and the foe's color; figure height per unit of record size; the ground speed counted as full stride |
