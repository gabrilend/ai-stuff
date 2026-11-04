# 108 — Phase 1 demo: three voices on one canvas

phase 1, the canvas and the blit

## Current behavior

No demos exist. `run-phase-demo` in the project root reports that no phase
has one.

## Intended behavior

`issues/completed/demos/phase-1-demo` plays a scripted series of voice
canvases into the blitter's arrivals folder. The series is made by a small
generator script, not by hand, and is written to show single-word edits,
overlapping writes, stale bases and conflicts. The demo then shows:

- each version of the canvas, drawn at its real size in the terminal, with
  the cells that changed in that version highlighted;
- after each version: words written, words blanked by the whole-word rule,
  removals, conflicts;
- one deliberately oversized canvas being refused, and the fit check's report
  for it, exactly as a model would read it.

The numbers come from the blitter's log and goodbye receipt, so the demo
shows what the blitter really did.

## Suggested implementation steps

1. The scripted-series generator.
2. The run script and the drawing.
3. Fill in `issues/phase-1-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 1

## Blocked by

107.

## Blocks

None.
