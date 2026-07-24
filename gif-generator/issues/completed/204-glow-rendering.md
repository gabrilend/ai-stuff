# 204 — glow rendering

## Current Behavior

Complete. The snapshot freezes the live prefix with fades computed at
freeze time (fade rides in doubles — it is the one value born at the
border, and narrower storage made the two render paths disagree in
the last bits; the identity test caught it and the reasoning lives at
the field). The splatter stamps squared-falloff bells at true
fractional positions; the pool-direct render path exists only so the
tests can prove the border loses nothing. Ten assertions, including
last-float identity over a real simulated swarm.

## Intended Behavior

The splatter: every live particle stamps a radial glow into the light
canvas, additively.

- The stamp is a small square around the particle's sub-pixel position;
  within it, energy falls off as a squared-falloff bell evaluated at
  each pixel's true distance from the fractional center — motion stays
  silky, never snapping to the grid.
- Stamp intensity scales by the particle's fade (from the physics work)
  and its bright-seed; stamp color comes from its hue.
- Deposits only add, so particle order is irrelevant — the property
  that later lets worker threads split the population by index span.
- The frame snapshot defined in the particle-sim datapath is
  introduced here as the renderer's actual input (positions, fades,
  hues, bright-seeds copied out of the pool after each tick) — the
  clean border between simulating and drawing.
- Tests: a single centered particle produces a symmetric stamp; two
  coincident particles produce exactly the sum; a particle at the
  canvas edge clips without error; snapshot rendering equals direct-
  from-pool rendering byte-for-byte after tone-mapping.

## Suggested Implementation Steps

1. The frame snapshot record and the copy-out step.
2. The stamp loop with edge clipping.
3. Tests as described.

## Blockers

- 102 (light canvas), 201–203 (a population to draw).

## Related Documents

- docs/datapath-rendering.md (splatting section)
- docs/datapath-particle-sim.md (the frame snapshot)
- strategems/pipeline-of-snapshots (why the copy is the design)
