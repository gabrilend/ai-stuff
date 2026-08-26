# 014-the-path-language — info

Reads the little language each stroke is written in.

For a general: a stroke in the archive is a line of text like

    M19.5,39.86c2.45,0.57,5.23,0.8,8.04,0.57C40.75,39.38,63,36.5,79.78,36.15

which says: start at one point, then bend through two curves. The letters are instructions and the numbers are the points they bend through. This turns that text into the curves it describes.

It is not a general reader for the format it belongs to. That format has arcs, straight lines, quadratic curves and a dozen other instructions, and this archive uses none of them -- every one of its eighty thousand strokes is a move followed by cubic curves. Accepting instructions that will never arrive would mean the day one did arrive, it would be handled by code nobody had ever run. So anything else is an error that names the character it came from.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `014-the-path-language.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.parse(d, context)` | One stroke's path text, as the curves it describes. |

### `M.parse(d, context)`

One stroke's path text, as the curves it describes.

Returns { x, y, curves }, where x and y are where the brush starts and each curve is { x1, y1, x2, y2, x, y } -- two control points and an endpoint, all absolute. The point a curve starts from is wherever the previous one ended, which is how the format itself works and saves storing it twice.

`context` is a phrase naming what is being parsed, used only in errors.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `read_number(text, position)` | One number, and where it ended. |
| `want(count)` | The next several numbers, or an error saying what was missing. |
| `add_curve(x1, y1, x2, y2, ex, ey)` | One cubic curve, recorded, and the state it leaves behind. |

## Where it sits

Used by `020-test-the-ink`.
