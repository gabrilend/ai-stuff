# 301 — The curved panel

**Phase:** 3 — The panel on its arm
**Blocks:** 302, 303
**Related documents:** docs/core-terms.md

## Current Behavior
The panel is a word.

## Intended Behavior
Where each cell of a release lands on a curved panel (curve described by
radius, number, mm), and how the picture stretches across the curve.

## Suggested Implementation Steps
1. Ray from the aperture per cell; hit point on the curve.
2. Tests: a flat panel (infinite radius) gives no stretch.
