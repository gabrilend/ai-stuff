# 026-arrows-that-teach-the-order — info

Draws the layer that says which stroke comes first, and which way the brush went.

For a general: this is the part that makes the output a learning material rather than a clever picture. From the vision --

  if the strokes are the structure, then the stroke order is the intended   viewing order, as directed with arrows because it's a learning material.

A numbered arrow sits at the start of every stroke, pointing the way that stroke is written. It is drawn on its own transparent sheet and laid over the finished picture afterwards; it never goes into the grey field. Asking a diffusion model to render arrows into a landscape both fails and is wrong in principle -- an arrow is an annotation *about* the picture, not a thing in the world the picture shows.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `026-arrows-that-teach-the-order.lua` and
run the sweep again.*

## Invocation

```
luajit src/026-arrows-that-teach-the-order.lua --chars 休語鬱
```

## What it offers

| | |
|---|---|
| `M.build(record, settings, options)` | The whole stroke-order sheet for one character. |
| `M.write(path, surfaces)` | The sheet, written as a picture with transparency in it. |

### `M.build(record, settings, options)`

The whole stroke-order sheet for one character.

Returns the four surfaces and a description of every arrow placed, which the card in `302` carries so that the overlay can be checked without looking at the picture.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `segment_line(digit_x, digit_y, width, height, which)` | Where one segment of a figure runs, as two points. |
| `sheet(resolution)` | Four surfaces: three colours and a transparency. |
| `line_on(surfaces, ax, ay, bx, by, width, colour)` | One straight mark, in colour, on all four surfaces at once. |
| `wedge_on(surfaces, points, colour)` | One arrowhead, in colour. |
| `digit_on(surfaces, value, x, y, width, height, thickness, colour)` | One figure, drawn as lit segments. |
| `number_on(surfaces, value, x, y, size, thickness, colour)` | A whole number, right of the given point, centred on it vertically. |
| `main(argv)` |  |

## Where it sits

Used by `027-test-the-meaning`, `030-make-one-kanji`.
