# 506 — Hatching Anchored to the Ground

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 102, 501 |
| Blocks | 505 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

Nothing draws hatching.

## Intended behavior

Two properties are wanted at once, and they pull against each other.

### It must not swim

If the lines are computed from **screen** coordinates, they slide across the
painting as you drag the map — the city moves and the pattern stands still. This
is the shower-door effect, and it makes hatching read as something smeared over
the window rather than painted onto the ground.

So the line index for a pixel is computed from its position **in painting
coordinates**: project onto the axis perpendicular to the filter's angle, divide by
the spacing, take the whole number. Locked to the ground, so panning carries the
pattern with the city.

### It must stay legible

Spacing fixed in *painting* pixels would be five times denser on screen at the
whole-city view than at native zoom, collapsing into solid fill exactly when you
most want to compare places.

So the spacing used is **the spacing wanted on screen for that place's value,
divided by the current zoom**.

### The consequence, stated honestly

The pattern is perfectly locked during panning and **breathes slightly during
zooming**. That is the right way round: panning is constant and zooming is
occasional, and a pattern that drifts while you are already changing scale is
barely noticeable, while one that drifts while you drag is intolerable.

### Value to spacing

Tighter means more. The mapping from a reading of 0..1 to a screen spacing is a
tunable curve, not a straight line — the eye judges density logarithmically, so
even steps in value should be even steps in *apparent* density rather than in
pixels.

Both ends need bounds. Too tight and it fills solid, losing the painting beneath
and the weave with it; too loose and a small place gets no lines at all and reads
as unknown, which is a lie — see [503](503-nothing-is-a-value.md).

**A place too small to show even one line of its hatching must not silently read
as ignorance.** Either the spacing floor guarantees a line, or such places are
handled deliberately. This is a real failure mode and it appears only on the
smallest blocks near the horizon.

## Suggested implementation steps

1. Compute line index from painting coordinates, always.
2. Compute spacing as a screen figure from the reading, then divide by zoom to get
   the painting-space period.
3. Clamp the screen spacing between a floor and a ceiling from
   `input/what-to-start-with`.
4. Handle the too-small-for-one-line case explicitly and say in the source what it
   does and why it is not left to chance.
5. Test the anchoring by panning across a hatched block and confirming the pattern
   moves with the roofs beneath it.
6. Test the legibility by zooming out and confirming density stays readable rather
   than going solid.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [505 — the weave](505-the-weave.md)
