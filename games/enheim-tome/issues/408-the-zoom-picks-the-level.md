# 408 — The Zoom Picks the Level

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 104, 205, 401 |
| Blocks | 409 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

Hit-testing returns the finest place under the pointer. Nothing decides which
ancestor a click actually means.

## Intended behavior

Four levels can be selected — building, block, district, quadrant — and **the zoom
decides which**.

Far out, a click takes a quadrant. Descend and the same click takes a district,
then a block, then a building.

### Why there is no control for it

Because you aim by moving closer, which you were doing anyway. Adding a mode
selector would create a state you can be in without noticing, where a click does
something other than what the view suggests.

More importantly it costs nothing to implement, because it **reuses the rule that
already fades the cage**. A place draws its boundary when its on-screen width
crosses a threshold; a place is selectable when its boundary is drawn. So:

> **What you can select is exactly what you can see outlined.**

That is one rule wearing two hats, and it means the interface never has to explain
itself — the visible cage *is* the explanation.

### How it resolves

Hit-testing gives the finest place. Walking its chain outward gives its ancestors.
The level chosen is **the finest one whose boundary is currently drawn at full or
partial strength** — that is, whose on-screen width is above the lower fade
threshold from [207](207-each-boundary-fades-on-its-own-size.md).

Because the ragged chain means some places have no quadrant, this is a walk over
a list rather than an index into fixed levels. See
[401](401-the-containment-chain-is-a-list.md).

### The cost, stated

To select a whole district you must zoom out first, even when you already know
which one you want. That is a real friction and the reason the search exists —
naming a place reaches it regardless of zoom. See [609](609-space-to-search.md).

## Suggested implementation steps

1. Given the pointer, get the finest place and its chain.
2. Walk the chain from finest outward, taking the first whose on-screen width is
   at or above the fade threshold.
3. If none qualify — everything is tiny — take the outermost level available
   rather than returning nothing.
4. Expose the level that would be selected so the tome can show it and
   [303](303-the-pointer-shows-what-is-about-to-happen.md)'s equivalent in the game
   can outline it.
5. Test at three zooms on the same pointer position that the selection walks
   outward as you zoom out, and that a block beyond the wall skips straight from
   district to group without a branch.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [207 — each boundary fades on its own size](207-each-boundary-fades-on-its-own-size.md)
