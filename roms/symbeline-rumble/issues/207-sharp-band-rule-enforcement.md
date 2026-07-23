# 207 — Sharp band rule enforcement

**Phase:** 2
**Blocked by:** 203 (camera), 206 (tilt-shift defines the band).
**Blocks:** 208, 209.

## Current behavior

`docs/006-art-direction.md` declares the sharp band rule: units render
only in the central sharp band; if a unit would render outside the
band, it does not render. This rule is currently aspirational — no code
enforces it.

## Intended behavior

A scene-level system tracks the current tilt-shift band bounds and
filters unit submissions:

- `scene_set_sharp_band(fxw_t world_top, fxw_t world_bottom)` records
  the band in world coordinates for the current frame.
- `scene_submit_unit(unit_t*)` checks whether the unit's projected
  screen Y falls within the band. If yes, submit. If no, *do not
  submit* — the unit is briefly invisible.
- Scenery (non-unit geometry) is exempt; it renders into blur freely.

The rule applies to:

- Player and enemy units.
- Projectiles, spell effects centered on a unit.
- Speech bubbles attached to units.

The rule does NOT apply to:

- Terrain, props, structures.
- Section-mark gold bars (attached to structures, not to units).
- Ambient scene atmospherics.

### Camera coupling

In normal play, the camera follows action such that units stay in the
band. The rule is a *correctness backstop* for moments when the camera
cannot keep up (transitions, paging, edge cases) — it ensures we never
accidentally render a blurry-looking unit, which would either look
wrong on native or be impossible on NDS.

### Failing loudly

In debug builds, a unit culled by the rule emits a log line:

```
SHARP_BAND_CULL frame=12345 unit=footman_001 screen_y=20 band=[64..192]
```

If this happens often in release, the camera tracking has a bug; the
log gives us the evidence.

## Suggested implementation steps

1. Add the band-tracking and submission-filter logic to `src/08-scene.h`
   and `.c` (new files; index counter advances).
2. Wire the band-set from `platform_render_begin_tilt_shift` into the
   scene (the platform layer notifies the scene).
3. Implement the screen-Y projection for unit positions using the
   current camera matrices.
4. Add `tests/08-scene-sharp-band.c` exercising units at positions
   inside and outside the band; assert submission count matches.
5. Document the rule in `src/08-scene.info.md` with the rationale.

## Deliverable artifacts

- `src/08-scene.h`, `src/08-scene.c`, `src/08-scene.info.md`.
- `tests/08-scene-sharp-band.c`.
- Wiring in `platform_render_begin_tilt_shift`.

## Related documents

- `docs/006-art-direction.md` — the rule's rationale.
- `notes/sketches/parity-may-be-pessimism.md` — if native looks
  better-than-DS at phase 2 capstone, this rule's pessimism shape is
  part of why.
