# 805c — Diagrams by level

The third piece of 805.

## Current Behavior

No `diagram` word exists.

## Intended Behavior

Canvas word `diagram{ boxes = {...}, arrows = {...} }`, laid out by levels
reusing 043's `graph.build`/`graph.levels` (a box is a node, an arrow an
edge); each arrow drawn from one box to another with a label at either
end.

## Suggested Implementation Steps

1. Boxes/arrows read into a 043-shaped graph.
2. Level layout turned into pixel positions, one column per level.
   **Test:** a diamond of four boxes lays out in three columns; every
   arrow starts on its `from` box and ends on its `to` box.

## Blocked by

- 804
