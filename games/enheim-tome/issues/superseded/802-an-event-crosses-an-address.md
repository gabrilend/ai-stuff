# 802 — An Event Crosses an Address

> **Superseded.** Kept for the record rather than deleted &mdash; see
> [phase 8 progress](../phase-8-progress.md) for what replaced it and why, and
> [the scaffold](../../docs/009-the-scaffold.md) for the design that stands now.
>
> The crossing that matters is between people in a place at an hour, not between
> two addresses. It joins nothing, because it is not stored.

| | |
| --- | --- |
| Phase | 8 — Events, and What Is Known |
| Blocked by | 203, 801 |
| Blocks | — |
| Reads | [the scaffold](../../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

Events sit at an address and refer to nothing.

## Intended behavior

An event **joins two places**. The key is in one block; the chest is in another,
across the yard.

So an event is **an edge, not a leaf** — and the joining is the whole of its
interest. A fact entirely contained in one house is a detail; a fact that reaches
somewhere else is a reason to go there.

### What this makes the city

A second graph over the first.

The street network gives you adjacency: what is physically next to what — see
[203](../203-adjacency-is-a-shared-edge.md). The events give you a different set of
connections entirely: what is *tied* to what, regardless of whether you can walk
between them easily.

Those two graphs disagreeing is where the interest lives. A key in a block on one
side of a wall opening a chest on the other joins two places the streets do not,
and that is a thing worth knowing precisely because the city's own shape hides it.

### Most reaches should be short

"The block on the other side of the yard" is one hop, or two. That is the register:
**a fact that reaches a neighbour**, not a fact that reaches across the city.

Long reaches should be rare enough to feel like something. If every event joined
distant quarters, distance would stop meaning anything and the city would flatten
into a lookup table.

**Working ruling:** the coverage report notices the distribution of reach lengths
in hops, so that drift toward long reaches is visible while the corpus is being
written rather than after.

### The reach is an address, not a pointer to another event

The chest is a thing in a place. It is not a second event that must exist first.
That keeps events independent — each is written, checked and finished on its own,
which matters enormously across a corpus of tens of thousands.

If events referred to each other, writing one would mean maintaining a web, and
nobody sustains that for years.

## Suggested implementation steps

1. Add the optional reach as an address in the same form as the event's own.
2. Validate that it resolves and that it is not the same place as the event's own
   address — an event reaching itself is a writing mistake.
3. Compute the reach in hops using the neighbour walk, and record the distribution
   for the coverage report.
4. Do not build any structure that pairs events with each other.
5. Test that an event's reach resolves to a real block, and that hop distance is
   computed over the street graph rather than by any measure of distance.

## Related documents and tools

- [the scaffold](../../docs/009-the-scaffold.md)
- [The fence network](../../docs/004-the-fence-network.md)
