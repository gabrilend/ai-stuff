# 805c — Diagrams by level

The third piece of 805.

## Current Behavior

Built as geometry. `src/134-the-diagram-canvas.lua` reads boxes and
arrows into a 043 graph and lays it out one column per level, each arrow
from its source's right edge to its target's left edge, with `there` and
`here` at its ends. Painting it waits on 804. Checked by
`tests/135-checking-diagrams-by-level.lua`.

## Intended Behavior

Canvas word `diagram{ boxes = {...}, arrows = {...} }`, laid out by levels
reusing 043's `graph.build`/`graph.levels` (a box is a node, an arrow an
edge); each arrow drawn from one box to another with a label at either
end.

## Suggested Implementation Steps

1. Boxes/arrows read into a 043-shaped graph.
2. Level layout turned into pixel positions, one column per level.
   **Test:** a diamond of four boxes lays out in three columns; every
   arrow starts on its `from` box and ends on its `to` box. Done.

## Decisions

- Built as geometry alone, as 805a was: pixel boxes and arrow ends, for
  804's painter to draw once it exists. 804 is not needed to decide where
  things go, so the block is on the painting, not on this piece.
- An arrow from `a` to `b` makes `b` build on `a` (043's blocked_by), so
  every arrow runs rightwards, from the middle of its source's right edge
  to the middle of its target's left edge.
- Within a column, boxes go top to bottom in name order (043's own
  order), each centred in an equal share of the height.
- A circle of arrows, a box name that is not one word (043 reads names as
  space-separated words), a repeated name, an arrow naming no box and an
  arrow to itself are each refused by name.
- The word lives in its own file (134), not the chart canvas's, since it
  shares no geometry with charts.

## Blocked by

- 804
