# 306 — Phase 3 demo: the round trip through rmail

phase 3, the relay through rmail

## Current behavior

Phase 2's demo shows versions reaching readers on kuvalu once 206 is done.

## Intended behavior

`issues/completed/demos/phase-3-demo` runs the rehearsal (305) for a few
minutes and shows:

- per voice, a timeline of canvases received, turns run, and canvases sent;
- the round-trip time from version published to the voice's edit blitted,
  as a histogram, which shows rmail's pacing;
- canvases that waited (arrived during a turn) and were replaced before use;
- the canvas itself changing in the terminal with phase 2's marks, so phases
  1–3 run together.

## Suggested implementation steps

1. The run script, reading the rehearsal's log.
2. Fill in `issues/phase-3-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 3

## Blocked by

305.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The demo runs the rehearsal in a throwaway copy of the project**, as
   phase 2's demo does. It uses the project's own `input/` (the canvas, the
   turn, the rehearsal's timers) and is removed at the end. `--keep` leaves
   it. The voices are sent this project's commit (its checkout is the
   project folder itself).
2. **It runs for `minutes` in `input/rehearsal` (5), with rmail's own
   timers (30 s ± 30 s)**, so the histogram shows rmail's real pacing
   rather than a sped-up one. `--minutes` shortens it. The test uses
   1 s ± 0.5 s, a 1.5 s turn and 20 seconds.
3. **Every version is drawn as it is made, with phase 2's marks**, coloured
   by voice and dimmed by age, or as letters under the rows in plain
   mode. Above each version: the voice, its turn, and how long after its
   base was published it was blitted. Phases 1–3 thus run together, as the
   issue asks.
4. **Two histograms:** the whole round trip, and the part of it spent
   waiting for rmail's timer (the voice's canvas from finished to
   delivered). The second shows where the time goes.
5. **The timeline is one line per voice, 60 columns over the run**: `r`
   received, `=` a turn running, `S` sent, `u` unchanged, `x` replaced.
   The voice's counts are printed under it.
6. **"Waited" means received while that voice's turn ran; "replaced"
   means overwritten in `turn/<voice>/waiting` before it was taken.** Both
   are listed with their times. The voices' own canvases that were
   superseded in their outbox before rmail carried them are counted too.
7. **Every number comes from the rehearsal's timings, events and
   receipt.** The test reads those itself and checks the demo against
   them.

## Implementation notes (2026-11-05)

- `issues/completed/demos/phase-3-demo` and `phase-3-demo.lua`; offered by
  `./run-phase-demo 3`.
- `src/045-test-phase-3-demo.lua`: 20 pass.
- `src/043-rehearsal.lua`: a turn's base and the time its base was
  published are now read from the arrival itself when the voice's own
  events have not been read yet. This happens when an arrival is taken in
  the same moment the turn ends. `on_version` gets that turn's timing row.
- Mutation checks, 7, all caught. Two survived at first and needed
  stronger runs:
  - **The replaced list.** The test's turn now outlasts the carrier's
    timers, so canvases wait and are replaced.
  - **Turns counted as sends.** The run through `run-phase-demo` now uses
    one word only, so turns that change nothing happen.
- `.file-index-counter` is at 045.

**Needs the owner's machine:** the demo watched in a real terminal for its
five minutes, and once with `carrier = "rmail"` in `input/rehearsal`, so
the histogram shows the real daemons' timing.
