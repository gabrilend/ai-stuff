# Phase 8 — The Mountain

**Five of six.** The world is no longer generated. It is a file somebody typed, it
is a mountainside rather than a pyramid, it has no walls in it, every shelf is
visible from summit to base, and nine hundred spheres roll down it bouncing off
real geometry and off each other.

| Issue | |
| --- | --- |
| [801](completed/801-a-map-is-plates-and-stairs.md) | a map is plates and stairs |
| [802](completed/802-the-mountainside-is-hard-coded.md) | the mountainside is hard-coded |
| [803](completed/803-the-height-field-becomes-a-model.md) | the height field becomes a model |
| [804](completed/804-a-ball-is-a-sphere-against-faces.md) | a ball is a sphere against faces |
| [805](805-a-ball-is-a-sprite-in-a-solid-world.md) | **not started** — a ball is a sprite in a solid world |
| [806](completed/806-balls-collide-with-each-other.md) | balls collide with each other |

`./run-maze --map 070-the-mountainside` shows it.

## The journey, and what it taught

### The picture has no walls in it

The generator built a nested pyramid with two-layer walls on a room lattice, and
all three of those were wrong. Looking at the reference picture closely enough to
count courses of masonry settles it: every vertical surface in it is the side of a
higher flat plate. What reads as a wall between two corridors is the edge of a
block whose own top is walkable, and there is not one wall in the whole painting.

**What it taught:** the project had been treating the picture as a mood board and
the design as settled. `inspiration/NOTICE.md` recorded six measurements taken off
it, and every one of them was about a dimension — corridor width, wall height,
stair run. None was about what the thing was *made of*, which turned out to be the
only question that mattered.

### Seventy-one percent of the maze could not be seen, and the arithmetic said so

Before the pivot, the visibility problem was measured rather than argued about.
The line of sight climbs `2 * HALF_HEIGHT / LAYER_PIXELS` layers per diagonal
cell, which is 1.6, and a wall standing two layers above its corridor is 2. Twenty
pixels of wall against sixteen pixels of diagonal step, so the wall's top face is
drawn above the floor behind it and that floor is gone.

The room lattice made it universal: rooms sit at odd coordinates, so the cell
diagonally in front of every room is a lattice post, and a post is always a wall.
Every room in the maze was hidden by its own front post, on every seed.

**What it taught:** a generator cannot fix a projection. The measurement is in
[109](109-nothing-hides-behind-anything.md) and the tool is
`src/067-sightlines.info.md`, and both survive the pivot unchanged, because what
they measure is the camera and not the maze.

### A descending surface is visible for free

The mountainside answers the same question without any pass to enforce it. If
elevation never rises toward the camera, then along the line of sight heights only
fall, so the visibility condition holds everywhere by construction and there is
nothing to check.

The measured result is 81.2% of cells showing some of their face, against 29.3%
for the generated maze. **Every hidden cell is behind a rim or a divider** — the
two features deliberately taller than the ground behind them. Nothing is hidden by
accident, which is the difference that matters.

**What it taught:** the visibility pass sketched in issue 109 was never written and
now never will be. Choosing a shape that cannot violate an invariant beats
enforcing it afterwards.

### The reference implementation has to be the definition, not a slower guess

The sightline raycast was first checked against a version that crept along the ray
in fortieths of a cell. They disagreed on seven cells out of a thousand, and the
creeping one was wrong: a ray entering a cell a hundredth of a layer below its top
climbs clear before the next sample. The replacement asks every cell in the world
whether the ray passes under it — slow, and impossible to get wrong.

**What it taught:** "obviously correct" and "obviously slow" are not the same
property, and only the first one is useful in a test.

### The off-by-one between a map and a store

A map's elevation is the plane of the top surface; the stone store's height is the
index of the topmost solid layer, and layer L occupies L to L + 1. They differ by
one. The two cancelled invisibly in the sightline survey — both the ray's origin
and the blocker's height used the same convention — and would not have cancelled
in the physics, where a ball resting on a shelf at 22 has its centre at 22 plus its
radius.

