# 302 — The Click Does Three Things

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 301, 304 |
| Blocks | 303, 310 |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | — |

## Current behavior

The tool opens and shows a network. Nothing can be traced.

## Intended behavior

Blocks are traced **one loop at a time**: click around a block until it closes,
name it, move on. What a click *does* depends entirely on what is under the
cursor:

| Under the cursor | What the click does |
| --- | --- |
| empty painting | makes a new vertex |
| an existing vertex | adopts it, becoming a shared junction |
| an existing edge | adopts **the entire run**, reversed |

Because the outcome depends on what was hit, this is a **dispatch table keyed on
the hit kind**, not a chain of if-else.

### The third row is the whole design

Suppose block A is traced and you are on the far side of a curving lane, tracing
block B. Even with perfect snapping onto A's two corner vertices, the stretch
between them is a fresh set of clicks. A traced that curve with five shape
points; you trace it with four, in slightly different places.

Now two hairlines run down the same lane with slivers of painting between them —
and, silently, **the two blocks do not share an edge**, so they are not
neighbours, so nothing will ever propagate between them.

Adopting the whole edge instead is one click rather than five, and the blocks
become adjacent because they are literally naming the same edge record. Identical
by definition rather than by luck.

Without edge adoption, per-block tracing produces a torn city no matter how good
the point snapping is. This issue exists mostly to make that one operation right.

### Closing the loop

The loop closes when you click the vertex you started from. On closing, the tool
builds the block's loop with **direction flags** — see
[201](201-vertices-edges-and-loops.md) — deriving each flag from the order the
edge was walked during tracing, not from geometry.

An adopted edge is walked in the direction opposite to the block that already
owns it. That is where the flag comes from, and getting it from anywhere else is
how self-crossing loops appear.

### Edges between adopted vertices

Clicking a sequence of empty points creates new vertices; the run between the
first and last becomes a new edge when the segment ends at an adopted vertex or
closes the loop. Interior points of that run are shape points belonging to it
alone.

## Suggested implementation steps

1. Extend hit-testing to report the hit *kind* — empty, vertex, or edge — along
   with what was hit, using the snap radius from
   [304](304-snapping-is-measured-on-the-screen.md).
2. Build the dispatch table: three entries, one per kind.
3. Hold the in-progress trace as an ordered list of steps, each recording what it
   adopted or created, so it can be undone step by step.
4. On adoption of an edge, record the direction it was walked.
5. On closing, assemble the loop and run the validator from
   [208](208-the-network-validator.md) on the affected part before accepting it.
6. Refuse to close a loop that fails validation, and say which check failed and
   where — never accept a malformed block and leave it to be found later.
7. Test by tracing the four fixture blocks around a crossroads and asserting all
   four report the right neighbours.

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [The fence network](../docs/004-the-fence-network.md)
