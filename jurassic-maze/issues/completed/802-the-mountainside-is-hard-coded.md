# 802 — The Mountainside Is Hard-Coded

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 801 |
| Blocks | 803, 804, 805 |
| Reads | `inspiration/inspiration-maze.png`, `inspiration/NOTICE.md` |
| Open questions | one, at the bottom |

## Current behavior

Every maze in the project comes out of a generator, and there has never been a
known-good one to check anything against. When a ball behaves oddly there is no
way to tell whether the ball is wrong or the maze is, because the maze was made
by the same reasoning that is under suspicion.

## Intended behavior

One map, written by hand, checked in, and never regenerated. It is the reference
against which everything else is judged, and its job is to be *correct* rather
than to be varied.

It is a mountainside read off the reference picture, and it keeps four things
from it.

**A high corner and a low corner.** Elevation falls from the far corner — small
x and y, drawn at the top of the screen — toward the near one. Nothing rises
toward the camera, which is what makes the whole surface visible from a fixed
isometric view without any special pleading. This is the single most important
property and it is the one the generator got wrong.

**Shelves along the contour.** Flat plates run across the slope, at right angles
to the fall, which in this projection puts them across the screen rather than
into it. Each shelf is a plaza several cells deep.

**A rim on the downhill edge of each shelf.** Two layers above its own floor, so
a ball that reaches the low edge of a shelf is contained rather than dropped, and
has to find a way down. The rim is the closest thing in the map to a wall, and it
is a lip on a plate rather than a wall between two corridors.

**Staircases through the rim.** One or two per shelf, at chosen places, each
carrying the shelf's elevation down to the next shelf one tread per layer. They
are what a ball rolls down and they are why the route from summit to base is a
switchback rather than a straight fall.

Between shelves, where there is no staircase, the drop is a cliff of several
layers. A ball that gets over a rim falls it. That is allowed, and it is the
difference between the fast way down and the intended way down.

## Suggested implementation steps

1. Lay the shelves first, as plain rectangles, with nothing else. Look at it.
   A mountainside with no maze on it should already read as a mountainside, and
   if it does not, no amount of detail added afterwards will rescue it.
2. Add the rims, as a second rectangle along each shelf's low edge two layers up.
   The overlap rule makes this one line per shelf rather than a redrawn shelf.
3. Cut the staircases through the rims, at alternating ends, so the route down is
   a switchback rather than a straight line.
4. Add dividers on the wider shelves — short raised rectangles that split a shelf
   into two channels — so that reaching the staircase is a route rather than a
   straight roll.
5. Check it with the sightline survey before believing it. The claim that a
   descending surface is entirely visible is a claim, and 067 is the thing that
   settles it.

## Related documents and tools

- [801](801-a-map-is-plates-and-stairs.md) — the format this is written in
- `src/067-sightlines.info.md` — the visibility measurement
- `inspiration/NOTICE.md` — what has been measured off the picture

## Open question

**Is this a transcription or a composition?** What is being written here is a
mountainside in the reference picture's idiom — its shelf depths, its stair runs,
its drops — and not a cell-by-cell trace of any particular region of it. A literal
trace is possible and would take a long time, and it is not obvious that it buys
anything the idiom does not, since the picture's maze was drawn to be looked at
rather than to be simulated. Not answered.
