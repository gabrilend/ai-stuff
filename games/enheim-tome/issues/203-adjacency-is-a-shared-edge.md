# 203 — Adjacency Is a Shared Edge

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 201 |
| Blocks | 208, 608 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Blocks exist and have loops. Nothing knows which blocks touch.

## Intended behavior

**Two blocks are neighbours when their loops name the same edge.** That is the
entire definition, it is exact, and it is the **only notion of nearness this game
has**.

### Why there is nothing else

The painting is an oblique aerial view. Ordinary townhouses measure 12 to 20
pixels across by the north wall and 40 to 70 down in the harbour — a three or
fourfold swing that worsens toward the horizon. Any distance computed from those
pixels is wrong by a factor that depends on where you measured it.

So the game never claims one. Where another game says "everything within two
hundred feet", this one walks the neighbour graph: one block along, then another.

That is the better model anyway for a walled city. **Influence travels down lanes
and a rampart stops it outright**, because the blocks on either side of a wall do
not share an edge. No special case is needed for walls; they work by not being
streets.

### What a hop means

Walking the graph gives distance a felt shape rather than a numeric one. One hop
is your daily life. Several hops is an errand you would remember taking. Anything
that wants a range expresses it in hops.

### Building it

An index from edge to the blocks that name it. Every edge should name **exactly
two** blocks, except along the city's outer boundary where it names one.

That index gives neighbours in constant time and is also what
[208](208-the-network-validator.md) checks for impossibilities — an edge named by
three blocks cannot exist in a plane.

## Suggested implementation steps

1. On load, walk every block's loop and record, per edge, which blocks named it.
2. Neighbours of a block: for each edge in its loop, the other block naming that
   edge, if any.
3. A breadth-first walk from a block, yielding blocks in order of hops, with a
   limit. This is the primitive every later "how far does this reach" question
   uses; write it once here.
4. Never compute a centroid distance anywhere, for any purpose. If something
   wants one, that is a design error to raise rather than a function to add.
5. Test on the fixture: four blocks around a crossroads, each with two neighbours;
   confirm that blocks diagonally opposite are **two hops apart, not adjacent**,
   since they share only a vertex and not an edge.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [What this game is](../docs/001-what-this-game-is.md) — what the game never claims
