# 003 — Datapath: the structure field

The structure field is a grayscale image. It is the only thing standing between
"a picture of a forest" and "a picture of a forest that is also the character 森",
and understanding what it is makes the rest of the project obvious.

## What the field is for, mechanically

A diffusion model makes a picture by starting from noise and repeatedly asking
*what would this look like if it were slightly less noisy and slightly more like
the prompt*. A ControlNet is a second network wired alongside the first that adds
a further condition to every one of those steps: *and also, slightly more like
this image I am holding*.

The family of ControlNets this project targets — the ones variously called
*illusion*, *QR monster*, *brightness* — hold a **grayscale image and treat it as
a map of where light and dark should end up**. They do not care about edges,
depth, or pose. They care that the finished picture is dark where the map is dark.

So the map is the kanji. The prompt is the scene. The sampler's job becomes:
*build a forest whose shadows land on these strokes.* It has enormous freedom in
how — a trunk, a gap between trunks, a cast shadow, a dark reflection — and no
freedom at all about where. That is the whole illusion, and it is why the output
reads as a photograph rather than as a character with a picture behind it.

## Why the strokes are blurred, and what the blur is worth

The naive field is the strokes drawn white on black at full contrast. It produces
a picture with the kanji **painted onto it** — a black bar across the sky, hard
edged, obviously added. The model satisfied the constraint the cheapest way
available, which is to draw the shape.

The fix is to soften the strokes until they stop being lines and become *regions
of darkness*. A hard edge is a demand for an edge. A soft gradient is a demand for
a neighbourhood, and a neighbourhood can be satisfied by a tree standing there.

So the blur radius is the dial between the two failure modes:

```
    no blur                  right                    too much blur
 ┌───────────┐          ┌───────────┐            ┌───────────┐
 │  ▐█████▌  │          │   ░▒▓▒░   │            │           │
 │           │          │           │            │    ░░░    │
 └───────────┘          └───────────┘            └───────────┘
 a black bar is         a tree grows             nothing in particular
 drawn on the sky       where the stroke was     is anywhere; the kanji
                                                  does not survive
```

It is a knob, it will be turned, and every turn of it belongs in
`docs/balance-updates.md` rather than in a commit message.

## How the field is built

`src/022-the-structure-field.lua`, working on the surface from
`src/016-the-grey-canvas.lua`. Five steps, in order:

1. **Place the strokes.** Each stroke's SVG path is parsed (`src/014`), its curves
   flattened to short straight runs (`src/015`), and each run is drawn onto a
   floating-point surface as a thick line with soft shoulders. Coverage is computed
   from the distance of each pixel to the line, so the result is antialiased
   without anything being drawn twice — overlapping strokes take the maximum
   coverage rather than accumulating, or crossings would be darker than the
   strokes that made them and the character would grow bright knots at its joints.

2. **Taper the ends.** A brush stroke is not a rectangle. Width falls off over the
   last fraction of each stroke's length, which does two things: it matches how the
   character actually looks written, and it keeps stroke ends from reading as
   deliberate blunt objects in the finished picture.

3. **Ramp by stroke order.** Stroke one is laid down at full strength and the last
   stroke at slightly less. The eye goes to the darkest thing first and follows the
   gradient, so the composition itself pulls a viewer along the writing order,
   underneath and independent of the arrows that state it outright. The size of the
   ramp is a knob; at zero it is off, and off is a legitimate setting.

4. **Blur.** Three passes of a box blur, which is a close enough gaussian for this
   and is separable, so cost is proportional to the number of pixels rather than to
   the square of the radius.

   **The radius is not the same for every character.** How much room there is
   between "still a line" and "merged with its neighbour" depends on how crowded
   the character is, and characters run from one stroke to nearly thirty inside
   the same box. The setting is the radius for a character of ordinary density
   and it shrinks from there. Held flat, it welds the dense characters into a
   grey smudge at exactly the size this project is specified at.
   `docs/balance-updates.md` has the numbers and says what stroke count is
   standing in for.

5. **Set the range.** The field is scaled into a band between a floor and a
   ceiling rather than running the full zero-to-one. A field containing true black
   and true white asks for a picture containing true black and true white, and the
   sampler will oblige by crushing the scene. Compressing the field's contrast is
   what makes the constraint a *bias* rather than a *demand*, and it is the second
   most important knob after the blur.

The result is written as an 8-bit grayscale PNG by `src/017-write-a-picture.lua`,
at whatever square resolution the run asks for, and it is the image the workflow's
`LoadImage` node names.

## Which way round the ink goes

Written by hand, kanji are dark ink on light paper, and the obvious field is dark
strokes on a light ground. That is the default.

It is not always the right one, and the choice is exposed rather than assumed. A
night scene, a forest floor, anything whose subject is *dark things against
light* — the stroke wants to be the lit part and the ground wants to be dark. A
field polarity flag on the scene decides, and `docs/004` describes what sets it:
the biome does, because a biome knows whether its subject is lanterns in the dark
or trees against the sky.

## What is deliberately not in the field

**The arrows are not in it.** Stroke-order arrows are a *teaching* layer, drawn by
`src/026-arrows-that-teach-the-order.lua` onto a separate transparent image and
composited over the finished picture afterwards. Putting them in the field would
ask the diffusion model to render arrows into the scene, which is both unlikely to
work and exactly wrong: an arrow is an annotation, not part of the world depicted.

**The component boxes are not in it.** The scene grammar knows where 人 sits and
where 木 sits, and it uses that to write the prompt. It does not draw boxes. The
strokes already are the components; a second signal saying the same thing in
rectangles would fight with the first.

## How to know it worked

Two tests, and one is not automatable.

`src/027-test-the-meaning.lua` checks the field mechanically: that every stroke
put ink somewhere, that the range came out inside the band it was asked for, that
the blur did not push the character off the canvas, and that a field with the
ramp turned on is monotonically weaker along the writing order.

The other test is a person squinting at it, which is the actual specification and
cannot be written down as an assertion. `src/032-a-gallery-you-can-page.lua`
therefore shows every field at thumbnail size next to its character, because the
thumbnail is the size at which the illusion is supposed to work and full size is
the size at which it is supposed to fail.
