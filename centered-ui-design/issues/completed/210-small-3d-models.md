# 210 — Small 3D models: spheroid units

**Phase:** 2 — Glass and metal
**Blocked by:** 209, 201

**Blocks**: 208
**Related documents:** docs/visual-language.md (The map: models and voxels)
**Completed:** 2026-10-10

## Current Behavior

Built. Every unit is an oblong spheroid: one unit sphere of 20 rings × 32
segments is built at start, and each unit draws it as an instance, stretched
by its own length and width, turned to its heading, lifted to rest on the
folded ground with a slight idle bob, and shrunk by the fold the further out
it stands. The per-unit data is the shared-memory front block itself,
uploaded whole each frame. The skin is drawn by code (metal panels, seams,
rivets, brushed grain, and a band showing the owner's color); lighting is a
soft diffuse term, a metal-tinted ambient, a Blinn-Phong specular glint, a
cool rim light, and a bright glow on the named unit.

## Intended Behavior

- Units are oblong spheroids: one formula gives surface and shading, so no
  model files are needed for units. Never AI-generated art.
- One mesh, drawn once per unit as an instance from the unit records.
- Texture-mapped skin made by code; owner color from the record.
- Specular highlight reading as polished metal.
- Units sit on the folded ground and shrink with the fold.

## Implementation Steps (as built)

1. `src/011-the-spheroid.lua`: the unit sphere (positions on the sphere with
   z as the long axis, texture coordinates around and along it).
2. `src/012-made-by-formula.lua` (`unit_skin`): red = metal brightness,
   green = where owner color shows.
3. `src/013-the-world-renderer.lua`: the instance mesh in the record's own
   vertex format; the unit shader (stretch, turn, fold, project; ellipsoid
   normals (x/a, y/b, z/c); Blinn-Phong).
4. Tests: every vertex on the unit sphere; texture coordinates span 0–1;
   triangle count matches the grid.

## Decisions

- Owner colors are looked up in the vertex shader and passed on, because
  older shader versions only promise array lookups by a varying index there.
- Buildings may later be hand-made models in a plain format; that belongs to
  the factory issues.
