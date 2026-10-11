# 301 — The accordion projection, with reach and squeeze dials

**Phase:** 3 — The wheel at the center
**Blocked by:** 103, 204

**Blocks**: 302, 305, 307, 707
**Related documents:** docs/datapath-accordion-view.md, docs/core-terms.md
(The view)

## Current Behavior

The debug view draws tiers at equal spacing, everything to one fixed scale.

## Intended Behavior

- The map is drawn between the wheel's edge and the screen's edge. A world
  position maps to a pixel through a radial curve controlled by **reach**
  (tiers shown) and **squeeze** (compression of outer tiers), then the view
  rotation (the current seat's quadrant faces up).
- The curve is strictly increasing so clicks map back to positions exactly.
- Beyond reach: drawn as edge markers pointing outward, never dropped.
- Two half-circle dials (rotors from 204) at the left screen edge set reach
  and squeeze; values eased so the map breathes rather than jumps.
- Settings are kept per seat.

## Suggested Implementation Steps

1. `src/NNN-accordion.lua`: forward and inverse curve; pure math.
2. `src/NNN-accordion-dials.lua`: the two dials, writing the settings.
3. Tests: forward-then-inverse returns the input within 1e-9 for many
   positions and settings; squeeze 0 is linear.

## Open questions

- Are reach and squeeze the two kinds of zoom the vision means? (See
  docs/open-questions.md, question 2.)
