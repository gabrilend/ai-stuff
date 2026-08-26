# 202 — The field the illusion rides on

## Current behavior

There is a canvas and there are measured strokes. Nothing puts one on the other.

## Intended behavior

**The grayscale image that makes a picture secretly be a character.** `docs/003`
is the full description; this builds it.

Five steps in a fixed order — place, taper, ramp, blur, compress — and the order
is not negotiable. Blurring before the ramp would smear a stroke's darkness into
its neighbours before the ramp could distinguish them. Compressing before the
blur would compress a range the blur then narrows again, so the band would come
out wrong. Each step assumes the last one happened.

**Every knob is read from settings and none is written here.** Blur radius,
stroke width, taper fraction, order ramp, the range band and the resolution are
all in `input/settings.lua` and all in `docs/balance-updates.md`. A number typed
into this file is a number nobody will find when the images come out wrong.

**Polarity is applied last and is a single inversion.** The scene decides it
(`docs/004`); this obeys.

**The field is also emitted as a preview.** The same field, at thumbnail size,
with the character printed beside it — because the whole specification is *does a
person see the character in the thumbnail*, and `304` needs that comparison for
every image in the set. It is the same computation at a different size, not a
second implementation.

## Suggested implementation steps

1. **`src/022-the-structure-field.lua`**, taking a record and settings and
   returning a canvas.

2. **Scale from the archive's box to the canvas.** KanjiVG draws in 109 by 109
   with the origin top-left, and PNG rows also run top-down, so there is no flip —
   but the character does not fill its box, so a margin is applied, and it must be
   applied *symmetrically about the centre of the box* rather than about the
   character's own bounding box. Centring each character on its own ink makes 一
   fill the frame like 田 does, and every character comes out the same visual
   size, which destroys the one signal a learner has for how complex a character
   is.

3. **Taper by position along the arc**, not by point index. Flattening puts more
   points on curves, so tapering by index thins the curved parts of a stroke and
   leaves the straight parts blunt.

4. **The ramp is a multiplier on the brush, applied per stroke** — stroke *i* of
   *n* draws at `1 - ramp * (i-1)/(n-1)`. A one-stroke character divides by zero
   in that expression and must not.

5. **Test what `docs/003` promises**: every stroke put ink somewhere (a stroke
   that vanished means the scaling is wrong for that character), the final range
   sits on the requested band, no ink touches the outer edge of the canvas, and
   with the ramp on, the mean darkness of each stroke's own pixels decreases along
   the writing order.

## Related

`docs/003` — the design in full. `104` — the surface. `201` — the measurements.
