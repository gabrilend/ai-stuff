# 202 -- An eye and its wedge

**Phase:** 2, the world can be seen
**Blocked by:** [103](103-a-thing-is-one-record.md),
[104](104-walls-are-segments.md)
**Blocks:** [203](203-the-angular-sweep.md)
**Documents:** [sight and what it remembers](../docs/007-sight-and-what-it-remembers.md)

## Current behaviour

Nothing exists.

## Intended behaviour

Turn a thing into the question the sweep answers.

A body carries a position, a `facing`, a `sight_arc`, and a `sight_range`. Those
four define a **wedge**: an origin, two bounding angles, and a radius. This file
builds the wedge and gathers the walls that could possibly matter to it.

### The wedge

| From the thing | Becomes |
| --- | --- |
| `x`, `y` | The apex. Sight is computed from a point, not from a body's whole circle -- a body's `radius` is what *blocks* sight, not what sees. |
| `facing`, `sight_arc` | Two bounding angles, `facing ± arc/2`, in the 16-bit angle space where a full turn wraps by overflowing. |
| `sight_range` | The radius. |

A `sight_arc` of 32768 is a half-turn -- everything in front. A full 65535 is
everything, and the two bounding angles meet, which is a case the wedge-clipping
code has to handle rather than treat as a degenerate wedge of zero width. That
distinction between "sees nothing" and "sees everything" is one comparison and it
is worth a comment, because getting it backwards is silent and total.

A `sight_range` of zero means this body does not see. That is the normal state of
a coffee cup, and it is checked here, once, so the sweep never runs for something
that has no eyes.

### The broad phase

The sweep's cost is sorting endpoints, so the job here is to hand it as few
segments as possible.

Two filters, cheap first:

1. **Bounding box against the sight circle.** From the uniform grid built in
   [104](104-walls-are-segments.md). Constant time per cell, and the cells a
   circle touches are arithmetic.
2. **Wedge rejection.** A segment entirely outside the angular wedge is dropped
   before its endpoints are ever converted to angles.

Both are conservative -- they may pass a segment that turns out not to matter, and
must never drop one that does. A broad phase that is occasionally too generous
costs a little sorting. A broad phase that is once too strict makes a wall
disappear, and that is the bug where somebody sees through stone.

## Suggested implementation steps

1. Build the wedge from a thing index. One function, no allocation.
2. Handle the full-circle case explicitly and comment which side of the comparison
   means "everything".
3. Write the broad phase against the grid. Return a span of segment indices into a
   scratch buffer that was sized at startup -- not a list that grows.
4. Decide what happens when the scratch buffer is full. This is a real case in a
   dense room, and the answer is not to silently drop segments. Either the buffer
   is sized from the world at load so it cannot overflow, or the overflow is an
   error that names the body and the count. The first is better and is what
   [107](107-the-validator-refuses-to-guess.md) is for.
5. Write the companion `.info.md`.
6. Test: a body facing each cardinal direction with a narrow arc, one with a full
   circle, one with zero range, and one at a wrapping angle where the wedge
   straddles zero. The wrap case is where this file will break.
