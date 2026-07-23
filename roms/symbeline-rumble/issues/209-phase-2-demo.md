# 209 — Phase 2 capstone demo

**Phase:** 2
**Blocked by:** 201–208.
**Blocks:** nothing in phase 2. Unblocks phase 3.

## Current behavior

The still-life scene from issue 208 runs on both targets but has no
integrated demonstration that compares them side-by-side or quantifies
parity.

## Intended behavior

`./run-phase-demo` with input `2` runs
`issues/completed/demos/phase-2-demo/run.sh`, which:

1. Builds both profiles (`scripts/symbeline-build both`).
2. Launches NDS in melonDS and native binary side-by-side. If no
   display server is available, runs both, captures screenshots
   automatically.
3. Each target runs the still-life scene for 30 seconds.
4. Both targets log per-frame data to `tmp/<profile>-phase2-frame.log`
   (frame count, current memory budget readout, current triangle
   count, current bound-texture count). Same schema as phase 1.
5. After both runs, captures a representative screenshot from each
   target.
6. Runs `scripts/compare-frames` against the two screenshots:
   - Computes per-channel histogram similarity (cosine).
   - Reports a 0.0–1.0 parity score.
   - Logs the worst-divergent regions for human inspection.
7. Prints a one-screen **statistics readout**:

   ```
   PHASE 2 — STILL-LIFE DEMO
   ─────────────────────────────────────────────────
   Frames rendered .......... nds: 1798 / native: 1801
   Avg frame time ........... nds: 16.6ms / native: 4.2ms
   Triangle count ........... nds: 412 / native: 412
   Texture VRAM ............. nds: 184 KiB / native: 184 KiB (cap)
   Main RAM ................. nds: 2.1 MiB / native: 2.1 MiB (cap)
   Tilt-shift technique ..... nds: layered backdrop / native: depth-blur shader
   Sharp-band culls ......... nds: 0 / native: 0
   Histogram parity score ... 0.XX
   ─────────────────────────────────────────────────
   ```

## What the demo is meant to prove

- The render seam works on both targets.
- The tilt-shift divergence produces visually similar frames.
- The sharp-band rule is active and unviolated.
- The asset pipeline (model + texture + scene) is functional.
- The budget readouts continue to honor DS limits on both targets.

## What the demo is **also** meant to surface

This is the first moment `notes/sketches/parity-may-be-pessimism.md`
becomes testable. The user is expected to look at the screenshots and
form an opinion: does the native build look like a worse version of
itself wearing the DS's clothes, or does the parity discipline produce
two screenshots that read as the same game on different screens? The
answer guides whether the parity rule survives into phase 3.

If the native frame looks faintly embarrassing — fan-port-shaped — the
prediction in the sketches note was right and we revisit the parity
rule. If the two frames read as the same game, the prediction was
wrong and the parity discipline holds. Either way, the result is the
input to the next architectural decision.

## Suggested implementation steps

1. Create `issues/completed/demos/phase-2-demo/`.
2. Author `run.sh`, `README.md`, `screenshots/` (placeholder for the
   captured output).
3. Author `scripts/compare-frames` (Lua, build-time tool): reads two
   image files, emits a histogram-based parity score, exits non-zero
   on score < 0.7.
4. Extend `run-phase-demo` (from phase 1's issue 110) to dispatch on
   phase number; add the phase-2 case.
5. Take side-by-side screenshots; commit to `screenshots/`.
6. Update `issues/phase-2-progress.md` with completion notes and the
   parity-may-be-pessimism evaluation.

## Deliverable artifacts

- `issues/completed/demos/phase-2-demo/run.sh`.
- `issues/completed/demos/phase-2-demo/README.md`.
- `issues/completed/demos/phase-2-demo/screenshots/nds.png`.
- `issues/completed/demos/phase-2-demo/screenshots/native.png`.
- `scripts/compare-frames`.
- Updated `run-phase-demo`.
- `issues/phase-2-progress.md` (final update for phase 2).

## Related documents

- `docs/009-roadmap.md` — phase 2 capstone description.
- `notes/sketches/parity-may-be-pessimism.md` — the hunch tested here.
- All of phase 2's issues.
