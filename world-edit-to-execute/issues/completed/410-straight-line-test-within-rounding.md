# Issue 410: Path Smoothing Sees a Straight Line Within Rounding

**Phase:** 4 - Runtime
**Type:** Implementation
**Priority:** Low
**Dependencies:** None open
**Builds on (completed):** path smoothing (403e)
**Tracks:** known debt D-2 in `issues/CRITICAL-PATH.md`
**Status:** Completed 2026-11-02

---

## Current Behavior

`smooth.remove_collinear` (`src/runtime/pathfinding/smooth.lua`) drops a
waypoint when it lies on the line between its neighbours. It tests that
with the cross product compared to exactly zero. On grid cells (whole
numbers) that works. With fractional coordinates, which world positions
are, rounding leaves the cross product a hair off zero (about 2e-16), so
straight runs keep waypoints they could drop: ten points evenly spaced on
one line, starting at (0.1, 0.3), reduce to eight instead of two.

A second fault sits beside it. The function's comment says it removes only
"direction-preserving points", but the code doesn't check direction: a
path that goes out along a line and comes back along it loses the point
where it turns, since all three points are on one line.

## Intended Behavior

- Three points count as in line when the sine of the angle between the two
  legs is within a small tolerance (`smooth.COLLINEAR_TOLERANCE`, 1e-9).
  The tolerance doesn't depend on the path's scale: a slight bend on a
  2,000-unit leg and a turn on a path a thousandth of a unit long are both
  still turns.
- A point the path doubles back from is kept; a repeated point on a
  straight line is dropped, as before.

## Suggested Implementation Steps

1. In `are_collinear`, keep the exact-zero case, and otherwise compare
   |cross| with the tolerance times the product of the two lengths.
2. In `remove_collinear`, drop a point only when it is in line *and* the
   path keeps going the same way (the dot product of the two legs is not
   negative).
3. Tests in `src/tests/test_path_smoothing.lua`.
4. Take D-2 off the critical path's known debt.

## Acceptance Criteria

- [x] Fractional points whose raw cross product isn't zero but which lie
      on one line count as collinear
- [x] A ten-point fractional straight line reduces to two points
- [x] Slight bends on long legs and turns on tiny paths are kept
- [x] A path that doubles back keeps its turning point
- [x] Existing smoothing and pathfinding tests pass unchanged
- [x] D-2 is removed from `issues/CRITICAL-PATH.md`

## Implementation Notes

**Date:** 2026-11-02

- **`src/runtime/pathfinding/smooth.lua`:** `smooth.COLLINEAR_TOLERANCE =
  1e-9`. `are_collinear` divides out the lengths (one square root, only
  when the cross product isn't exactly zero, so whole-number grid paths
  cost what they did). `remove_collinear` checks the two legs point the
  same way before dropping the middle point.
- **`src/tests/test_path_smoothing.lua`:** eight new tests (72 in all).
  Against the old `smooth.lua` three of them fail: the fractional points,
  the fractional line (8 points left, not 2) and the path that doubles
  back.
- The critical path's Known Debt section also had D-1 still listed,
  though bounty B01 fixed it on 2026-09-29; it is moved to the fixed list
  with D-2 and D-3 (issue 118), which leaves no open debt.

### Decisions made while building

1. **A tolerance on the angle, not on the cross product itself.** The
   cross product grows with the square of the path's size, so any fixed
   threshold on it would be too loose for long legs in world units and too
   tight for small ones. The sine of the angle has no units.
2. **1e-9.** It is about 6e-8 of a degree, far below any turn a unit makes
   and far above double rounding (around 1e-16), so neither kind of
   mistake is near it.
3. **Doubling back counts as a turn.** The function's own comment already
   promised it ("only removes direction-preserving points"); A* doesn't
   make such paths, but waypoint lists from orders and scripts can.
