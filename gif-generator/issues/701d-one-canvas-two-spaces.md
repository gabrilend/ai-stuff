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

One score, one `canvas{}`, any mix of the two vocabularies:

    canvas{ size = 320, fps = 20, length = 4.0, seed = 7 }
    camera{ eye = {0, 2, 7.5}, target = {0, 0, 0}, fov = 44 }      -- world space
    shape{ mesh = "jellyfish", at = {0, 0, 0}, motion = "drift" }   -- world space
    stroke{ at = 0.5, lasts = 2.0, shape = arc{ center = {160, 160},
            radius = 90, from = 12, to = 6, turn = "clockwise" } }  -- screen space

- **Screen space** for 2D: pixels, origin top-left, y down, as today.
- **World space** for 3D: units, origin at the world's centre, y up, seen
  through the one camera.
- **Each frame**: the 3D layer is drawn into colour and depth; the 2D layer
  is drawn into light; the two are composed, then quantised once through the
  one palette, then encoded once.
- **Order**: a 2D stroke says whether it is `behind` the 3D layer (sky,
  backdrop) or `over` it (the default: light painted on the glass in front).
  A stroke has no depth, so this is a layer, not a depth test.
- **Light adds**: a 2D glow over a 3D shape brightens it rather than
  covering it, the way glow already works in the 2D painter.
- **Landmarks cross over**: a 2D stroke may name a 3D shape as a point,
  `tip("jellyfish")`, meaning "where that shape appears on screen this
  frame", so a line of light can follow something in the world.

A score with only 2D strokes renders byte-identical to today; a score with
only 3D shapes renders byte-identical to the film it was ported from.

## Suggested Implementation Steps

1. Define the frame: one structure holding colour, depth and light, sized by
   the canvas.
2. Teach the 3D painter to draw into it, and the 2D painter to add light to
   it, each unchanged otherwise.
3. Write the composer: behind-strokes, then the 3D layer, then
   over-strokes, then tone-map, then quantise.
4. Let the wall accept both vocabularies in one score, and add `camera{}` and
   `shape{}` beside `stroke{}`.
5. Add the cross-over landmark: a 3D shape's projected point, per frame.
6. Prove the two byte-identity promises above, then render one mixed scene.

## Open Questions

1. Are two layers (behind, over) enough, or should strokes be orderable
   between 3D shapes, which would need a depth for each stroke?
2. The 2D painter uses a black background and adds light; the 3D painter
   draws lit surfaces and a sky. Whose background wins when both are
   present: the 3D sky, black, or a canvas setting?
