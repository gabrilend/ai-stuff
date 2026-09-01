# 102 — Surfaces Are A Bit Trick

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 101 |
| Blocks | 107, 108, 202, 304, 306, 401 |
| Reads | [the stone and what is inferred](../docs/002-the-stone-and-what-is-inferred.md) |
| Open questions | none |

## Current behavior

`surfaces_of` is the three-operation expression, and a parallel array holds the
result for every column. `recompute_surfaces` takes a range so a thread pool can
call it in slices and so a golem breaking one block can repair five cells rather
than a hundred thousand.

Headroom is counted on demand and **returns open sky rather than zero when
nothing is above the surface**. Counting only as far as the last layer treats the
top of the array as a ceiling, and a surface standing at the world's highest layer
then reports no headroom at all — so nothing may step onto it, so the staircase
that reached it is severed, so the maze validates as two pieces for reasons that
have nothing to do with the maze. That is what it did, and finding it took
tracing a two-piece maze back through the movement rule.

The test compares the fast expression against a slow one that tests two bits per
layer, over the degenerate cases and four thousand random columns.

## Intended behavior

A **surface** is the top of a stone block with air above it: layer `L` of column
`c` is a surface when bit `L` of `c` is 1 and bit `L+1` is 0.

The whole set of surfaces for a column is one expression:

    surfaces = c & bit.bnot(bit.rshift(c, 1))

Shifting the column down by one layer puts what was above each layer into that
layer's position. Complementing gives a 1 wherever the layer above was air.
Anding with the original keeps only the layers that were stone. What remains is
exactly the standable tops — all thirty-two layers evaluated at once, in three
operations, with no loop and no branch.

That line is the most load-bearing in the project and everything else derives
from it:

- A column with a tunnel through it has **two** surfaces, and the expression
  finds both without knowing tunnels exist.
- A column that is entirely air has none.
- A column solid to the top of the world has none either, which is correct —
  there is nowhere on it to stand.

The surface set for every column is computed in one sweep after generation and
stored in a parallel array, one 32-bit integer per cell. It is recomputed only
when the stone changes, which is never until a golem does it in phase seven.

**Headroom** is not stored. The number of consecutive air layers above a surface
is counted on demand from the column, a handful of shifts, and only for the
specific cell a body is trying to enter. Storing it would mean maintaining it,
and it changes whenever the stone does.

## Suggested implementation steps

1. Write `surfaces_of(column)` as the one expression above. Fold it. Put the
   three-sentence explanation of why it works in a comment directly over it —
   this is exactly the kind of line that is obvious while writing and opaque six
   months later.
2. Write the sweep that fills the parallel array, and make it take a range of
   cell indices so the thread pool can call it in slices.
3. Write `surface_at(store, cell, layer)` — is this specific layer a surface —
   and `highest_surface_below(store, cell, layer)`, which the falling code needs.
4. Write `headroom(store, cell, layer)`: count consecutive clear bits starting at
   `layer + 1`, stopping at the layer ceiling.
5. Write the test against a slow reference that loops over every layer testing
   two bits. Run it over random columns from a seeded stream, including the three
   degenerate cases — all air, all stone, and a single block at the top layer.
6. Write the invariant the validator will use: every surface found by the fast
   expression is found by the slow one, and the reverse.

## Related documents and tools

- [The stone and what is inferred](../docs/002-the-stone-and-what-is-inferred.md)
- [Standing somewhere and going elsewhere](../docs/004-standing-somewhere-and-going-elsewhere.md)
