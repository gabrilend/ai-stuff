# 104 — Pan and Zoom by Hand

| | |
| --- | --- |
| Phase | 1 — The Canvas |
| Blocked by | 102 |
| Blocks | 302, 408 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | **1** — the bindings are not settled, and the tracing tool must agree |

## Current behavior

The view can be moved by setting its three numbers. Nothing moves it in response
to a hand.

## Intended behavior

**Working ruling, not a decision:** drag to pan, wheel to zoom about the pointer.

### Zoom is anchored to the pointer

The painting pixel under the cursor **stays under the cursor** as the zoom
changes. Anything else feels like the city is sliding away from what you are
looking at.

Mechanically: note the painting point under the pointer before the change, apply
the new zoom, then set the pan so that point maps back to the same screen
position. This is two calls to the conversions in
[102](102-the-view-is-an-offset-and-a-scale.md) and a subtraction, and it is the
difference between a view that feels attached to your hand and one that does not.

### Zoom steps are multiplicative

Each notch multiplies rather than adds. Adding a constant makes the zoom crawl
when far out and leap when close in; multiplying gives the same felt step
everywhere. The range is only five-fold, so the step can be gentle.

### The conflict to be careful of

The tracing tool shares this code but not this meaning. There, a drag beginning
on a vertex **moves that vertex**, not the map. The two programs must not disagree
about what an unqualified drag on empty ground does, or muscle memory carries a
mistake from one to the other.

The working ruling: **drag on empty ground pans in both programs**, and the
tracing tool takes over a drag only when it begins on something grabbable. See
[303](303-the-pointer-shows-what-is-about-to-happen.md), which is what makes that
distinction visible before the press.

### What space is not

**Space is taken** by the search — see [609](609-space-to-search.md). It is not a
pan modifier here, however common that is elsewhere.

## Suggested implementation steps

1. Drag with the primary button on the map pane pans, by the screen delta divided
   by zoom.
2. Wheel multiplies the zoom by a constant per notch, anchored at the pointer.
3. Clamp after every change, pan and zoom both.
4. Keep the binding table separate from the behaviour, so the tracing tool can
   reuse the behaviour and supply its own table.
5. Confirm by eye that a building under the cursor stays under the cursor across
   the full zoom range, at several points including the far corners of the
   painting.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [Open questions](../docs/012-open-questions.md) — question 1
