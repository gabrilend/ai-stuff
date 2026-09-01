# Drawing A Pile Of Stones

The renderer never draws a block. It draws **faces**, and a face is a
disagreement between one column and its neighbour.

## What a column contributes

Walk the column's bits from the bottom up and break them into **runs** of
consecutive stone. A plain pile of eight blocks is one run, from layer 0 to
layer 7. A pile with a tunnel bored through it is two runs. Air contributes
nothing.

For each run, three faces may be drawn, and each one is a flat four-sided
polygon:

| Face | Shape on screen | Drawn when |
| --- | --- | --- |
| **top** | a diamond, `2 × half_width` across and `2 × half_height` tall | always, at the run's topmost layer |
| **right** | a parallelogram going down-right | the neighbour at `x+1` does not have stone there |
| **left** | a parallelogram going down-left | the neighbour at `y+1` does not have stone there |

The other two sides and the underside face away from the viewer and are never
considered. That is the whole benefit of a fixed camera angle, and it is
two-thirds of the geometry gone for free.

The exposed height of a side face is not the run's height — it is the part of
the run the neighbour does not cover. Given this column's run and the
neighbour's stone bits, the exposed layers are `run & ~neighbour`, and the face
is drawn only over those. Two identical columns side by side have `run &
~neighbour` equal to zero between them and draw no face at all, which is why a
large solid terrace costs the same to draw as its outline.

## Three tones and where they come from

Light comes from the upper left, as it does in the reference picture. Three
tones, applied per face:

| Face | Tone |
| --- | --- |
| top | full brightness |
| left | about three quarters |
| right | about half |

Nothing is computed per-pixel and there is no normal vector anywhere. The angle
of every face in the world is one of exactly three values, known at the time the
projection was chosen, so the shading is a lookup with three entries. A lighting
model here would be arithmetic performed to rediscover a constant.

The base colour varies slightly per cell, drawn from a hash of the cell index
rather than from a stream — so the stone is mottled, the mottling is stable
across frames, and it costs no memory and no draws from the
[named streams](005-randomness-comes-from-named-streams.md). A hash is used
rather than a stream precisely because the renderer must not be able to move the
simulation.

## The order things are drawn in

Back to front, one linear sweep of the column array, as
[the projection](006-the-isometric-projection.md) explains. Within one column,
runs are drawn bottom-up, and within one run the two side faces are drawn before
the top face.

Bodies are the awkward case. A body standing on a surface must be drawn after
everything behind it and before everything in front, and "everything" includes
the column it is standing on. So bodies are **bucketed by cell** before the
sweep starts — one pass over the body store, each body dropped into the bucket
for its cell — and the sweep draws a column's faces and then whatever bodies are
in that column's bucket.

That bucketing pass is the only place in the renderer that touches the body
store, and it is a scatter into a preallocated array of counts and offsets
rather than a table of lists, so it allocates nothing per frame. A renderer that
allocates per frame is a renderer that stutters every time the garbage collector
notices.

## What the outline is for

Every face gets a thin darker edge along its boundary. Without it a wall two
layers tall next to a wall three layers tall is two shades of the same grey with
an invisible seam, and the maze reads as a flat noisy texture rather than as
geometry. The reference picture solves this with drawn linework, and the outline
is the cheapest thing that does the same job.

The outline is drawn as part of the face, not as a second pass, because a second
pass over the same faces doubles the sweep and the whole point of the linear
sweep is that it happens once.

## What is not drawn

- **Anything buried.** A block with stone on all four sides and stone above
  contributes no faces at all, and is never visited beyond the bit test that
  says so.
- **Anything outside the window.** See the culling note in
  [the projection](006-the-isometric-projection.md).
- **The jungle.** The reference picture surrounds the maze with ferns, palms,
  volcanoes and a sky. None of that is in the program and none of it is planned
  for the early phases. It is scenery, it has no simulation behind it, and it
  would be the single largest source of art assets in a project that currently
  has none. It is recorded in [open questions](026-open-questions.md) rather
  than quietly dropped.

## Related documents and tools

- [The isometric projection](006-the-isometric-projection.md) — where each face lands
- [Seeing it without a window](009-seeing-it-without-a-window.md) — the same maze, no pixels