**What it taught:** it is written down in one place, in `069-the-map.info.md`, at
the function where the conversion happens.

### A sphere on level ground never moves, and it rewrote the map

The mountain's first shape was eight broad flat shelves with a kerb along each
downhill edge. Under a real physics it did nothing at all: three hundred spheres
sat exactly where they were dropped and stayed there for a minute. Every surface
in a height field is level or vertical, gravity points straight down, and a sphere
on a level plate has no sideways force on it whatsoever.

The old roller hides that completely. It accelerates a ball along the
*interpolated* slope of the height field, which is nonzero near every edge — so
its balls move because of the smoothing rather than because of the ground, and
nobody could have known that from watching them.

The mountain now descends a layer every two cells all the way from the summit to
the rim, so no ball is ever on a plain, and a ball is dropped with a nudge because
that is the only thing that ever starts one. Once started it keeps going, and the
mechanism is worth knowing: rolling off the edge of a step, the nearest stone is
the *edge* rather than either face, so the push is diagonal and turns part of each
fall into forward motion. That is why a sphere accelerates down a staircase, and
it is why the resolver pushes along the direction to the closest point rather than
along the face's normal.

**What it taught:** the physics was not tested against the map, it *changed* the
map. Two documents had described broad flat shelves, and both were describing a
world that could not work.

### Four bugs that only a crowd produces

Every one was invisible with three hundred balls and unmissable with nine hundred,
and every one is now an assertion.

**A pair was taken by the lower id.** Either rule visits each pair exactly once
and only one is correct: resolving a pair moves both spheres, and the partner
needs its settle against the stone afterwards. The roster is maintained by
swap-remove, so it is in no order at all, and the higher id is very often the body
processed twenty slots ago. The rule is now the roster slot.

**Two spawns in one tick claimed one cell.** The spawner asks the buckets whether
a cell is occupied and the buckets are rebuilt once a tick, so the second spawn of
a tick saw a count that knew nothing about the first and dropped a ball exactly
inside another — two spheres at one point, with no line of centres to separate
along.

**The index pass ran after the spawn pass**, so the occupancy check read positions
from before that tick's move. It runs before now, and the cost is that a body is
invisible for the single frame in which it appears.

**A sphere that got under a floor was gone forever.** The one-sided face test —
which is what makes a rectangle behave as the surface of a solid, and which is
right for every riser — refuses to look at a face from behind. A ball shoved down
through a floor by a neighbour kept falling, past every other floor, for the same
reason. Still simulated, still drawn, at minus a hundred and twenty-five layers,
with the rim check reporting it was inside the map because the rim check only ever
looked at x and y.

A top face is now the lid of a solid rather than a one-sided plane: a sphere under
one and horizontally inside it is lifted, whichever side it came from. There is no
such thing as behind the top of a height field.

**What it taught:** three of the four were latent long before this row existed,
and a fifth found on the way — the spawn retry drawing from the general floor
rather than from the wide floor — has been putting dinosaurs where dinosaurs do
not fit since phase six. A crowd is a test.

## What is deferred, and what it is waiting on

**Drawing it properly.** [805](805-a-ball-is-a-sprite-in-a-solid-world.md) is
written and not started. The world is still drawn by the column sweep rather than
from the model, so the renderer and the physics read two different descriptions of
the same mountain, and a ball is still a drawn circle rather than a sprite.

**What the pass costs.** Nine hundred spheres cost 3.6 milliseconds a tick, about
four microseconds each, against 0.8 for the old roller — a fifth of a frame. The
row also declares itself **not parallel**, honestly: it writes to two bodies at a
time and the second is not in the range a thread pool would hand it.

**The thirty-two layer ceiling.** The map wants four-layer shelves and comes to
thirty-four layers; a column is a 32-bit integer. The map was re-spaced to three
layers to fit, which is a concession recorded in the file rather than a decision.
The map format has no such ceiling and does not need the bitmask, having no holes.
Open question two of [801](completed/801-a-map-is-plates-and-stairs.md).

**Everything that is not a ball.** The guys, the fencers, the dinosaurs and the
delve all still run and are all set aside until the ball example works.
