# 109 — Nothing Hides Behind Anything

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 104, 108, 201 |
| Blocks | — |
| Reads | [the isometric projection](../docs/006-the-isometric-projection.md), [carving the maze](../docs/003-carving-the-maze.md) |
| Open questions | three, listed at the bottom, none of them answered yet |

## Current behavior

Three quarters of the maze cannot be seen, and the bodies walking about in it are
hidden behind the walls standing in front of them. A screenshot at any useful
zoom shows wall tops and the shadowed sides of walls, and almost no corridor
floor at all.

This is not a rendering bug. The renderer is drawing exactly what the geometry
says, and the geometry says the maze is opaque to its own camera. Nobody had
measured it, so nobody knew the number.

Measured with a raycast against the real generator, seed 1, at the shipped
constants:

| | |
| --- | --- |
| floor cells | 8374 |
| centre of the floor face visible | 25.7% |
| **any part of the floor face visible** | **29.3%** |
| every column top, centre visible | 56.8% |

The blame is concentrated in one place. Of the cells whose centre is hidden,
4465 are hidden by the cell one step diagonally in front of them standing exactly
two layers taller — that is, **by an ordinary maze wall**.

## Why it happens, in three constants

The camera is at infinity in a fixed direction. Two world points land on the same
screen pixel when `x - y` is equal and `(x + y) * HALF_HEIGHT - z * LAYER_PIXELS`
is equal, so the direction from any point toward the camera is

    (+1 cell, +1 cell, +2 * HALF_HEIGHT / LAYER_PIXELS layers)

With `HALF_HEIGHT` 8 and `LAYER_PIXELS` 10 that is **1.6 layers per diagonal
cell**. Put the other way round: one diagonal step toward the camera moves a cell
16 pixels down the screen, and a wall standing two layers above its corridor is
drawn 20 pixels tall. Twenty is more than sixteen, so the wall's top face is
drawn *above* the floor behind it and the floor behind it is gone.

The room lattice makes this universal rather than occasional. Rooms sit where
both coordinates are odd, so the cell diagonally in front of every single room is
a lattice post, and a post is always a wall, and a wall is always two layers up.
**Every room in the maze is hidden by its own front post.** There is no seed and
no parameter setting for which this is not true.

## Intended behavior

Two separate rules, because two separate things are going wrong and only one of
them belongs to the generator.

### The rule the projection has to satisfy

A wall must be drawn shorter than one diagonal step, or it hides the corridor
behind it no matter what the generator does:

    wall_rise * LAYER_PIXELS  <  2 * HALF_HEIGHT

Currently `2 * 10 = 20` against `2 * 8 = 16`, and it fails. The generator cannot
fix this, and it must not try: a wall short enough to see past is a wall a body
can climb, and a maze whose walls can be climbed is a plaza. Which side of that
inequality gets moved is open question one.

Swept across layer heights, three seeds each, the threshold is sharp and it is
exactly where the arithmetic says it is:

| layer pixels | layers the ray climbs per cell | any part of floor visible, wall rise 2 | wall rise 1 |
| --- | --- | --- | --- |
| 10 | 1.60 | 29.0% | 77.0% |
| 9 | 1.78 | 29.3% | 81.1% |
| 8 | 2.00 | 29.4% | 82.1% |
| **7** | **2.29** | **82.4%** | 84.8% |
| 6 | 2.67 | 83.3% | 86.7% |
| 5 | 3.20 | 85.1% | 87.3% |

Nothing between 10 and 8 helps at all, and 7 changes everything, because the
comparison being made is between two integers and it flips in one step.

### The rule the generator has to satisfy

Once walls are shorter than a diagonal step, what remains hidden is terrain
standing in front of lower terrain: terrace edges four layers tall, and outcrops.
At a seven-pixel layer, 17% of floor cells are still completely hidden, and every
blocker in the list is taller than a wall — plus three, four, six, eight layers,
one to three diagonal cells in front.

The invariant to enforce, for every floor cell at `(x, y)` with top height `H`,
and every `t` at least one:

    height(x + t, y + t)  <  H + t * (2 * HALF_HEIGHT / LAYER_PIXELS)

There is a cheaper equivalent form worth knowing, because it turns the whole
thing into one scan per diagonal instead of a search. Define

    G(x, y) = height(x, y) - (HALF_HEIGHT / LAYER_PIXELS) * (x + y)

The condition above holds for every pair on a diagonal exactly when **G is
strictly decreasing along that diagonal in the direction of the camera**. A pass
that walks each diagonal once, from far to near, carrying the smallest `G` seen so
far, finds every violation in one sweep over the height field.

That is the shape the new pass should take. What it does with a violation is open
question two.

## Suggested implementation steps

1. Write the raycast first, as a measurement, not as a fix. It marches from a
   point on a top face toward the camera, crossing one cell boundary at a time,
   and reports the first cell whose height is above the ray. Every column is a
   plain pile, so a cell blocks when the ray is below its height on entry — the
   ray only climbs, so entry is where the ray is lowest over that cell.
2. Put the survey in the validator beside the other counted things, reporting the
   fraction of floor visible and the fraction of column tops visible. A warning is
   an error there and this is a count, so it becomes a number to compare against
   last week's rather than a message nobody reads.
3. Add the visibility pass to the generator, after heights exist and before the
   stone is realised, so it works on room heights rather than on columns.
4. Add the test. It asserts the invariant directly, on several seeds, and it is
   the thing that stops this coming back when somebody tunes a terrace.
5. Only then change whichever constant open question one settles on, and re-run
   the sweep to confirm the number moved where the table says it should.

## Related documents and tools

- `docs/006-the-isometric-projection.md` — where the view direction comes from
- `docs/003-carving-the-maze.md` — the six passes this adds a seventh to
- `src/032-the-validator.info.md` — where the survey belongs
- `inspiration/NOTICE.md` — the projection constants, and what was measured off
  the reference picture rather than chosen

## Open questions

**One. Which side of the wall inequality moves?** The wall has to be drawn
shorter than one diagonal step. Either a layer gets drawn shorter — walls and
terraces become squatter, cells stay the same size — or the cell diamond gets
bigger against the layer, so walls keep their proportions and fewer cells fit on
screen. Both are the same ratio and they look nothing alike. Not answered.

**Two. When the visibility pass finds a violation, what gives way?** Lowering the
blocker flattens the terrain the maze is built on and may sever a staircase.
Raising the hidden ground does the reverse and can lift a room past the ceiling.
Setting the terrace edge back a cell per layer turns every four-layer cliff into
a stepped shoulder, which is what the reference picture appears to actually do,
and is the most work. Not answered.

**Three. Does the rule apply to the whole maze or only to the floor?** A wall top
is a surface a body can stand on, and 43% of column tops are hidden as well.
Making every column top visible is a far stronger constraint than making every
corridor visible, and it may not be satisfiable at all with walls of any height.
Not answered.
