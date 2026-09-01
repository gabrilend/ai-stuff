# 402 — Smoothing Belongs To The Renderer

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 202, 401 |
| Blocks | nothing |
| Reads | [walking the surface graph](../docs/014-walking-the-surface-graph.md) |
| Open questions | none |

## Current behavior

`Walking.drawn_position`, called by the renderer and by nothing else. The arc on
a vertical step is there, scaled by the layer difference so a flat step gets
none.

The grep test asserting that no simulation file calls it is not written. The
layering test already greps for the engine, `math.random` and the camera stream
over every file under `src/`, and this is one more row in it.

## Intended behavior

The drawn position of a walking body is its two surfaces interpolated by
`progress`. **The simulation never reads this.** The interpolation happens in
the renderer, once, at draw time, and no decision anywhere depends on it.

That separation is the whole reason the smoothed graph walk was chosen over
continuous motion for these bodies: the simulation gets a graph, which is cheap
and exact, and the eye gets smoothness, which is a lie the renderer tells.

A **vertical step needs an arc**. Interpolating a one-layer climb in a straight
line makes the body slide up a diagonal, which reads as ascending an invisible
ramp rather than climbing. A small hump added to the interpolated height, peaking
at the middle of the step, fixes it.

The arc is a cosmetic hack living entirely in the renderer, and it is written
down because it is exactly the kind of thing somebody tidying up will delete
without knowing why it is there — after which the little guys look wrong and
nobody can say what changed.

## Suggested implementation steps

1. Write `drawn_position(bodies, id)` in the renderer, returning fractional x, y
   and height.
2. Add the arc as a function of `progress` scaled by the layer difference, so a
   flat step gets no arc at all.
3. Assert in a test that no file under `src/` outside the renderer calls this
   function. A grep test, like the engine one.
4. Compare a recorded screenshot before and after adding the arc, and keep both
   in the phase demo, because the difference is the clearest single illustration
   of what "smoothed for the eye" means.

## Related documents and tools

- [Walking the surface graph](../docs/014-walking-the-surface-graph.md)
- [Drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md)
