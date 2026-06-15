# 401 — Movable Point Light System

## Status

TODO — Phase 4 (rendering polish). Not blocking any Phase 1 / 2 / 3
work.

## Current behavior

Terrain shading is a single static directional "sun" baked into
vertex colors at mesh-build time (`src/020-terrain.c`,
`light_bake()`). The sun direction is hardcoded at
`(0.4, 0.5, 0.8)`. Nothing in the world has dynamic lighting; if
the sun moved, the terrain would have to be rebuilt and re-uploaded
every frame, which is too expensive.

raylib's default shader is unlit — it samples vertex color and a
texture, multiplies them, and writes the result. Per-fragment
lighting therefore requires a custom shader.

## Intended behavior

A movable **point light** can be placed in the world. The light has
a position (X, Y, Z), a color, and a radius (or an attenuation
falloff). The terrain — and any other lit geometry the project
introduces later — receives this light's contribution at render time,
falling off with distance.

Interaction:

- A small visible marker (e.g. a glowing sphere or a wireframe
  diamond) renders at the light's position so the user can see
  where it is.
- The user can drag the light around on the X/Y plane (its Z is
  read from `terrain_height_at(x, y)` plus a small offset so it
  hovers just above the ground), reusing the rally-point drag
  pattern from issue 117.
- An optional UI control sets the light color and intensity. A
  fixed default is acceptable for the first cut.

The static sun-bake stays — the point light is *additive* on top of
it. A dark valley with the point light over it should look "lit
from above by something other than the sun"; a sunlit slope with no
point light nearby should look exactly like it does today.

## Suggested implementation steps

1. Add per-vertex normals to the terrain mesh. Today the normal is
   computed and immediately consumed in the bake; for dynamic
   lighting the GPU needs them. Allocate `mesh.normals` in
   `build_mesh` and fill from `normal_at_grid`.
2. Write a custom shader pair (vertex + fragment) under `assets/`:
   - Vertex stage: passes through position, normal (transformed by
     model matrix), and vertex color (which already contains the
     sun-baked component).
   - Fragment stage: starts with the vertex color, adds the
     point light contribution (Lambertian against the light
     direction, scaled by attenuation `1 / (1 + k * d²)` or a
     smoothstep falloff to a fixed radius), and writes the result.
3. Replace the terrain's `LoadMaterialDefault()` with a material
   bound to the new shader.
4. Create `src/040-light.{h,c}` (or fold into `030-camera.c`'s
   neighborhood — the right home depends on whether the light is a
   gameplay or a viewer concern; since the user controls it, lean
   toward a viewer concern).
5. Pass light parameters as shader uniforms each frame: position,
   color, intensity, radius.
6. Add the visible marker render: small unlit sphere or diamond at
   light position.
7. Add the drag interaction. The vision's mechanics doc has
   precedent in rally points (issue 117) — same "click a thing,
   drag in X/Y plane, release to commit" pattern. The light is a
   single global object so no selection scaffolding is needed.

## Related documents

- `docs/004-architecture.md` — module placement.
- `docs/005-roadmap.md` — Phase 4 sits after the gameplay phases.
- `issues/completed/104-heightmap-terrain.md` — explains why
  raylib's default shader is unlit and how the current bake works.

## Notes

This issue exists because the user, after seeing 104's static sun
shading, asked "can we move a point light around?" It is captured
here so the idea is not lost; it is **deliberately deferred** out
of Phase 1 because:

- Phase 1's goal is "basic movement options" — combat, factories,
  rally chains. None of that needs dynamic lighting.
- Adding a custom shader to Phase 1 widens the surface area for
  rendering bugs at exactly the point we want gameplay to be
  observable.
- The vision document does not mention lighting; it explicitly
  values geometric honesty over presentation.

When the time comes to implement, the Phase 1 mechanics doc's
advice still applies: keep the visual presentation honest about
the gameplay state, not flashier than it.

## Phase 4 placeholder

Phase 4 ("rendering polish") does not yet have other issues. This
issue is the seed; future enhancements (dynamic shadows, particles,
post-processing) would land here too. Phase 4 has no prerequisite
beyond the gameplay phases being complete enough that polish is
the obvious next move.

## Task pool integration

The light's *render* contribution lives on the main / render
thread (shader uniforms set per-frame in the render path, no
threading concern). The light's *interactive drag* mirrors the
rally-point drag in issue 117 and inherits its priority shape:

**Live drag visual update — priority 6.** Each drag event spawns
a short task to update the light's position in the snapshot the
renderer reads from.

**Commit on release — priority 3.** Standard input-handler
priority.

If Phase 4 grows particle systems, those would be the natural
heir of the projectile-arc-update pattern (priority 1 if
gameplay-relevant, priority 7-9 if purely cosmetic). Particles are
the textbook self-rescheduling-task use case.
