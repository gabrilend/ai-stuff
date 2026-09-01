# 103 — The Window and Its Two Panes

| | |
| --- | --- |
| Phase | 1 — The Canvas |
| Blocked by | — |
| Blocks | 102, 601 |
| Reads | [the map surface](../docs/002-the-map-surface.md), [the tome](../docs/007-the-tome.md) |
| Open questions | — |

## Current behavior

Nothing exists.

## Intended behavior

The window is **permanently split** into a map pane and a tome pane, and neither
ever covers the other.

```
┌────────────────────────────┬─────────────────────┐
│                            │                     │
│   the map pane             │   the tome pane     │
│   pans and zooms           │   ~420 wide,        │
│   gets the rest            │   fixed             │
│                            │                     │
└────────────────────────────┴─────────────────────┘
```

The tome takes a **fixed width** — around 420 pixels — and the map gets whatever
remains. Not a percentage: the tome holds text at a readable size, and text does
not want to be a proportion of a window. A wider display should give you more
city, not wider paragraphs.

Both figures come from `input/what-to-start-with` rather than the source.

### Why permanent, and what it costs

It costs about a quarter of the window forever. It buys a game where the drawn
half and the written half are always both in sight, which for a game about
understanding a city rather than commanding one is the right trade. The map is
never covered by a panel; the tome never has to be summoned.

### The seam

A visible division, one or two pixels, so the two halves read as two surfaces
rather than one surface with a busy right edge. Whether it can be dragged to
re-proportion the split is not decided and is not needed for this phase.

### The tome pane stays empty until phase 6

Nothing is drawn in it — not readouts, not debug figures, not a placeholder. An
empty panel, honestly empty, for five phases.

The reason it exists this early rather than being introduced when it has content:
**every visual judgement made before then is made at the real proportions.** How
the cage reads, how hatching sits, whether the whole city is legible at the fit —
all of those are judgements about a 1180-wide pane, and making them against a
full-width window would mean re-making them later.

The cost is that a quarter of the window does nothing for a long time, and that
during the tracing campaign there is no readout of where the cursor is in
painting coordinates. That is accepted: the tracing mode is a different state of
the same window and may fill the pane with whatever it likes.

### Resizing

On resize, the tome keeps its width and the map pane absorbs the change. Since
the map's zoom floor is derived from its pane width, a resize recomputes the
floor and may need to raise the current zoom to stay above it — see
[102](102-the-view-is-an-offset-and-a-scale.md).

## Suggested implementation steps

1. Read window size and tome width from the input directory at startup.
2. Compute the two pane rectangles; expose them as the only source of truth for
   where either half lives.
3. Set a scissor or equivalent clip on each pane so neither can draw into the
   other. This is what makes "never covers" a property of the program rather
   than a promise.
4. Draw the seam.
5. On resize, recompute both rectangles and notify the view so it can redo its
   zoom floor.
6. Test that a pointer position in the tome is never reported as a position on
   the map, at several window sizes.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [The tome](../docs/007-the-tome.md)
