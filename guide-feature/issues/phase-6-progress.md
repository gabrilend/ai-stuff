# Phase 6 Progress — Distill mode

## Goals
kuvalu's second merge mode: a language model combines the voices' newest
canvases before the blit. Ends with both modes run on the same recorded
input, side by side.
(`docs/roadmap.md`, phase 6)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
- **601 distill mode** (2026-11-05): the blitter's second mode. It keeps
  every voice's newest canvas, holds arrivals in distill mode, and has the
  distiller (`use.distiller`, words in `input/distill-instructions`) make
  one canvas from them all through the turn's ask-until-it-fits loop,
  blitted on the current canvas under the name kuvalu. The mode switches
  while running; a rehearsal switched newest, distill, newest made valid
  versions in both modes (`src/068-test-distill.lua`).
- **602, the phase 6 demo** (2026-11-05): `issues/completed/demos/phase-6-demo`
  (also `./run-phase-demo 6`).
  - Records a rehearsal (a minute, or `--minutes`) with the real turn in
    all three voices, whose stand-in models rewrite the first word of a row,
    a row further down each turn, at their own pace, so they meet on the
    same words: every voice canvas the blitter took, with the version it
    started from. `--save` keeps the recording; `--from` replays one.
  - Replays the same canvases through the blitter in newest mode and in
    distill mode (a stand-in distiller on 127.0.0.1), one arrival at a
    time, and shows the two shared canvases side by side after each, the
    cells that arrival changed highlighted and rows that differ starred:
    words changed, conflicts and words written over (newest), the distill's
    fit tries and seconds (distill).
  - Ends with the totals for each mode and how many of each voice's
    changes (words written and erased) the final canvas still shows in
    each mode, and the two final canvases.
  - The test checks a recording made by hand whose outcome is known, then
    a recorded rehearsal replayed from its saved recording, showing the
    same canvases and numbers.

## Phase 6 is done here, apart from the real distiller

601–602 are done. The blitter has both merge modes, switched while it
runs: `newest` blits each voice's changes as they land, and `distill` has
kuvalu's distiller combine every voice's newest canvas into one, under the
name kuvalu. The roadmap's goal for phase 6, both modes run on the same
recorded input, side by side, is met here against a stand-in distiller,
which merges by a fixed rule (047): a real model will merge differently,
and that difference is what the demo is for.

Left for the owner's machine:
- **A real distiller on `use.distiller`** (`kuvalu-qwen` in `endpoints`;
  401a's server), and `input/distill-instructions` and `input/distill`'s
  recommended counts tried with it, with what changes in
  `docs/balance-updates.md`.
- **The demo against the real servers**, recorded from a rehearsal with the
  real voices' models, to compare the modes on real writing.
