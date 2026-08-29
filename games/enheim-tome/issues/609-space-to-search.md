# 609 — Space to Search

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 306, 601, 606 |
| Blocks | — |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | — |

## Current behavior

Reaching a place means finding it by eye and clicking it. Since the map carries no
labels, that means already knowing where it is.

## Intended behavior

Press **space** and type. The welded top becomes a search field, and reverts to
the filter controls when you are done.

### It is what pays for having no labels

The map carries no text of any kind — no names, no tooltips, nothing. That refusal
buys a great deal: the painting is undamaged, and label collision, a genuinely
hard problem that produces flickering mediocre results, never has to be solved.

**This is what it costs, and this is what repays it.** Without a way to reach a
place by name, a wordless map would be a map you can only wander.

### What is searchable

Every named thing: blocks, districts, quadrants, groups, intersections,
buildings, houses, and people.

**Searching a house resolves to its block**, because a house has no position of its
own — [407](407-a-house-has-no-geometry.md). So the positionless list stays
findable, which is the thing that makes it acceptable for houses to have no
geometry at all.

The same for a person: find the person, arrive at the block that holds the house
that holds them.

### Names are not unique

Two lanes in different quarters may share a name. So results are a **list**, each
saying enough to distinguish it — its containment chain, outward — and choosing
one goes there.

### Going there

Move the view to the place and select it. This is the one interaction that
**deliberately moves the camera**, which is why it works even when the thing you
want is at a zoom level you are not at — the friction named in
[408](408-the-zoom-picks-the-level.md), where selecting a district otherwise means
zooming out first.

Set the zoom so the place is comfortably framed, which for a quadrant is far out
and for a building is close in.

### Why space, and what it costs

Space is the largest, easiest key. The cost is that it cannot also be a pan
modifier, which it commonly is elsewhere — noted in
[104](104-pan-and-zoom-by-hand.md).

## Suggested implementation steps

1. On space, when no text field is active, take over the top region and focus a
   field.
2. Match against all named things; rank exact prefix matches first.
3. Show results in the text pane, each with its containment chain.
4. Selecting a result moves the view, frames the place, and selects it.
5. Escape restores the filter controls and changes nothing.
6. Test that a house's name reaches its block, and that two blocks sharing a name
   both appear and are distinguishable.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [What this game is](../docs/001-what-this-game-is.md)
