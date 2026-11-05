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
