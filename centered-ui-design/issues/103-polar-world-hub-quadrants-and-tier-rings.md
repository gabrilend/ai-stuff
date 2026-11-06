# 103 — The polar world: hub, quadrants and tier rings

**Phase:** 1 — The world beneath
**Blocked by:** 102

**Blocks**: 104, 108, 301, 401, 501, 601
**Related documents:** docs/core-terms.md (The shape of the world),
docs/datapath-world-tick.md

## Current Behavior

No world model exists.

## Intended Behavior

- Every position is a pair: tier-distance (0 at the hub, 1.0 at the outer
  edge of tier 1) and angle (radians, 0 = up, clockwise).
- The world knows its team size and gives each seat a quadrant: an angle
  range of a full turn divided by team size, seat 1 starting centered on up.
- Tier bands are listed from the hub outward; each knows its inner and outer
  tier-distance (band *k* spans *k−1* to *k*) and has a terrain grid filled
  as open ground for now (phase 6 fills it properly).
- Functions answer: which quadrant is this position in; which tier band;
  distance between two positions (in tier-distance, using a polar distance
  where one tier of angle-travel at radius *r* costs proportionally to *r*,
  so flanking far out takes longer than flanking near the hub — see open
  question).

## Suggested Implementation Steps

1. `src/006-positions-and-angles.lua`: position constructor, angle wrapping,
   angular difference, polar distance.
2. `src/007-the-world.lua`: world table creation from settings; quadrants;
   tier bands.
3. Tests: quadrant lookup at every boundary for team sizes 1–4; angle wrap.

## Open questions

- Does sideways (flanking) movement cost more far out (a real circle, wider
  outside), or the same at every tier (tier-time applied to angle too)? The
  current plan is "more far out"; this decides whether flanking is a
  near-hub manoeuvre.
