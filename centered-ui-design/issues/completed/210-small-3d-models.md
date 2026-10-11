# 210 — Small 3D models: units with bodies, arms and legs

**Phase:** 2 — Glass and metal
**Blocked by:** 209, 201

**Blocks**: 208
**Related documents:** docs/visual-language.md (The map: models and voxels),
docs/core-terms.md (figure, walking phase)
**Completed:** 2026-10-10 (first as single spheroids; reopened the same day
and completed again with bodies, arms and legs)

## Current Behavior

Built. Every unit is a small figure of six spheroids — body, head, two arms,
two legs — from one mesh built once at start, each vertex tagged with its
part. A body plan (data) places and sizes each part in figure heights. Each
unit is one instance, its data read straight from the shared-memory records:
place, heading, size, girth, walking phase, speeds. In the vertex shader each
part is bent by the body plan: a limb's points are pushed forward and lifted
by an amount growing with the square of their distance from the shoulder or
hip, so the limb deforms along a curve and its attachment never moves; the
surface's facing is corrected by the bend's exact slope. Legs swing in
opposite phase, each arm opposite its leg, the body bobs, and a standing unit
sways its arms. The move box turns each unit's walking phase by the ground it
covers (one cycle per stride, shorter far out where figures are smaller).
The mesh never changes: the formula's input does. The skin is drawn by code;
lighting is diffuse, metal ambient, a Blinn-Phong glint, a rim light, and a
glow on the named unit. Checked by screenshot (default view and close-ups:
bent legs visible) and by tests.

## Intended Behavior

- Units are figures built only from spheroids (no model files, never
  AI-generated art).
- One mesh, built once, drawn once per unit as an instance from the records.
- Limbs deform, not rotate; the motion comes from updating the formula's
  input (the walking phase), never from rebuilding the shape.
- Texture-mapped skin made by code; owner color from the record; specular
  metal; figures shrink with the fold far out.

## Implementation Steps (as built)

1. `src/018-the-body-plan.lua`: the parts table; the figure mesh (six unit
   spheres turned poles-up, part number per vertex); the bend in Lua (for
   tests) and in GLSL (`bend_part`, with the shear's normal correction);
   sending the plan to the shader as arrays.
2. `src/006-the-move-box.lua`: the walking phase turned by ground speed over
   a stride (`STRIDE_WORLD_UNITS`), plus an idle turn.
3. `src/004-the-sphere-fold.lua`: the fold's slope in GLSL, so the shader
   knows each unit's ground speed (how much it is walking).
4. `src/013-the-world-renderer.lua`: the figure mesh with its part attribute;
   the unit shader (ground speed → walking amount, bend, turn, place,
   project); `UNIT_WORLD_SCALE`, `FULL_PACE`.
5. `src/011-the-spheroid.lua` and `src/012-made-by-formula.lua`: the unit
   sphere and the skin, unchanged.
6. Tests: six parts on unit spheres; the bend keeps the hip fixed and moves
   the foot exactly stride × length forward and lift × length up; on the
   back swing the foot goes back and does not lift; the phase turns faster
   at higher speed.

## Decisions

- Owner colors are looked up in the vertex shader and passed on, because
  older shader versions only promise array lookups by a varying index there.
- The figure height scale was raised twice by eye (docs/balance-updates.md).
- Buildings may later be hand-made models in a plain format; that belongs to
  the factory issues.
