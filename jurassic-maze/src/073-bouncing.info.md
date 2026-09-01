# 073-bouncing

A ball as a sphere, against the model's faces and against other spheres.

Read this page rather than the source, and read
[804](../issues/completed/804-a-ball-is-a-sphere-against-faces.md) and
[806](../issues/completed/806-balls-collide-with-each-other.md) before either.

## What it is for

The row it stands beside — [037-rolling](037-rolling.info.md) — samples an
interpolated height field, and smooths staircases into ramps **on purpose**. That
was right when a staircase was a rare thing cut into a maze of walls. On a
mountainside whose only way down is stairs it means the balls never bounce at
all; they slide.

So there is no height field here and no slope term. There is a sphere, gravity
straight down, and the flat rectangles from [071-the-model](071-the-model.info.md).
A ball on a stepped hillside accelerates because the stone pushes it sideways,
which is what a normal is for. A tread is a horizontal face and a riser is a
vertical one, and meeting either is the same three lines.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(deps)` | a table of modules | hands them in, once, at world creation |
| `advance(world, bodies, roster, first, last, dt)` | | moves a slice of the bouncing roster |
| `resolve_pair_for_test(bodies, a, b, ra, rb, restitution)` | | the pair resolver, named so a test can reach it |

`deps` carries `Locomotion`, `Creatures`, `Model`, `BodyStore` and `Stone`. They
are handed in rather than loaded because the world already has them, and loading
them again makes a second copy of the creature table — which is then tuned in one
copy and read from the other.

## One tick

Gravity, speed cap, integrate, settle against the world, resolve against
neighbours, **settle against the world again**, then friction and rest.

## Six things that are the way they are for a reason

**The stored `z` is the body's feet, not its centre.** Everything else in the
project uses it that way, so the sphere's centre is a radius above it and the
conversion happens here. Getting it wrong is invisible and fatal: a sphere centred
on its feet is half buried, its centre sits exactly on the plane of the floor, the
floor decides it is not on the outward side, and the ball falls through the
mountain.

**A face only pushes from in front.** A contact is resolved only when the centre
is on the outward side of the face's plane. That one dot product is what makes a
one-sided surface out of a rectangle — a ball on the high shelf beside a cliff is
on the *solid* side of that cliff's riser, so the riser ignores it — and it needs
no special case for edges or corners.

**The push is along the closest point to the centre, not along the face normal.**
At the top edge of a riser the nearest stone is an edge rather than a plane.
Pushing along the plane's normal there shoves a ball sideways off a surface it is
resting on. Pushing away from the edge is diagonal, and **that is the mechanism
that makes a ball accelerate down a staircase** — part of each fall is turned into
forward motion.

**Faces are resolved one at a time and immediately.** Gathering every overlap and
applying them together sounds more correct and is not: two faces meeting in a
corner each want the sphere pushed out along their own normal, and applied
together they push it twice as far as either asked, straight through whatever is
behind.

**The stone is settled last, and the stone wins.** A sphere shoved by a neighbour
can end up back inside the stone, and a sphere inside stone is a catastrophe —
the ground beneath it is the top of the block it is in, so it stands on nothing
and falls forever. A sphere overlapping another sphere is a pile that looks tight.
The remaining overlap in a heap is the price and it is bounded: a centre is never
inside another sphere.

**Pairs are taken by roster slot, not by id.** Both rules visit every pair
exactly once and only one is correct. Resolving a pair moves both spheres, and the
partner needs its final settle against the stone afterwards. The roster is
maintained by swap-remove so it is in no particular order, and the partner with
the higher id is very often the one processed twenty slots ago.

## A sphere at rest on level ground never moves

This is not a bug and it changed the map. Every surface in this world is level or
vertical, so a sphere sitting on one has no sideways force on it at all. Three
hundred of them sat exactly where they were dropped, on a mountain of eight broad
flat shelves, and did nothing for a minute.

The old roller hides that by accelerating along the *interpolated* slope, which is
nonzero near every edge — its balls move because of the smoothing rather than
because of the ground. Two things follow. The map descends a layer every two
cells, so no ball is ever on a plain; and a ball is dropped with a nudge, which is
the only thing that ever starts one. Once started it sustains itself on the step
edges.

## The row is not parallel, and says so

Every other locomotion row touches one body per iteration, so a pool can hand each
core a range of the roster. This one writes to two bodies at a time and the second
is not in its range. Nothing splits anything yet, so the claim costs nothing today
— and it is the difference between adding a pool later as a change to the tick and
adding it as an audit of every row.
