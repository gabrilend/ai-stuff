# 602 — The dunes draw themselves

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 102, 112, 601 |
| Blocks | 610 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. The field is designed as a heightfield raised by a tool (issue 102),
territory as an owner per cell (issue 112), and the terminal viewer (issue 111)
as the only thing that draws either — as characters graded by height. No window
draws the ground.

## Intended behavior

The dunes are drawn from the heightfield directly, and nothing about how they
look is stored anywhere but in the numbers the tool raised. Two layers, drawn by
two functions, one of which is a picture that never changes and one of which
changes every tick.

**The ground is shaded once.** When a field arrives — at load, and never again,
because the heightfield is read-only for the whole match — a shading function
turns it into one image: each cell's colour from its height band, darkened or
lit by the slope's facing against a fixed light direction so that a crest reads
as a crest and a windward face as a face, the water line drawn as a hard edge
with the cells below it in the sea's colour, and hydrocarbon cells marked. The
image is generated data; the lens only ever blits it, scaled and cropped to the
lens's rectangle. That is generate-then-view applied to a picture: the shader
is a function from heightfield to pixels that a test can run with no window at
all and check a pixel of.

**Territory is a tint that changes.** Every frame, the territory layer draws
each owned cell as a translucent tint in its team's colour over the ground,
from the newer snapshot. Cells with a claim in progress are drawn with a thinner
tint that grows with the claim's progress — the pair of integers, read off the
snapshot — so that a player can watch ground turning. Contested cells are drawn
with both tints halved, which is what they are.

The two layers are rows in the lens's layer table (issue 603): a lens showing
the dunes shows the ground; a lens showing territory shows the ground with the
tint over it. Neither layer knows about units.

The look is deliberately plain — shading by height and slope, which is enough to
read the ground — because the generated tileset (issue 610) is the thing that
makes the dunes look like a place, and it lands later, on top of a layer that
already works.

## Suggested implementation steps

1. Write the shader as a numbered source file: a function from a field (issue
   102's record) to an image's pixel data, with the light direction, the height
   bands, and the palette as a table at the top of the file rather than in the
   loop. Folded, with a comment saying why the light comes from where it does.
2. Write the ground layer's draw function: blit the shaded image through the
   lens's transform (issue 603's `to_screen`), cropped to the lens rectangle.
3. Write the territory layer's draw function: walk the snapshot's owner array
   for the cells the lens can see, and draw a tinted rectangle per cell. Walk
   only the visible cells — the lens knows its field extent — because walking
   the whole field for a lens showing a corner of it is the slowest thing a
   viewer can do.
4. Draw the claim-in-progress tint from the cell's claim increment against the
   snapshot's claim counter, and the contested state as both tints halved.
5. Register both as rows in the layer table.
6. The test: the shader, given the test field, returns pixel data whose
   dimensions match the field; a cell below the water line is the sea's colour;
   a cell on a crest is lighter than the same height on a lee face. No window is
   opened by the test.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the layers, and generate-then-view.
- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) —
  what the heightfield holds and how it is raised.
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — what
  an owned, claiming, or contested cell is.
- Issue 102 (the field), issue 112 (the owner array and the claim pair), issue
  603 (the lens transform), issue 610 (the tileset that replaces the plain
  shading).
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether the shaded image should be one texture for the whole field or a grid
  of tiles, which decides how a very large field fits in graphics memory.
  Decided by the field size in group B of the open questions, which is awaiting
  evidence.
