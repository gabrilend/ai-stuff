# 205 — Hit-Testing Is One Pixel

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 204 |
| Blocks | 207, 408, 507 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | **2** — what a click on undefined ground does |

## Current behavior

The identity buffer exists. Nothing consults it.

## Intended behavior

Asking what is under the pointer is **one pixel read**, then a walk up the
containment chain to whichever level the zoom has selected.

```
   pointer position in the map pane
              │
              ▼
   read one pixel of the identity buffer
              │
              ▼
   an identity: a building, a block, or zero
              │
              ▼
   walk up the chain to the level the zoom wants
              │
              ▼
   the place the click means
```

That is the whole thing. No polygon tests, no spatial grid, no quadtree. It costs
the same whether the city has four blocks or four thousand, which is the property
that matters given the city will have around two thousand blocks and ten thousand
buildings.

### It must answer every frame, not only on click

Hover feedback depends on it — the fence under the pointer draws at full strength
regardless of size, per [207](207-each-boundary-fades-on-its-own-size.md), and the
glow may follow the pointer at high zoom. So this runs continuously, which is
another reason it must be a read rather than a search.

### The pointer outside the map

A position in the tome pane is **not a position on the map**. The clip established
in [103](103-the-window-and-its-two-panes.md) makes that structural; this must
respect it and report nothing rather than clamping to the map's edge, which would
make the outermost blocks selectable by pointing at the tome.

### Undefined ground

Identity zero means nobody has defined this ground — mountains, fields, sea, the
foreground ridge, and everything not yet traced.

**Working ruling, not a decision:** a click there deselects, and nothing glows.

The alternative — bare ground doing nothing, so the current selection survives —
feels quite different in the hand and also says something about whether the far
countryside is *outside the game* or merely *not yet traced*. See
[open questions](../docs/012-open-questions.md), question 2.

## Suggested implementation steps

1. Convert the pointer to map-pane coordinates; return nothing if it is outside.
2. Read the identity at that pixel.
3. Resolve upward to the level the current zoom selects — see
   [408](408-the-zoom-picks-the-level.md).
4. Cache the result per frame; several things ask the same question each frame and
   the answer cannot change within one.
5. Implement the working ruling for identity zero, and mark it in the source as a
   ruling rather than a decision, naming the open question.
6. Test that a point on a known building reports the building at close zoom and
   its block at a wider one.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [Open questions](../docs/012-open-questions.md) — question 2
