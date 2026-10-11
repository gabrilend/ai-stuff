# 301 — The sphere, projected onto the circle

**Phase:** 3 — The wheel at the center
**Blocked by:** 103, 209
**Blocks**: 302, 305, 307, 308, 609, 707
**Related documents:** docs/datapath-accordion-view.md, docs/core-terms.md
(sphere projection)

## Current Behavior

The debug view draws tiers at equal spacing on a flat circle.

## Intended Behavior

- The world grid lies on a sphere: hub at one pole, tiers as bands of
  latitude, each band crossed in equal time. The screen shows it flattened
  into a circle around the dashboard — inner tiers wide, outer tiers folded
  toward the edge.
- A place maps to a point in the far camera's 3D scene through a radial curve
  (tiers shown, fold), then the view's rotation (current seat's quadrant
  faces up).
- The curve is strictly increasing so clicks map back to places exactly.
- Places beyond the shown tiers are drawn as edge markers, never dropped.
- The projection settings are set by the game, never by the player. Assumed:
  the furthest active front always fits on screen, and the settings ease
  between values so the map breathes rather than jumps (open question 2).

## Suggested Implementation Steps

1. `src/NNN-sphere-projection.lua`: forward and inverse curve; pure math.
2. `src/NNN-projection-settings.lua`: settings derived from the snapshot
   (fronts), eased over time.
3. Tests: forward-then-inverse returns the input within 1e-9 for many places
   and settings; settings never come from input events.

## Open questions

- Who sets tiers shown and fold? (Open question 2.)
