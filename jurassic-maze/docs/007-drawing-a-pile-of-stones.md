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

## The stone is baked once

The stone does not change, so the faces are turned into geometry **once**, at
load, and the camera is applied as a transform afterwards. Panning and zooming a
hundred thousand polygons then costs two numbers.

Rebuilding the geometry per frame would be a hundred thousand polygons of work to
produce a picture identical to the last one, and — worse — it would allocate,
and a renderer that allocates per frame stutters every time the collector
notices, correlated with nothing anybody can see.

When a golem starts breaking walls in phase seven, the rebuild happens on the
stone's version counter rather than every frame. The counter exists now, and is
never bumped, precisely so that the first thing to change the stone cannot forget
it.

## The order things are drawn in, and where bodies go

Back to front, which is band by band: cells sharing one value of `x + y` lie
across the screen and none can occlude any other.

Bodies are the awkward case, and they are why the band order exists at all. A
body must be drawn after everything behind it and before everything in front, and
"everything" includes the wall in front of the corridor it is standing in. A
single mesh is drawn all at once, so a body drawn afterwards sits on top of the
entire maze.

So the mesh records, for each band, the range of its geometry, and the frame
draws: band's stone, band's bodies, next band. Two draw calls per band and no
geometry rebuilt.

The bodies are grouped into bands by a sweep over the body store into reused
arrays — nothing allocated per frame — and that sweep is the only place in the
renderer that touches the body store at all.

## What the outline is for, and which edges get one

Without linework a wall two layers tall next to a wall three layers tall is two
shades of one grey with an invisible seam, and the maze reads as a noisy texture
rather than as geometry. The reference picture is drawn linework over flat
colour and reads as stone because of it.

The scheme is two meshes and no line drawing at all. The faces tile without gaps,
so a mesh of full-size faces in the outline colour is completely hidden by a mesh
of **inset** faces drawn on top — except along whichever sides were pulled in,
where the gap exposes a line of it. Two draw calls for the whole maze's linework.

**Which sides get pulled in is the part that matters.** Insetting all four is
what a naive reading of "outline every face" gives, and it draws a line between
every pair of neighbouring cells — including two cells of one long wall whose
tops are the same continuous slab of stone. With those lines in, the maze stops
reading as corridors between walls and starts reading as a field of separate
cubes; it was the single largest visual error in the first working renderer, and
nothing about it showed up in any number.

So a side is inset only when it is a real edge: a top face's side, only where the
neighbour's floor is not at exactly this layer; a wall face's vertical side, only
where the neighbour's exposed run does not match. The reference picture has
linework everywhere and none of it is the line between two cells of one wall.

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
