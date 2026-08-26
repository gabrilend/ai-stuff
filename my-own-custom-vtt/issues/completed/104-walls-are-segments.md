# 104 -- Walls are segments

**Phase:** 1, the world holds still
**Blocked by:** [101](101-the-arithmetic-is-integers.md),
[102](102-the-world-is-flat-arrays.md)
**Blocks:** all of phase 2. Sight is a question asked of these segments.
**Documents:** [the map is geometry, not a picture](../../docs/006-the-map-is-geometry-not-a-picture.md)

## Current behaviour

Nothing exists.

## Intended behaviour

The wall record, the light record, and the handful of geometric predicates that
everything later will ask of them.

A wall is two endpoints and some flags. It is not dark pixels, and the entire
project rests on that difference: because a wall is a segment, sight can be
computed from it; because sight can be computed, fog can be per-person; because
fog is per-person, the server can refuse to send what a viewer cannot see.

The two blocking bits are separate on purpose. A chasm blocks movement and not
sight. A curtain blocks sight and not movement. A portcullis blocks movement and
lets sight through. One `solid` flag would delete all three cases.

`ONE_WAY` blocks only from the segment's left, taking `a`-to-`b` as forward.
Which side something is on is the sign of a cross product, computed once when the
segment enters a sweep.

### The predicates this file owns

| Predicate | Used by |
| --- | --- |
| Which side of a segment is this point on | `ONE_WAY`, and the sweep |
| Do these two segments intersect, and where | Motion against walls |
| Closest point on a segment to a point | Collision resolution in phase 3 |
| Does this segment's bounding box overlap this circle | The sight broad phase in phase 2 |

All in fixed point, all through [101](101-the-arithmetic-is-integers.md).

### A door is a wall whose flags change

There is no door system. A segment whose `door` field points at a thing has its
blocking bits cleared when that thing is opened. The sight code never learns what
a door is, and there is never any doubt about what a half-open door does -- the
leaf swings for the picture's sake and the bits flip at one defined moment.

## Suggested implementation steps

1. Define the wall record and the light record.
2. Write the predicates, each with a comment naming what each branch means -- for
   the side test in particular, what the world is like when the answer is zero,
   because collinear is a real case and it is where these tests go wrong.
3. Write the polygon predicates that [105](105-regions-nest.md) and the validator
   need: containment, signed area for winding, and self-intersection.
4. Write the companion `.info.md`.
5. Test the predicates against hand-computed cases, especially collinear,
   touching-at-an-endpoint, and zero-length segments. A zero-length segment
   should be refused by [107](107-the-validator-refuses-to-guess.md) rather than
   handled here, but the predicate should not crash on one.

## What moved out of this issue

The broad-phase index -- a uniform grid over the map, so that "which walls are
near this point" is answered without touching every wall -- was originally listed
here and belongs with [202](202-an-eye-and-its-wedge.md) instead.

The reason is that **its only two consumers are the sight sweep and collision,
and both are later phases.** Building an index in phase 1 would mean building it
without either caller to shape it, and an index built against no query is an
index built against the wrong query. Phase 1 ends with predicates that answer
correctly and walk every wall to do it, which is right for a world that is not
moving and is measured rather than guessed at by
[109](109-the-phase-one-demo.md).

## Related

Lights live here rather than in their own file because a light is geometrically
the same object as an eye -- a position, an arc, a radius -- and phase 2 will want
to run the same sweep for both.
