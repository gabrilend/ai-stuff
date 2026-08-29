# 304 — Snapping Is Measured on the Screen

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 301 |
| Blocks | 302, 305 |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | — |

## Current behavior

Nothing snaps.

## Intended behavior

The grab radius is a fixed distance **in screen pixels** — around eight — and
therefore covers a large area of painting when zoomed out and a tiny one when
zoomed in.

That is correct rather than a compromise. It matches **how precisely a person can
actually point at that moment**. A radius fixed in painting pixels would be
unusably tight when zoomed out and absurdly grabby when zoomed in, which is
exactly backwards.

### The consequence, and the refusal it demands

At the whole-city view an eight-pixel radius covers roughly forty painting
pixels. At that zoom, snapping will happily grab the wrong vertex, and placing a
new one lands it forty pixels from where you meant.

So the tool **refuses to place or drag vertices below some zoom**. Not a warning —
a refusal, with the reason said plainly and the zoom you need named.

The alternative is imprecise work that looks fine until somebody zooms in a week
later, which is the same class of fault as a silent mis-snap and just as
expensive.

The floor comes from `input/what-to-start-with`, and it wants feeling rather than
reasoning.

### What is snappable

Vertices, and the nearest point on an edge. When both are within the radius, **the
vertex wins** — adopting a corner is almost always what was meant when you are
near one, and adopting an edge that happens to pass near a corner is almost never
what was meant.

## Suggested implementation steps

1. Convert the radius once per frame into painting units by dividing by zoom;
   search in painting space, since that is where the network lives.
2. Find candidate vertices within it, then candidate edges; prefer the vertex.
3. Break ties between vertices by nearest, and record the distance so
   [303](303-the-pointer-shows-what-is-about-to-happen.md) can show which one won.
4. Gate placing and dragging on the zoom floor; on refusal, say the current zoom
   and the zoom needed.
5. Test that the same screen distance snaps at 0.3 and at 1.0 — the property is
   that the *hand* behaves identically, not the coordinates.

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [208 — the network validator](208-the-network-validator.md) — which catches near-duplicate vertices when this fails
