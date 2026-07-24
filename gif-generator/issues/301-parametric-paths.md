# 301 — parametric paths

## Current Behavior

Emitters sit where they are placed; nothing can carry one along a
curve. The clock-face convention exists only as documentation.

## Intended Behavior

Paths as functions: progress (0 to 1) in, canvas position out.

- **Arc**: center, radius, a starting and ending clock position, and a
  direction of turn (clockwise or counterclockwise — always explicit;
  an arc without a stated turn is a validation error, because "from 12
  to 7" is ambiguous without it, and the vision's two hands prove both
  directions matter).
- **Line**: two endpoints, straight interpolation.
- **Point**: a position that ignores progress.
- The clock-face convention from the scene-script datapath is
  implemented here once: hours (fractional allowed) to screen-space
  angles, y growing downward, clockwise meaning increasing angle.
- Paths also answer "which way am I heading?" (the tangent) so
  emitters can bias velocity along or against travel — the vision's
  "oriented inward" hands.
- Tests: 12 o'clock is straight up from center; a clockwise 12-to-7
  arc passes through 3 o'clock at the proportional progress; line
  midpoint; tangents perpendicular to arc radii; the missing-turn
  validation error fires.

## Suggested Implementation Steps

1. The clock-to-angle conversion (one function, one home).
2. The three path constructors returning position-and-tangent
   functions.
3. Tests as described.

## Related Documents

- docs/datapath-scene-script.md (the clock-face convention section)
