# 205 -- The fog is a bitmap

**Phase:** 2, the world can be seen
**Blocked by:** [204](204-the-visibility-polygon.md)
**Blocks:** [404](404-one-function-writes-to-a-socket.md), and the rollback
question in phase 3.
**Documents:** [sight and what it remembers](../docs/007-sight-and-what-it-remembers.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One fog record per viewer: a bitmap over a coarse cell grid, one bit per cell, set
the first time any part of that cell falls inside the viewer's visibility polygon,
**never cleared**.

Sight and memory are different things and this file is memory. Sight is
recomputed from scratch every tick and never stored. Memory accumulates forever
and is never recomputed. A corridor you walked an hour ago is in one and not the
other, and that difference is the difference between a floor plan you remember and
a goblin standing in it now.

### Why a grid, when the whole project insists the map is not a grid

Because memory is approximate by nature, and the two grids are answering different
questions.

- **The rules grid**, if a ruleset has one, decides *where things may stand*. That
  is a constraint on the world, and it is deliberately kept out of the world.
- **The memory grid** decides *how finely we record having-been-somewhere*. Nobody
  needs millimetre precision on "have I been down this corridor".

Quantising turns an unbounded polygon-union problem into setting bits, and setting
bits is free. The two grids need not be the same size and neither knows the other
exists. Both of those sentences belong in the source.

### Size

One cell per world metre, from configuration. A map a hundred and twenty metres
across is about fourteen thousand bits -- under two kilobytes per viewer. Twelve
people cost less than a photograph.

At that price the argument for coarser cells has evaporated, and the remaining
question is whether a metre is too *coarse*: a cell set because one corner of it
fell inside your vision claims you remember a square metre of floor you barely
saw. See [2.1](../docs/016-open-questions.md).

### Rollback reaches into this file

Phase 3 can take a turn back. Whether the fog goes back with it is
[3.3](../docs/016-open-questions.md) and it is not settled -- but **whichever way
it goes, this file has to be able to do it**, which means a fog record must be
snapshottable and restorable exactly like the world is.

Since it is already a flat block of bits, that is a block copy, and it costs
nothing to build in now. Building it in later means finding every place a bitmap
is touched.

## Suggested implementation steps

1. Allocate one bitmap per viewer at the size the world implies, at load. It never
   grows, because the world's extent does not change during a session.
2. Write the fold: rasterise a visibility fan and OR it into the bitmap. Use
   [204](204-the-visibility-polygon.md)'s rasteriser rather than writing a second
   one.
3. Write the query: is this cell set. One shift and one mask.
4. Write snapshot and restore as block copies, for rollback.
5. Write the companion `.info.md`.
6. Test: walk a body down a corridor a step at a time and assert the set-bit count
   only ever increases. Then snapshot, walk further, restore, and assert the count
   is back where it was.

## A note on what this is really for

It looks like a drawing feature and it is not. The outbound filter uses it to
decide which *walls* a viewer may be sent, which makes it part of the security
boundary rather than part of the picture. See
[what a viewer is allowed to know](../docs/009-what-a-viewer-is-allowed-to-know.md).
