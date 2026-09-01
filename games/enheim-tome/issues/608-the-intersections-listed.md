# 608 — The Intersections, Listed

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 203, 306, 606 |
| Blocks | — |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Intersections have names. Nothing shows them.

## Intended behavior

A selected block lists **its intersections, each with everything it connects to**.

### Why this is in the interface at all

Because of what nearness means here:

> The connections are what's nearby.

Not distance, not a radius — which street runs lead where, and what they reach. So
a block's borders are **a list of named corners** rather than an anonymous
outline, and reading that list tells you who your neighbours are in the only sense
this game has.

That makes the adjacency graph — which is otherwise an invisible structural fact —
into something a person can read and reason about. It is the difference between a
model that is merely correct and one that can be understood by the person using
it.

### What each entry says

| | |
| --- | --- |
| the corner's name | from [306](306-naming-a-block-and-a-corner.md) |
| what runs into it | the street runs meeting there |
| where each leads | the block on the far side of each |

Hovering an entry should glow the block it leads to, so the list and the map
explain each other. The glow already means *this one* and needs no new meaning —
see [507](507-the-glow.md).

### Unnamed corners still appear

Most corners will have no name for a long time. They are still connections and
still matter, so they are listed by what they join rather than omitted: *the
corner where the west lane meets Fishgate*.

Omitting them would make a block look less connected than it is, which is worse
than a clumsy description.

### Where it sits

In the scrolling text pane, with the block's other facts. It belongs with what is
known about a place rather than with the actions available there.

## Suggested implementation steps

1. From the selected place's derived boundary, collect the junctions at its
   edges' endpoints.
2. For each, find the edges naming that vertex and, for each edge, the other block
   naming it.
3. Render name — or a description built from what it joins — plus the destinations.
4. On hover, glow the destination block.
5. Test on the fixture crossroads that a block lists four corners and that the
   diagonal block is **not** among the destinations, since it shares only a vertex
   and not an edge — the same distinction tested in
   [203](203-adjacency-is-a-shared-edge.md).

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The tome](../docs/007-the-tome.md)
