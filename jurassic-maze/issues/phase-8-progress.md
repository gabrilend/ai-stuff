# Phase 8 — The Mountain

**Three of five.** The world is no longer generated. It is a file somebody typed,
it is a mountainside rather than a pyramid, it has no walls in it, and it renders
with every shelf visible from summit to base.

| Issue | |
| --- | --- |
| [801](completed/801-a-map-is-plates-and-stairs.md) | a map is plates and stairs |
| [802](completed/802-the-mountainside-is-hard-coded.md) | the mountainside is hard-coded |
| [803](completed/803-the-height-field-becomes-a-model.md) | the height field becomes a model |
| [804](804-a-ball-is-a-sphere-against-faces.md) | **not started** — a ball is a sphere against faces |
| [805](805-a-ball-is-a-sprite-in-a-solid-world.md) | **not started** — a ball is a sprite in a solid world |

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

## What is deferred, and what it is waiting on

**The whole ball simulation.** [804](804-a-ball-is-a-sphere-against-faces.md) and
[805](805-a-ball-is-a-sprite-in-a-solid-world.md) are written and not started. What
runs on the mountainside today is the *old* roller — the interpolated height field
from phase 3 — which smooths staircases into ramps on purpose. It works, and it is
the wrong physics for a mountain whose only way down is stairs.

**The thirty-two layer ceiling.** The map wants four-layer shelves and comes to
thirty-four layers; a column is a 32-bit integer. The map was re-spaced to three
layers to fit, which is a concession recorded in the file rather than a decision.
The map format has no such ceiling and does not need the bitmask, having no holes.
Open question two of [801](completed/801-a-map-is-plates-and-stairs.md).

**Everything that is not a ball.** The guys, the fencers, the dinosaurs and the
delve all still run and are all set aside until the ball example works.
