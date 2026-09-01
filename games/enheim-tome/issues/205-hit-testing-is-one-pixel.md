# 205 — Hit-Testing Is One Pixel

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 204 |
| Blocks | 207, 408, 507 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — *(was question 2; answered)* |

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

The glow may follow the pointer at high zoom — see
[508](508-the-glow-flips-to-aiming.md) — and the tome shows what is under it. So
this runs continuously, which is another reason it must be a read rather than a
search.

It is no longer needed for the cage. An earlier design drew whatever was under
the pointer at full strength to rescue places too small to see; with the cage
showing one level uniformly, nothing at that level is ever too small.

### The pointer outside the map

A position in the tome pane is **not a position on the map**. The clip established
in [103](103-the-window-and-its-two-panes.md) makes that structural; this must
respect it and report nothing rather than clamping to the map's edge, which would
make the outermost blocks selectable by pointing at the tome.

### Every pixel of the painting is somewhere

**There is no undefined ground.** The city is subdivided rather than filled in,
so coverage is always complete — see
[the fence network](../docs/004-the-fence-network.md). A click anywhere on the
painting lands on some place, however coarsely divided that part of the city
still is.

What remains off-map is genuinely off-map: **the letterbox** above and below the
painting at the fit zoom, about 57 pixels at a 1600 by 900 window.

There, the click is **ignored and the selection stays as it was**, under one
sentence: *input that is not on the map cannot affect the selection of things in
the map.*

This also means there is no way to deselect by clicking away. Selecting something
else is how you stop looking at a thing, and the tome always has something in
it.

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
