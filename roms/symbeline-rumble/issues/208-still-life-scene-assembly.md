# 208 — Still-life scene assembly

**Phase:** 2
**Blocked by:** 202, 203, 204, 205, 206, 207.
**Blocks:** 209 (the demo plays this scene).

## Current behavior

Phase 2 has all the rendering pieces — viewport split, camera, model
and texture loaders, tilt-shift divergence, sharp-band rule — but no
integrated scene to exercise them.

## Intended behavior

A small static scene representing "a quiet moment in a Symbeline
Rumble world." Contents:

- **Terrain:** a low grassy mound, 4 tiles wide, gently sloped.
  Rendered as a single textured mesh.
- **Props:** three rocks, two trees. Hand-placed at named world
  positions.
- **Unit:** the chibi knight from phase 1, standing still on the
  mound, in the sharp band.
- **Camera:** fixed at a slight elevation, looking down the
  vertical axis, framing the mound in the band.
- **Tilt-shift band:** centered around the unit's Y, ~50% of the
  screen height.
- **Bottom screen / lower window half:** a tactical inset of the
  same scene, but from a more overhead angle — like a map view —
  using the same models and textures, different camera.

No animation, no input, no game state. This is the "still-life"
deliberately — a portrait, not a scene with motion. The purpose is to
prove the rendering pipeline composes correctly, not to show off
behavior.

### Loadable from a binary

The scene is stored in `assets/scenes/still-life.srs` (Symbeline Rumble
Scene), a small binary that references model and texture handles by
asset path. The format is straightforward — header + entries (entity
type, position, asset reference) — and is similar to the `.srm` /
`.srt` family.

The scene loader walks the entries and submits them via the platform
seam, applying the sharp-band rule per-unit.

## Suggested implementation steps

1. Author the assets:
   - `assets/scenes/still-life-mound.obj` → emit `.srm`.
   - `assets/scenes/still-life-rock.obj` / `still-life-tree.obj` →
     emit `.srm`.
   - `assets/scenes/still-life-grass.png` → emit `.srt` per profile.
2. Define `.srs` format in `src/09-scene-format.info.md`.
3. Author `scripts/emit-scene.lua` taking a small Lua DSL for scene
   description and emitting the binary.
4. Author `src/09-scene-loader.h`, `.c` with `scene_load_from_file`.
5. Write `src/10-still-life.c` (replacing the old hello-rumble) — a
   tiny program whose `main` is "load and render the still-life scene
   each frame, run for 30 seconds, exit." The bottom-screen inset uses
   `platform_render_set_viewport(bottom)` with the alternate camera.

## Deliverable artifacts

- Scene assets (`.obj`, `.png`, `.srm`, `.srt`).
- `scripts/emit-scene.lua`.
- `src/09-scene-format.info.md`.
- `src/09-scene-loader.h`, `.c`, `.info.md`.
- `assets/scenes/still-life.srs.lua` (the DSL source).
- `assets/scenes/still-life.srs` (generated; gitignored).
- `src/10-still-life.c` (and a phase-2 build target that uses it
  instead of phase-1's hello-rumble).

## Related documents

- `docs/006-art-direction.md` — palette, mood, what "quiet" means here.
- `docs/008-fixed-point-math.md` — positions in `fxw_t`.
