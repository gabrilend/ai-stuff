# 107 — NDS "hello rumble"

**Phase:** 1
**Blocked by:** 102 (build script), 103 (patch harness), 104 (platform
seam), 105 (fixed-point), 106 (trig table).
**Blocks:** 110 (phase 1 demo).

## Current behavior

The trunk has math, a platform seam, a build script, and a patch harness,
but no executable. There is no `.nds` artifact.

## Intended behavior

`scripts/symbeline-build nds` produces `build-nds/symbeline.nds`. Running
it (`scripts/symbeline-run nds`) on melonDS shows:

- **Top screen:** a single 16-color sprite (a chibi knight, placeholder
  art under `assets/dev/knight.png`) positioned at the center of the
  screen and bobbing vertically with `fx_sin` driving its Y offset.
- **Bottom screen:** a solid-color background plus a small text glyph
  "press A" rendered with libnds's example bitmap font.
- **Inputs:** pressing A halts the bob; releasing A resumes it.
- **Log:** every 64 frames, write to `tmp/nds-frame.log` the current
  frame count, the current `fx_t` Y offset, and the current input state.
  (Achievable via libnds + libfat on emulator; we accept that on real
  hardware this needs a flashcart.)

The "hello rumble" sprite must read as the same character on both
profiles — it is the visual anchor of phase 1 demo parity (issue 110).

## Suggested implementation steps

1. Author `src/10-hello-rumble.c`:
   - Vimfold-structured `main()`.
   - Calls `platform_init`, enters frame loop, calls `platform_frame_begin`,
     polls input, computes bob via `fx_sin`, submits sprite via
     `platform_render_sprite`, calls `platform_frame_end`.
   - Top-of-file CEO description: "the minimum game loop that exercises
     every part of the platform seam, the math layer, and the build
     pipeline — one bobbing knight on screen."
2. Fill in the NDS implementations in
   `src/platform/nds/01-platform-nds.c`:
   - `platform_init`: libnds video init (`videoSetMode` for 3D top,
     `videoSetModeSub` for 2D bottom), VRAM banks.
   - `platform_frame_begin/end`: GL flush, vblank wait.
   - `platform_input_*`: `scanKeys`, `keysHeld`, `keysDown`, touch read.
   - `platform_render_sprite`: use libnds's 2D sprite engine via
     `oamSet` for now (3D pipeline is phase 2).
   - `platform_log`: write to `nitrofs:/` (or stdout on emulator).
3. Build via `scripts/symbeline-build nds`. Patch harness applies
   `B000` (sanity) and nothing else. Trunk source is unchanged.
4. Verify by booting `scripts/symbeline-run nds` and confirming bob,
   pause-on-A, log file.

## Acceptance criteria

- `.nds` builds clean (no warnings; warnings are errors per global rule).
- Knight sprite bobs.
- A halts bob, release resumes.
- `tmp/nds-frame.log` accumulates entries.
- No malloc-and-forget; all allocations are sized and budgeted.

## Deliverable artifacts

- `src/10-hello-rumble.c`
- `src/10-hello-rumble.info.md`
- Filled-in `src/platform/nds/01-platform-nds.c`.
- `assets/dev/knight.png` (placeholder art, 16-color paletted).
- `build-nds/symbeline.nds` (build output, .gitignored).

## Related documents

- `docs/004-architecture.md` — memory budgets.
- `docs/006-art-direction.md` — even the placeholder knight must read
  consistently with the tilt-shift aesthetic.
- `docs/008-fixed-point-math.md` — the bob is `fx_sin`-driven.
