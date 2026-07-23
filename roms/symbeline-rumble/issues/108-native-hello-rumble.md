# 108 — Native "hello rumble"

**Phase:** 1
**Blocked by:** 102 (build script), 103 (patch harness), 104 (platform
seam), 105 (fixed-point), 106 (trig table).
**Blocks:** 110 (phase 1 demo).

## Current behavior

The trunk has all the pieces in place but the native profile has no
implementation routed in. There is no native binary.

## Intended behavior

`scripts/symbeline-build native` produces `build-native/symbeline`.
Running it shows a vertical window (256 wide × 384 tall — the DS stacked
screen aspect, doubled for visibility) split top/bottom:

- **Top half:** the same bobbing chibi knight from issue 107.
- **Bottom half:** the same solid-color background and "press A" prompt
  (A is mapped to keyboard Space, with mouse-click on the lower window
  half also counting as A).
- **Inputs:** pressing A (Space or click) halts the bob.
- **Log:** every 64 frames, write to `tmp/native-frame.log` (same
  format as `tmp/nds-frame.log`).

The two halves of the window are drawn as if they were two screens,
because that is what they will be on DS. Coordinate systems match: a
sprite at `(x=128, y=96)` in `fxw_t` coordinates renders at the visual
center of the top half on both targets.

## Suggested implementation steps

1. Fill in `src/platform/native/01-platform-native.c`:
   - `platform_init`: open a raylib window, sized to the doubled DS aspect.
   - `platform_frame_begin/end`: `BeginDrawing` / `EndDrawing`.
   - `platform_input_poll`: translate keyboard + mouse to logical buttons.
     Space → A; arrow keys → D-pad; left mouse on top half → top-touch
     (Anbernic emulation); left mouse on bottom half → stylus.
   - `platform_render_sprite`: blit a texture loaded from
     `assets/dev/knight.png` via raylib.
   - `platform_log`: write to `tmp/native-frame.log` and stdout.
2. Author `patches/B100-native-platform-impl.sh` to route the native
   implementation file into the compile set when `PROFILE=native`. The
   exact mechanism (filename swap, or `#define SYMBELINE_PROFILE_NATIVE`
   toggle in `src/01-platform.h`) is decided during implementation and
   documented in the patch file's header comment.
3. Author `patches/B101-native-asset-load.sh` to point asset loaders at
   the host filesystem (vs. nitrofs on NDS). Could also be a single
   `B100` with both jobs — left to implementer.
4. Add the new patches to `PHASE_BEGIN_PATCHES["native"]` in
   `patches/patches.sh`.
5. Add rows D2 (graphics submission) and D5 (file I/O) to the
   divergence grid (`docs/005-divergence-grid.md`) if not already
   present. Cross-reference the patch IDs.

## Acceptance criteria

- Native binary builds clean.
- Window opens, knight bobs.
- Space halts bob; release resumes.
- `tmp/native-frame.log` accumulates entries identical-in-structure to
  the NDS log.
- Patch harness applies the native patches at build start, unapplies
  them at build end; the trunk source is byte-identical before and
  after the build (verified via `git diff` returning empty after
  unapply).

## Deliverable artifacts

- Filled-in `src/platform/native/01-platform-native.c`.
- `patches/B100-native-platform-impl.sh`
- `patches/B101-native-asset-load.sh` (or merged into B100).
- `build-native/symbeline` (build output, .gitignored).
- Divergence grid rows updated.

## Related documents

- `docs/004-architecture.md` — platform seam, native backend choice.
- `docs/005-divergence-grid.md` — rows D2, D4, D5 are exercised here.
