# 206 — Tilt-shift divergence

**Phase:** 2
**Blocked by:** 201 (the `platform_render_begin/end_tilt_shift` hook).
**Blocks:** 207 (the sharp band rule references the tilt-shift bounds),
208, 209.

## Current behavior

`platform_render_begin_tilt_shift(band_top, band_bottom)` is a no-op
pass-through stub on both targets. Divergence grid row D1 reserves the
problem but no implementation exists.

## Intended behavior

Each target produces tilt-shift framing — a sharp central band, with
the regions above `band_top` and below `band_bottom` visually blurred —
via the technique appropriate to the target.

### NDS — layered pre-blurred backdrops (`patch_B201_nds_tilt_shift_layers`)

The DS has no shaders. The tilt-shift effect is faked:

- The 3D viewport is rendered into the central band only (clip
  appropriately).
- Above the band, a pre-blurred 2D background sprite is rendered into
  the top region. The sprite is authored by the level designer as part
  of the scene's asset bundle and represents "what the scenery looks
  like from this angle, already blurred."
- Below the band, the symmetric construction with the bottom-blurred
  sprite.
- Units, per the sharp-band rule (issue 207), are never rendered in the
  blur regions.

This is **patch B201**: replaces the no-op
`platform_render_begin_tilt_shift` with the NDS-specific clipping +
backdrop setup; `_end_tilt_shift` restores full-screen rendering.

### Native — depth-driven blur shader (`patch_B202_native_tilt_shift_shader`)

Modern wifi-less GPU work:

- The 3D scene renders to a render texture at full resolution.
- A fragment shader applies a depth-driven Gaussian blur: pixels with
  Y outside the band are blurred with a kernel whose radius increases
  with distance from the band. Pixels in the band pass through.
- The final composite is drawn to the screen.

This is **patch B202**: implements `platform_render_begin/end_tilt_shift`
on native using raylib's render-texture and a custom fragment shader.

### Divergence grid update

Row D1 is updated:

- Patch IDs filled: `B201` (nds) / `B202` (native).
- Re-convergence column unchanged: *None planned* — DS has no shaders.

## Suggested implementation steps

1. Write `patches/B201-nds-tilt-shift-layers.sh` with idempotent
   `patch_B201_*` and `unpatch_B201_*` functions.
2. Author the NDS-specific code that the patch installs into
   `src/platform/nds/01-platform-nds.c` (clipping, backdrop sprite
   binding).
3. Write `patches/B202-native-tilt-shift-shader.sh` similarly.
4. Author the native shader (`assets/shaders/tilt-shift.fs`) and the
   raylib render-texture wrapper.
5. Add `B201` to `PHASE_BEGIN_PATCHES["nds"]` and `B202` to
   `PHASE_BEGIN_PATCHES["native"]` in `patches/patches.sh`.
6. Update divergence grid row D1 with the assigned patch IDs.

## Deliverable artifacts

- `patches/B201-nds-tilt-shift-layers.sh`.
- `patches/B202-native-tilt-shift-shader.sh`.
- `assets/shaders/tilt-shift.fs` (native only; loaded at runtime).
- Updated `docs/005-divergence-grid.md` (D1 patch IDs filled).
- Updated `patches/patches.sh`.

## Related documents

- `docs/005-divergence-grid.md` row D1.
- `docs/006-art-direction.md` — the sharp band rule's rationale.
- `notes/sketches/parity-may-be-pessimism.md` — the hunch this issue
  ultimately tests.
