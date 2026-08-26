# 206 — Arrows that teach the order

## Current behavior

The stroke order is known and nothing says it out loud.

## Intended behavior

**A transparent image with a numbered arrow at the start of every stroke,
pointing the way the brush went.**

From the vision, and it is the sentence that makes this a learning material
rather than a picture:

> if the strokes are the structure, then the stroke order is the intended
> viewing order, as directed with arrows because it's a learning material.

**It is a separate layer and it never enters the field.** `docs/003` says why:
the field is a request to a diffusion model, and asking a diffusion model to
render arrows into a landscape both fails and is wrong in principle. An arrow is
an annotation about the picture, not a thing in the world the picture shows.

Each arrow needs three things and they all come from the flattened stroke:

- **where it starts** — the stroke's first point
- **which way it goes** — the tangent at that point, not the chord to the
  endpoint. A stroke that curves leaves in a direction quite different from where
  it ends up, and an arrow pointing at the endpoint of a bending stroke points
  through the middle of the curve and teaches the wrong exit.
- **its number** — its index in writing order

**It must be legible at thumbnail size**, because that is the size at which the
rest of the image works. That constrains everything: heads large relative to the
canvas, numbers large, and both drawn with a contrasting outline so they survive
whatever colour the generated scene turns out to be underneath. A layer designed
against a white background disappears over a bright sky.

**Digits are drawn, not typed.** There is no font machinery in this project and
adding one for ten glyphs would be the largest dependency here. A seven-segment
digit is a handful of line segments on the canvas already built for lines, it is
unambiguous at small sizes, and it reads as a diagram rather than as text — which
is what it is.

**Crowding is handled, because it is the normal case.** Twenty-stroke characters
have strokes beginning a few pixels apart. Arrows placed naively overlap into an
unreadable knot. Each arrow is nudged along the outward normal of its own stroke
until it clears the ones already placed, and where nothing clears, the number is
kept and the head is shortened — a number in the right place beats an arrow in
the wrong one.

## Suggested implementation steps

1. **`src/026-arrows-that-teach-the-order.lua`**, producing an RGBA image at the
   same resolution as the field so the two composite without scaling.

2. **Four canvases, one per channel**, reusing `104` rather than inventing a
   colour surface. Alpha is a canvas like any other and the writer in `105` takes
   four.

3. **Draw the outline first and the fill second**, both from the same geometry at
   different widths. That is one description of an arrow drawn twice, rather than
   two descriptions that will drift apart.

4. **Test the thing that is actually wrong when it is wrong**: that the arrow
   direction matches the tangent and not the chord, checked on a strongly curved
   stroke where the two differ by a large angle. Everything else about this layer
   is visible at a glance, and that one is not.

## Related

`docs/003` — why it is separate. `005` — where it is composited back in.
