# 403 — command-line runner

## Current Behavior

Complete. `./run` (or the runner module directly) renders one named
score or everything in input/, lands gifs by atomic rename from a
same-directory dot-partial (cross-filesystem rename fails with EXDEV
— reasoning commented), writes a plain-data report beside each gif,
streams history to the RAM log tier (a missing tier names bootstrap
rather than working around it), and writes goodbye last — what was
made, and what was not. Failures don't stop siblings; the exit code
remembers. The pipeline spine is a module shared by everything that
renders. Proven over both reference scores; the compiled two-clocks
immediately caught the phase-3 demo flooring 4.6×25 to 114 frames
(floats), which the capstone will fix in the demo.

## Intended Behavior

The runner: the program the vision describes, end to end.

- First act: read `input/` — run the named scene, or with no argument,
  every scene found there.
- The full pipeline per scene: read, compile (wall included), size the
  pool, tick the sim, snapshot, splat, tone-map, index, encode.
- Last act: write to `output/` — the gif(s), a render report (frames,
  peak particles, bytes, elapsed — measured, not estimated), and
  goodbye.
- Logs stream to `tmp/shared-memory/` (the runner recreates the RAM
  tiers if a reboot emptied them, per the skeleton issue's bootstrap).
- The root `run` script becomes a thin wrapper over this runner,
  keeping its DIR convention.
- Exit status honest: any validation or render error is nonzero with
  the error on standard output, no partial gif left behind in
  `output/` (partials go to scratch and are only moved in on success —
  an atomic-rename finish).

## Suggested Implementation Steps

1. The runner's spine (the pipeline order above, each stage already
   existing).
2. Scene discovery in `input/`; the atomic finish into `output/`.
3. The report and goodbye writers.
4. Rewire the root `run` script.

## Blockers

- 402 (compiler) and all rendering machinery beneath it.

## Related Documents

- docs/architecture.md (the pipeline, told as a story — this issue is
  that story as a program)
