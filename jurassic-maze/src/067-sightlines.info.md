# 067-sightlines

What the camera can and cannot see, as a raycast and as a count.

Read this page rather than the source. The source is for when one named function
is misbehaving; this is for everything else.

## What it is for

A maze nobody can see into is not a maze, it is a roof. Before this file existed
there was no way to say how much of the floor was hidden, so nobody knew that
three quarters of it was — the question could only be answered by squinting at a
screenshot, and a screenshot of a maze that is mostly wall tops looks like a maze.

It measures. Nothing here repairs geometry; the things that do steer by these
numbers. Pure arithmetic on the height field, no engine and no window, so the
validator and the headless runner can both load it.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `climb(Iso)` | the projection module | layers of sight gained per diagonal cell |
| `blocked(store, climb, px, py, pz)` | a point on a top face | the first cell in the way — its x, its y, its height — or nil |
| `survey(store, climb)` | | a table of counts, below |
| `wall_fits_behind_a_step(Iso, wall_rise)` | | whether an ordinary wall is short enough to see past |

## The one number everything turns on

`climb` is `2 * HALF_HEIGHT / LAYER_PIXELS`, and it is derived rather than
chosen. The camera is at infinity, so a direction points at it exactly when
moving along that direction does not move anything on screen. Screen x is
`(x - y) * HALF_WIDTH`, unchanged when the two steps are equal, which pins the
view to the diagonal. Screen y is `(x + y) * HALF_HEIGHT - z * LAYER_PIXELS`,
unchanged when `2 * HALF_HEIGHT` of horizontal is cancelled by `LAYER_PIXELS` of
height. So the line of sight is `(+1 cell, +1 cell, +climb layers)`.

At the shipped constants `climb` is **1.6**, and a wall standing two layers above
its corridor is **2** — taller than one diagonal step of sight. That single
comparison is why the corridor behind every wall is invisible.

## What the survey counts

| Field | Meaning |
| --- | --- |
| `floor_cells`, `column_tops` | how many of each there were to test |
| `floor_centre`, `top_centre` | the middle of the face reaches the camera |
| `floor_any` | at least one of sixteen points on the face reaches the camera |
| `hidden_by` | for floor with nothing visible: how far in front the tallest blocker is, and how much taller, tallied |

`floor_centre` and `floor_any` answer different questions and the gap between
them is the informative part. The centre is roughly whether a body standing there
would be seen. **Any part** is whether a person can tell the cell is there at all.
A corridor whose near half hides behind its own wall but whose far half shows is
legible; one where neither shows is a roof.

## Three things that make the raycast exact rather than sampled

**Every column is a plain pile**, so "is the ray inside stone here" is one
comparison against that cell's height. The validator's height-shaped check is
what guarantees that, and this file would quietly give wrong answers the day a
golem punches a tunnel through a wall — which is the reason that check takes a
flag rather than being deleted when phase seven starts making holes.

**The ray only climbs**, so the lowest it gets while crossing a cell is where it
entered. Testing the entry point alone is exact, not an approximation, and it
costs one comparison per cell crossed rather than a fine-grained march.

**The face is sampled at sixteen interior points, not at its four corners.** A
corner sits exactly on the seam between four cells, so a corner ray is decided by
which way the floating-point nudge rounded — it reports a neighbour rather than
an occluder. Interior points belong to one cell and cannot be argued with.

## `wall_fits_behind_a_step` returns a verdict and repairs nothing

One diagonal step toward the camera moves a cell `2 * HALF_HEIGHT` pixels down
the screen; a wall is drawn `wall_rise * LAYER_PIXELS` pixels tall. When the wall
is the taller, the floor one step behind it is gone.

The room lattice makes that universal rather than occasional: rooms sit where
both coordinates are odd, so the cell diagonally in front of every room is a
lattice post, and a post is always a wall. Every room in the maze is hidden by
its own front post, on every seed.

**The generator cannot fix this**, which is why this function reports rather than
acts. A wall short enough to see past is a wall a body can climb, and a maze whose
walls can be climbed is a plaza. It is a projection constant or it is nothing.
