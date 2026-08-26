# 015-flatten-the-curves — info

Turns curves into short straight lines, and measures what it made.

For a general: a stroke arrives as a handful of curves. Almost nothing wants to work with a curve -- drawing one means asking where it is at a thousand places, and measuring one means calculus. Chopping it into short straight lines makes both trivial, and if the pieces are short enough nobody can tell the difference.

The chopping is not uniform. A kanji stroke is usually a long straight run with one tight bend in it, so cutting it into equal pieces either wastes hundreds of points on the straight part or rounds the corner off. Instead each curve is split in half repeatedly and each half stops splitting once it is straight enough to be a line -- so the points end up where the bending is.

What comes out is not only points. The field wants to thin a stroke towards its ends, and the arrows want to know which way a stroke leaves its beginning, and the scene grammar wants to know how curved a stroke is. All three are answered from the distance travelled along the line, so that is measured here and carried alongside.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `015-flatten-the-curves.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.flatten(path, tolerance)` | A parsed path, as points with distances along it. |
| `M.locate(flat, distance)` | Where the line is, a given distance along it. |
| `M.direction(flat, index)` | Which way the line is going at one of its points, as a unit vector. |
| `M.direction_at(flat, distance)` | The same, at a distance along the line rather than at a point. |

### `M.flatten(path, tolerance)`

A parsed path, as points with distances along it.

Returns a table holding:   xs, ys    the points, in order   count     how many   at        distance from the start, at each point; at[1] is zero   travel    the whole distance along the line   span      the straight-line distance from the first point to the last   bbox      x0, y0, x1, y1

`travel / span` is the cheapest description of a stroke's shape there is: one means straight, and well above one means it bends. `docs/004` uses it.

### `M.locate(flat, distance)`

Where the line is, a given distance along it.

Returns x, y and the index of the point just before. Distances outside the line are clamped to its ends rather than refused, because the callers ask for "a little past the end" on purpose -- the arrow layer places a head beyond the last point and the taper measures inward from both ends.

### `M.direction(flat, index)`

Which way the line is going at one of its points, as a unit vector.

WHY NOT THE CHORD. The arrows in `206` need the direction a stroke *leaves* its beginning, and for a stroke that bends, that is nothing like the direction from its first point to its last. An arrow pointing at the far end of a curving stroke points straight through the bend and teaches the wrong exit.

Taken from the flattened line rather than from the curve's own derivative, which would be the mathematically direct answer and has a case the flattened version does not: a curve whose first control point sits exactly on its start has a derivative of zero there and no direction at all. The first flattened piece is always a real segment with a real direction.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `split(x0, y0, x1, y1, x2, y2, x3, y3, tolerance, depth, xs, ys)` | One curve, halved until each piece is straight, appending the far end of |

## Where it sits

Used by `020-test-the-ink`, `021-the-shape-of-a-stroke`.
