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

## What Happened

Built 2026-10-30 on the branch `claude/701d-one-canvas-two-spaces`. All
six steps are done; the issue stays open for a look on her machine and
for open question 3.

- **The frame and the pane (step 1).** A pane is its own light buffer
  (a `000-canvas`) and a place: `front`, `back`, or `world` (at, facing,
  size in world units, pixels across). There is always a front pane,
  named `front`; a stroke that names no pane is painted there.
  `src/052-frame.lua` holds the frame's three moves.
- **Both painters, unchanged (step 2).** The 3D painter's frame body
  moved, unchanged, into `frame.draw_world`, and the shape films draw
  through it too. The 2D painter paints each pane exactly as it painted
  a canvas; each pane has its own pool and random stream, and the front
  pane keeps the canvas's seed.
- **The composer (step 3).** `frame.gather_pane` lays a world pane into
  the depth: each subpixel looks along its ray, and where it meets the
  pane nearer than the surface drawn there (or where nothing is), it
  gathers the pane's light. `frame.compose` sums the gathered light, the
  back panes' light where nothing is drawn, and the front panes' light,
  tone-maps the sum once, adds it to the 3D colour, and indexes once.
  One choice to know: the 3D painter's colour is already display colour
  (lit, edged, 0 to 1), not light energy, so "tone-mapped once" applies
  to the panes' light, which is then added on top. With no light a pixel
  is exactly the 3D painter's; with no world, exactly the 2D painter's.
- **One score, both vocabularies (step 4).** The score reader takes
  `camera{}`, `world{}`, `shape{}` and `pane{}` beside `stroke{}`, and
  `canvas{}` takes `background` (`"black"`, a hue's dark glow, or
  `"sky"`, the world's stars) and `frames` in place of `length` (a loop
  of shapes counts frames). The 3D words are exactly the shape scenes'
  words: `shape{}` is one entry of a scene's `instances`, `camera{}` its
  camera, `world{}` the rest (lights, ground, beams...). The issue's
  sketch (`camera{ eye, target }`, `motion = "drift"`) is said in those
  words instead. The 2D wall and the 3D wall judge a score in one pass:
  `tests/two-spaces/broken.lua` has twelve mistakes across both spaces
  and hears of all twelve at once. The writer writes all of it, 3D
  numbers exactly.
- **Landmarks cross over (step 5).** `tip("tag")` naming a shape is
  where that shape appears in the picture each frame; a point or a line
  on a camera's pane follows it. A fill's corners stand still and a
  world pane does not see the picture, so neither may follow a shape.
- **The proofs (step 6).** `src/054-two-spaces-test.lua` (38 checks, in
  `./test-shape-films`, now 278 of 278): the four stroke-only scores in
  `input/` film the bytes they filmed before panes; each of the six
  approved films, said as a score, films its approved bytes; a pane
  hides behind a nearer shape and nowhere else. All 34 shape films still
  film byte-identical. `tests/two-spaces/mixed.lua` is the first mixed
  scene: a violet icosahedron circles a glass sign with a gold circle
  painted on it, passing in front of and behind it; a jade spark on the
  front pane follows the shape; an ice sweep glows on the back pane.
- A score with a second space indexes through every house hue, as the
  shape films do, so its shapes and strokes share one palette. A score of
  strokes alone keeps its own palette and its bytes.

Open question 3 (a pane that turns to face the camera every frame) is
still hers to answer. Panes hold the facing the score gives them; a
`facing = "camera"` would be a small addition to `frame.gather_pane`.
