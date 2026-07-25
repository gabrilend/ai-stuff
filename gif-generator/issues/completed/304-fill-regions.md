# 304 — fill regions

## Current Behavior

Complete, with two design discoveries recorded. First: naive
rejection sampling starves exactly when the frontier is a sliver —
which is every fill's opening moment — so sampling proposes inside a
shape that already respects the frontier (a strip, a disc, a prefix)
and rejects only on the polygon test. Second: an "at-once" sweep
joined the founding styles, because the vision's seal-line fades in
as one whole thing rather than drawing itself; "along" covers the
draw-itself case for lines. Zero coverage births nothing and banks
nothing (the flash nobody choreographed, refused — reasoning at the
decision). The emit module gained public single-birth and
fractional-due atoms so field births each land at their own sampled
point; the completed emitters issue carries the cross-note. Fifteen
assertions, uniformity tested statistically with tolerance stated.

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
