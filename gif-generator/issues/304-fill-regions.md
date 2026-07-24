# 304 — fill regions

## Current Behavior

Emitters ride points, lines, and arcs; nothing can slowly flood an
area with glow — the vision's "fill the triangle, slowly" has no home.

## Intended Behavior

The region sampler: a fill is not a polygon-rasterizing special case
but a *field emitter whose coverage grows*, so fills inherit the
particle aesthetic wholesale.

- A fill region is defined by vertices (triangle first; the mechanism
  should not care about vertex count) plus a sweep style: how coverage
  advances from 0 to 1 — founding styles: **downward** (a horizontal
  frontier descends), **from-edge** (grows away from a named edge),
  **radial** (grows from a point).
- Asked for a spawn position at coverage c, the sampler returns a
  uniformly random point inside the covered portion — uniform matters,
  or the fill looks crowded at one end; the test for it is statistical
  (bin counts over many samples, tolerance stated in the test).
- Line-shaped field emitters (the fading seal-line of the vision) are
  the degenerate case: a region with zero thickness; one mechanism,
  both uses.
- The frontier's position is eased by the track like any progress —
  "slowly" is just an easing choice.
- Tests: covered-area containment (no particle outside the frontier),
  uniformity as above, the zero-thickness line case, coverage 1
  equals the whole region.

## Suggested Implementation Steps

1. Point-in-region and frontier arithmetic for the three sweep styles.
2. The rejection-or-transform sampler (choose per style; document why
   where it lives).
3. Tests as described.

## Blockers

- 303 (tracks carry the coverage progress).

## Related Documents

- docs/datapath-scene-script.md (fill in the vocabulary)
- docs/datapath-particle-sim.md (field emission in the tick)
