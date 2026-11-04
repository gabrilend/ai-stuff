# 211 — Formula voxel effects

**Phase:** 2 — Glass and metal
**Blocked by:** 209, 201

**Blocks**: 208
**Related documents:** docs/visual-language.md (The map: models and voxels),
docs/datapath-glass-and-metal.md (voxel effect)

## Current Behavior

There are no effects.

## Intended Behavior

- Auras, shield domes, courier sparks and magic are clouds of very small
  voxels (tiny cubes). Each voxel's position, size and color come from a
  formula of (time, strength, seed); no hand-placed particles.
- Effects are drawn only when the seat looking has sight of them (assumed fog
  of war; see open question 6).
- From far away an effect keeps a minimum saturation and coverage, so an aura
  reads as a colored haze instead of vanishing into single pixels.
- Drawn with instancing; the voxel count per effect scales with on-screen
  size.

## Suggested Implementation Steps

1. `src/NNN-voxel-formulas.lua`: a dispatch table of named formulas (aura,
   dome, spark, burst), pure functions (data generation).
2. `src/NNN-voxel-drawing.lua`: instanced cubes, far-distance saturation
   floor (viewing).
3. Tests: the same seed and time give the same voxels; an effect with no
   sight is not drawn.

## Open questions

- "Hidden when not directly in view of an opponent" — fog of war, or the
  reverse? (Open question 6.)
