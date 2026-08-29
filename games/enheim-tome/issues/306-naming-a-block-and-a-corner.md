# 306 — Naming a Block, and a Corner

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 202, 301 |
| Blocks | 608, 609 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

Blocks can be traced. They have no names, and corners are anonymous geometry.

## Intended behavior

Two naming acts, and the second one turns a piece of geometry into a piece of the
world.

### A block gets a name

Prompted immediately on closing a loop, because an unnamed block is unreachable
by search and unnameable in the tome, and a thousand of them named "later" is a
day's work nobody will do.

Names need not be unique — two lanes in different quarters may share one — so
search must be able to offer a choice. See [609](609-space-to-search.md).

### A junction becomes an intersection

**A junction is where edges happen to meet. An intersection is a junction somebody
has named**, and naming it is what makes it a thing the game can talk about.

This matters because of what nearness is in this game:

> The connections are what's nearby.

Not distance — which street runs lead where, and what they reach. So a corner is a
place you can say something about, and a block's borders are a list of named
corners rather than an anonymous outline. The tome lists them, each with
everything it connects to. See [608](608-the-intersections-listed.md).

Naming a corner is **optional and later**. A block is usable with anonymous
corners; naming them is enrichment, done on a return visit, like most of what
this tool does.

### Where names are shown

Nowhere on the map. The map carries no text of any kind. Names appear in the
tool's own pane, and in the game only in the tome.

The tracing tool is not bound by the no-text rule — it is an instrument, not a
product — but it should still avoid writing across the painting while tracing,
because obscured roofs are the thing being traced.

## Suggested implementation steps

1. On loop close, focus a name field; do not let the block be committed nameless.
2. Provide a way to rename a selected block, and to list every unnamed block so
   the backlog is visible rather than discovered.
3. Add a naming action for the junction under the pointer, which writes a row in
   the intersections table pointing at that vertex.
4. Derive each intersection's connections from the edges naming its vertex — do
   not store them, since they change whenever the network does.
5. Have the validator count unnamed blocks and report them.
6. Test that naming a junction and then dragging it keeps the name attached, since
   the name belongs to the intersection and the position belongs to the vertex.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The places of the city](../docs/003-the-places-of-the-city.md)
