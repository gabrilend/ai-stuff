# 210 — Small 3D models

**Phase:** 2 — Glass and metal
**Blocked by:** 209, 201

**Blocks**: 208
**Related documents:** docs/visual-language.md (The map: models and voxels)

## Current Behavior

Units are dots in the debug view.

## Intended Behavior

- Units and buildings are small, simple, low-polygon 3D models, made by hand
  or generated from code — never AI-generated art.
- Models are stored in a plain format readable without libraries (a Lua table
  of vertices, normals and face colors, or Wavefront OBJ), with the owner's
  color applied to marked faces.
- Drawn with a simple lighting shader that sits with the glass-and-metal
  dashboard (soft key light, metal-tinted ambient).
- Many copies of one model are drawn with instancing.

## Suggested Implementation Steps

1. `src/NNN-model-loader.lua` and a first set of models in `assets/models/`
   (soldier, shield bearer, engineer, hero, factory, outpost), each with a
   line saying who made it and how.
2. `src/NNN-model-drawing.lua`: lighting shader, instancing.
3. Tests: a malformed model file stops loading with the line named.
