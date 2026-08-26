# 016-the-grey-canvas — info

A rectangle of numbers, and the brush that puts ink on it.

For a general: this is a sheet of paper with no idea what is being drawn on it. It can lay down a thick soft line, fill a straight-sided shape, blur everything, squeeze the range of light and dark into a chosen band, and turn itself upside down. Nothing in this file knows what a kanji is.

The numbers are kept as floating point rather than as bytes, because the picture this eventually holds is built in four passes -- draw, then weaken by writing order, then blur, then compress into a band. Doing that in eight bits would round four separate times, and the rounding shows up as banding in exactly the smooth gradients the blur exists to produce.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `016-the-grey-canvas.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.new(width, height, value)` | A fresh surface, every pixel the same. |
| `M.clone(canvas)` |  |
| `M.stroke(canvas, flat, options)` | One flattened line, laid down as a thick soft mark. |
| `M.convex(canvas, points, value, softness)` | A straight-sided shape with no dents in it, filled. |
| `M.blur(canvas, radius, passes)` | Softened, by running a box average over it several times. |
| `M.extremes(canvas)` | The darkest and lightest values present. |
| `M.compress(canvas, low, high)` | Everything squeezed into a chosen band. |
| `M.invert(canvas)` | Light for dark. What polarity does (`docs/004`). |
| `M.resample(canvas, width, height)` | The same picture at a different size, by averaging. |
| `M.bytes(canvas)` | The surface as one string of 8-bit values, row by row. |

### `M.new(width, height, value)`

A fresh surface, every pixel the same.

Pixels live in one flat array indexed y * width + x + 1, rather than a table of rows. One allocation instead of several hundred, and the blur walks it in straight lines either way.

### `M.stroke(canvas, flat, options)`

One flattened line, laid down as a thick soft mark.

options.width     how wide the mark is, in pixels options.strength  how dark, from zero to one options.taper     fraction of the length over which the ends thin away options.softness  how many pixels the edge fades over options.scale     multiply the line's coordinates by this options.offset_x, options.offset_y  and then shift them

COVERAGE IS COMPUTED, NOT PAINTED. For every pixel near a segment, the distance from that pixel's centre to the segment is worked out, and how much ink it receives falls off over the last pixel or so of the brush's half width. That gives a smooth edge without drawing anything more than once, which matters for the next paragraph.

INK COMBINES BY MAXIMUM, NOT BY ADDING. Strokes cross. If ink accumulated, every crossing would be darker than either stroke that formed it, and a character would grow a dark knot at each of its joints -- which the structure field would then hand to a diffusion model as an instruction to put something solid exactly where two strokes meet. Taking the greater of the two is what ink on saturated paper does, and it is why the whole stroke is drawn at one strength rather than built up.

### `M.convex(canvas, points, value, softness)`

A straight-sided shape with no dents in it, filled.

Used for arrowheads. Coverage comes from the distance to the nearest edge, which for a shape with no dents is simply the smallest of the distances to each edge's line -- so one loop over the edges gives both whether a pixel is inside and how close to the boundary it is, and the edges come out smooth for free.

The points must go round the shape in one direction. A shape whose points zigzag is not one this can fill, and it will quietly produce nothing rather than something wrong.

### `M.blur(canvas, radius, passes)`

Softened, by running a box average over it several times.

Three box averages approximate a gaussian closely enough that nothing downstream could tell, and a box average is separable and costs the same per pixel whatever the radius -- a running sum along each row, then down each column. A true gaussian at the radius this project uses would be several hundred multiplies per pixel to produce a result that the range compression afterwards would flatten the difference out of anyway.

Edges are handled by pretending the surface continues outward with its own edge pixel repeated. That is the choice that makes blurring a uniform surface give back the same uniform surface -- treating the outside as zero would darken every border, and the field's border is where the character's margin is.

### `M.compress(canvas, low, high)`

Everything squeezed into a chosen band.

`docs/003` says why the band is not the full range: a field containing true black and true white asks for a picture containing true black and true white, and the sampler obliges by crushing the scene. Narrowing the field is what turns it from a demand into a bias.

A surface that is entirely one value has no range to map, and stretching it would turn a blank sheet into something. It is set to the middle of the band instead, and that is the honest answer rather than a special case.

### `M.resample(canvas, width, height)`

The same picture at a different size, by averaging.

Averaging every source pixel that falls in a target pixel, rather than picking the nearest one. The thumbnail is the size at which the whole illusion is supposed to work (`docs/003`), so a thumbnail made by throwing pixels away would be testing a different image than the one a person shrinks in their browser.

### `M.bytes(canvas)`

The surface as one string of 8-bit values, row by row.

Where the floating point finally becomes a picture. Rounding rather than truncating, and clamped, because compression and blurring can both leave a value a hair outside the range and a wrapped byte is a bright speck in a dark field.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `width_at(distance)` | How wide the brush is, this far along the stroke. |

## Where it sits

Used by `009-where-things-are`, `020-test-the-ink`, `022-the-structure-field`, `026-arrows-that-teach-the-order`, `027-test-the-meaning`, `030-make-one-kanji`, `033-the-documentation-site`, `035-test-the-machine`, `046-two-ways-of-saying-it-is-good`.
