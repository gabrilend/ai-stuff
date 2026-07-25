# 503 — big-canvas demo (phase 5 capstone)

## Current Behavior

Complete — the numbers below are what the demo printed on its first
public run, recorded as history (run the demo or the statistics
utility for current truth): the doubled vision rendered in 4.81
wall-seconds with one worker and 1.56 with four — a 3.08x speedup —
and both files were byte-identical at 1,049,800 bytes, asserted in
the demo where the audience can watch it fail. The forge showpiece
(three rings, a radially blooming violet heart peaking at 4,017
particles, gold seals between the rings' resting tips) rendered its
150 frames at 512 in 2.79 wall-seconds with the crew. Both scores
are input/ citizens; both gifs joined the gallery beside everything
earlier.

## Intended Behavior

The phase-5 demo: the flagship vision scene at 512 or larger, rendered
twice — worker count one, then many — with the statistics utility's
two reports side by side; plus one new large-canvas showpiece scene
(denser particle work than the vision asks, chosen to make the workers
sweat honestly).

- Both gifs and both reports land in `output/` and the gallery; the
  demo prints the speedup as measured that run, never a remembered
  number.
- Byte-identity between the two renders is asserted right in the demo
  (the determinism promise, performed in public).
- Phase-picker gains phase 5.

## Blockers

- 501 (parallel pipeline), 502 (statistics utility).

## Suggested Implementation Steps

1. The showpiece scene (an `input/` citizen like any other).
2. The demo script: two renders, identity check, side-by-side report.
3. Picker registration; gallery rebuild.

## Related Documents

- docs/roadmap.md (phase 5)
- strategems/pipeline-of-snapshots (what is being shown off)
