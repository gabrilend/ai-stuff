# 701d — one canvas, two spaces

Part of 701. Depends on: 701b, 701c. Blocks: 701f, 701g.

## Current Behavior

The 2D painter fills a float **light buffer** (`src/000-canvas.lua`):
particles add light in pixels, the buffer is tone-mapped, and the result is
indexed into the seven-hue palette. Positions are pixels from the top-left
corner, y growing downward (`docs/score-format.md`, Shapes).

The 3D painter fills a **colour and depth buffer** (`raster.lua`): meshes are
projected through the camera, lit, given glowing edges, smoothed two by two,
and blobs are ray-marched per pixel. Positions are world units, y upward.

Each writes its own GIF. Nothing puts both in one frame.

## Intended Behavior

One score, one `canvas{}`, any mix of the two vocabularies, and **2D is
painted onto panes of glass**. Her answer to where a 2D stroke sits among 3D
shapes:

> we'd make a glass pane that's fully transparent and paint onto that.
> That's how game engines do it.

A **pane** is a flat, fully transparent rectangle with its own pixels. 2D
strokes are painted onto a pane in the pane's own screen-space coordinates
(pixels from its top-left corner, y down, exactly as a 2D score is written
today). Where the pane sits decides everything else:

- **Fixed to the camera**, at the front: a heads-up layer, like a game's
  interface. It always faces the viewer and covers the whole frame. This is
  the default, and a score with only 2D strokes is one such pane, rendering
  byte-identical to today.
- **Fixed to the camera**, at the back: a backdrop behind every shape.
- **Placed in the world**: a pane with a position, a facing and a size in
  world units. It is drawn like any other surface, so it has depth: a shape
  in front of it hides it, a shape behind it shows through its clear parts,
  and a stroke can sit *between* two shapes by sitting on a pane between
  them.

    canvas{ size = 320, fps = 20, length = 4.0, seed = 7, background = "sky" }
    camera{ eye = {0, 2, 7.5}, target = {0, 0, 0}, fov = 44 }
    shape{ mesh = "jellyfish", at = {0, 0, 0}, motion = "drift" }
    pane{ name = "sign", at = {0, 1, -2}, facing = {0, 0, 1}, size = {3, 3},
          pixels = 256 }
    stroke{ pane = "sign", at = 0.5, lasts = 2.0, shape = arc{
            center = {128, 128}, radius = 90, from = 12, to = 6,
            turn = "clockwise" } }
    stroke{ at = 1.0, lasts = 1.0, shape = point{ at = tip("jellyfish") } }
                                    -- no pane named: the front pane

- **The background is the score's to say**, in `canvas{ background = ... }`:
  black, a colour, or the 3D sky. Her answer: *"whatever's defined in the
  script that generates that particular gif."* Nothing is chosen for the
  score.
- **Light adds.** A pane is clear where nothing is painted. Where it is
  painted, its glow adds brightness to whatever is behind it rather than
  covering it, the way glow already works in the 2D painter.
- **Landmarks cross over**: `tip("jellyfish")` on a front pane means where
  that shape appears on screen this frame, so a line of light can follow
  something in the world.
- **Each frame**: the 3D shapes and the world panes are drawn into colour
  and depth together, the camera's panes are laid in front or behind, then
  everything is tone-mapped once, quantised once through the one palette,
  and encoded once.

A score with only 3D shapes renders byte-identical to the film it was ported
from.

**Not in this phase: painting onto curved surfaces.** A pane is flat. Paint
that wraps a mesh (a texture on a brick, a pattern on the jellyfish's bell)
needs every mesh to carry a map from its surface to a picture's pixels.
That is a further step, which panes make easier rather than replace.

## Suggested Implementation Steps

1. Define the frame (colour, depth and light, sized by the canvas) and the
   pane (its own light buffer, and a placement: front, back, or in the world).
2. Teach the 3D painter to draw into it, and the 2D painter to add light to
   it, each unchanged otherwise.
3. Write the composer: the back panes, then the shapes and world panes
   together with depth, then the front panes, then tone-map, then quantise.
4. Let the wall accept both vocabularies in one score, and add `camera{}`,
   `shape{}`, `pane{}` and `background` beside `stroke{}`.
5. Add the cross-over landmark: a 3D shape's projected point, per frame.
6. Prove the two byte-identity promises above, then render one mixed scene.

## Open Questions

1. **Are two layers enough? — ANSWERED. Panes instead.** A stroke goes
   wherever its pane goes, including between shapes. Her words above.
2. **Whose background wins? — ANSWERED. The score's.** Her words above.
3. Should a world pane be able to turn to face the camera every frame (a
   sign that always reads straight on) as well as hold a fixed facing?
