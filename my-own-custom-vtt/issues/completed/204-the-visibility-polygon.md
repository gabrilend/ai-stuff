# 204 -- The visibility polygon

**Phase:** 2, the world can be seen
**Blocked by:** [203](203-the-angular-sweep.md)
**Blocks:** [205](205-the-fog-is-a-bitmap.md),
[404](404-one-function-writes-to-a-socket.md), and the renderer's lighting.
**Documents:** [sight and what it remembers](../docs/007-sight-and-what-it-remembers.md),
[the dynamic picture](../docs/012-the-dynamic-picture.md)

## Current behaviour

Nothing exists.

## Intended behaviour

The sweep's output, in a form that serves three consumers without favouring any of
them.

A **fan of wedges** out from the eye: an origin, then a run of boundaries, each
carrying an angle and the distance at which something stopped the light. Not a
bitmap, not a list of lit cells -- a polygon, because it is exact, and because it
is small enough to put on a socket.

### The three consumers, which is why the shape matters

| Consumer | What it needs |
| --- | --- |
| [The fog](205-the-fog-is-a-bitmap.md) | Which cells are inside it. A rasterisation. |
| [The outbound filter](404-one-function-writes-to-a-socket.md) | Is this point inside it -- asked once per candidate thing, per viewer, per tick. |
| The renderer | The polygon itself, sent whole, so it can draw a clean edge between torchlight and dark. |

The third one is the reason it stays a polygon rather than becoming a cell mask
somewhere in the middle of the pipeline. **The geometry that made the fog secure
is the geometry that makes it look good** -- see
[strategems](../strategems/patterns-that-keep-working) -- and converting to cells
early would throw that away to save nothing.

### Point-in-polygon has to be fast, not general

The filter asks "is this point inside" for every candidate thing for every viewer
every tick, so this is a hot query and it is not a general one. The fan is sorted
by angle, so the answer is: binary search for the wedge containing the point's
angle, then one distance comparison. Logarithmic, no allocation, no traversal.

That only works because the fan is angularly sorted, which it is because the sweep
produced it in angle order. Anything that reorders the fan destroys this, and that
is worth a comment on the structure rather than on the query.

## Suggested implementation steps

1. Define the fan. A fixed-capacity buffer sized at startup, not a growing list --
   the maximum boundary count is bounded by the segment count the broad phase can
   return.
2. Emit it from the sweep in angle order.
3. Write the point-in-polygon query as a binary search plus one comparison, and
   comment the sortedness it depends on.
4. Write the rasteriser that [205](205-the-fog-is-a-bitmap.md) needs, as a separate
   function -- the fan does not know what a cell is.
5. Write the wire form: what the renderer receives. Keep it the same structure, not
   a second representation, so there is no conversion that can disagree with the
   original.
6. Write the companion `.info.md`.
7. Test the query against the rasteriser: for a sample of points, assert that
   "inside the polygon" and "in a set cell" agree except within one cell of the
   boundary. Two independent implementations of the same question is how this class
   of bug is found.
