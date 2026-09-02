# 204 — The Identity Buffer

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 101, 102, 201, 209, 307 |
| Blocks | 205, 501, 505 |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | — |

## Current behavior

The painting draws. Nothing knows which place any pixel belongs to.

## Intended behavior

One offscreen image the size of the map pane, where **each pixel holds the integer
identity of the finest place covering it** — a building where building zones have
been placed, otherwise the block — and zero for ground nobody has defined.

Everything coarser resolves by walking the containment chain upward, which is a
lookup rather than a drawing: this pixel is in that building, therefore that
block, therefore that district, therefore that quadrant. **One buffer answers at
every level.** No district buffer, no quadrant buffer, nothing to keep in step.

### It earns its place twice

- **Hit-testing** becomes one pixel read, then a walk up the chain to whichever
  level the zoom has selected. No point-in-polygon tests, no spatial index, no
  bounding-box hierarchy. See [205](205-hit-testing-is-one-pixel.md).
- **Filter rendering** becomes a single pass over it — for each pixel, look up its
  place, look up that place's reading, evaluate the hatching, resolve the weave.
  See [505](505-the-weave.md).

Either use alone would justify building it. Having both is why it sits this early.

### Rebuilt whenever the view moves

Because it lives in screen space, it is remade on every pan and zoom — a few
thousand filled shapes, which is nothing for a graphics card even every frame
during a drag.

Screen space rather than painting space is deliberate. A painting-space buffer
would be 25 million entries whatever the zoom, most of it off screen, and would
need resampling to be read anyway.

### Precision

Identities are integers and must survive the round trip through whatever surface
holds them. Storing an index in a colour channel and reading it back is a
classic place to silently lose the high bits and start reporting the wrong
block. With around ten thousand buildings the identities need more than sixteen
bits of headroom; pick a format that carries them exactly and **test the round
trip at the largest identity**, not the smallest.

## Suggested implementation steps

1. Allocate an offscreen surface the size of the map pane, in an integer format
   wide enough for the largest identity with room to grow.
2. Clear to zero — undefined ground.
3. Fill every visible block's polygon with its identity, using the boundary walk
   from [201](201-vertices-edges-and-places.md).
4. Fill every visible building zone over the top, so buildings win where they
   exist.
5. Rebuild on any view change; skip the rebuild when nothing moved.
6. Cull to the visible rectangle so the cost follows what is on screen rather
   than the size of the city.
7. Test: write the highest identity in the network, read it back, assert equality.
   Then assert that a point known to be inside a fixture block reports that block.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [The places of the city](../docs/003-the-places-of-the-city.md) — the containment chain
