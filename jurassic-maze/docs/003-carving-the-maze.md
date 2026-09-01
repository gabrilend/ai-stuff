# Carving The Maze

The maze is not placed and it is not drawn. It is grown from a seed by six
passes over the grid, each of which may look only at what the previous one left
behind. Given the same seed, the same maze comes out, on any machine, forever —
see [named streams](005-randomness-comes-from-named-streams.md) for why that is
more than an aspiration.

## The lattice underneath it

The grid is not uniform. Every cell has one of three jobs, decided by whether
its x and y are odd or even, and decided before anything random happens:

| x, y | Name | What it is |
| --- | --- | --- |
| both odd | **room** | somewhere a body can stand. The maze's vertices. |
| one odd, one even | **link** | the single cell lying between two rooms. Either opened into a corridor or left as wall. The maze's edges. |
| both even | **pillar** | always wall, never opened, never considered |

This is the standard trick for carving a maze on a grid, and it is used rather
than storing walls between cells because a wall stored between cells is a second
data structure with its own indexing and its own edge cases at the border. A
wall stored *as* a cell is just a cell, and the entire maze — rooms, corridors,
and the stone between them — lives in the one array of columns that
[the stone](002-the-stone-and-what-is-inferred.md) already describes. There is
nothing else to keep in step with it.

The cost is that a `width × depth` grid holds only about `width/2 × depth/2`
rooms. That is the price of one-cell-wide walls, and one-cell-wide walls are
what the picture has.

The outermost ring is always wall. It is a rim, and it exists so that a body
which has gone wrong cannot leave the world — an aquarium with a hole in the
side is a bug report nobody can reproduce.

## One — the terraces

Every **room** is given a base height, in layers, by piling **nested** slabs:
each one smaller than the last and roughly on top of it, its centre wandering by
a fraction of its own size. That is the literal reading of what was asked for —
a successive layer of flat stones, rectangular, piled upon one another — and it
is a stepped mound, which is what the reference picture is.

Scattered rectangles of random size and position were tried first, and it is
worth recording why they were wrong, because the idea looks reasonable written
down. **Seventy overlapping rectangles do not make terraces; they make noise.**
Every rectangle edge is a height change, the edges land everywhere, and each room
ends up at however many rectangles happen to cover it. The result renders as a
field of individual cubes at a hundred different heights — a city, not a maze —
and the corridors stop being legible because the walls flanking one are all
different heights.

Nesting fixes it by making the edges few and long. Within one slab every room is
at the same height, so every wall on that terrace stands at the same height, so a
corridor reads as a channel between two long walls. That is the entire visual
difference between this and the picture.

A handful of small **outcrops** — bumps and hollows on top of the terraces — are
the only slabs allowed to be scattered, and there are few enough that they read
as features rather than as noise.

Heights are capped one wall-height below the top of the world, so that a wall
standing on the tallest possible room still fits. A rectangle that would push a
room past the cap simply does not lift it, which produces flat summits rather
than an error, and a flat summit is a real feature of a pile of slabs.

## Two — the staircases, placed before there is a maze to damage

**This pass runs second, and where it runs is the single most important thing on
this page.**

It used to run last: carve the maze, then cut staircases into it. That is what
the reference picture looks like — every staircase in it is a gash cut into the
side of a block, never a structure standing on top of one — and it is a disaster
as an algorithm. Cutting a flight into a maze that already exists means
overwriting cells the maze was relying on. The flight lands correctly, and
whatever was reachable *only* through the room it just dropped three layers is
severed. It joins two pieces and breaks a third, so the count of pieces does not
fall, so the flight is rejected — and the terrace it was trying to reach stays
unreachable while the diagnosis reports hundreds of perfectly good places to put
a staircase. Six hundred flights would be built and thrown away per maze.

The fix is not a better rejection test. It is to place the flights **first** and
let the maze be carved around them.

And placing them first is nearly free, because a flight can be expressed entirely
in the room heights. Rooms sit two cells apart, and the link between two rooms two
layers apart takes the height exactly between them — so **a run of rooms whose
heights step by two is already a staircase of single-layer steps**, once pass
four fills the links in. A flight from a room at height `h` to one `gap` cells
away at `h + gap` is therefore just: set the rooms along the way to `h+2`, `h+4`,
… and force the links between them open.

Nothing in this pass touches a cell of stone. Pass four builds the whole flight
out of the ordinary machinery, and the staircase is part of the maze rather than
a wound in it.

Which flights get placed:

- **Connectivity first.** Rooms are grouped into regions — maximal sets
  reachable through gaps of two layers or less, which on a pile of terraces four
  layers apart means one region per terrace. Then a spanning tree of flights over
  those regions, shortest first.
- **Then more than that**, at random, up to `extra_stairs` of the available
  sites. Same reasoning as braiding the links below: a maze with exactly one way
  up to each terrace is one where every journey is forced.

A room may belong to only one flight. Two staircases through one room would each
rewrite the other's steps and neither would climb.

## Three — the spanning forest

Now the maze proper. Every room is a vertex; two rooms two cells apart are
neighbours, filtered by height — a gap of more than two layers cannot be bridged
by the single cell between them. A randomized depth-first walk opens the link
between each pair it steps across, leaving a tree with exactly one route between
any two rooms it reached.

**A forest, not a tree.** A single walk carves exactly the terrace it started on
and stops, because it cannot step across a four-layer edge. Every other terrace
is then left with all its links closed — which is to say, left solid, a plateau
of undisturbed stone with nothing inside it that looks perfectly deliberate from
above. So the walk restarts from every room it has not reached, and each restart
carves another terrace.

The flights from pass two arrive already open, and the carver may add to them but
never take one away. A staircase the maze decided to wall off at one end is a
staircase to nowhere, and it would look entirely intentional.

The walk is iterative with an explicit stack. A recursive one blows the Lua stack
somewhere around a few thousand rooms, which a 129-cell maze reaches, and it does
it as a crash that looks nothing to do with the maze.

Then **braiding**: a `braid` fraction of the still-closed links are reopened at
random, where the height rule permits. A maze with no loops has one route between
any two rooms, so a chase has a known ending and the pursued creature is cornered
every time. [The games](020-games-that-creatures-play.md) need loops to exist at
all.

## Four — realising the columns

Only now does anything touch the array of columns.

| Cell | Its height |
| --- | --- |
| room | its height from passes one and two |
| opened link | the height between its two rooms: the same as both if they are level, the lower one if they differ by one, one above the lower if they differ by two |
| closed link, pillar, rim | the tallest neighbouring **room**'s height, plus `wall_rise` |

and the column for a cell of height `h` is every bit from layer 0 up to layer `h`
and nothing above.

`wall_rise` is **two layers**, and the number matters. A body may climb one
layer. A wall two layers above the corridor it flanks is therefore exactly one
layer taller than the tallest thing anybody can climb, which is the cheapest a
wall is allowed to be while still being a wall. Three would look heavier and
change nothing; one would turn every wall in the maze into a step and there would
be no maze.

Taking the tallest **room** in the surrounding three-by-three, rather than the
tallest neighbour of any kind, is what guarantees that. A wall's four neighbours
are floors whose heights are all at or below that tallest room, so the wall
stands at least two above every one of them.

## Five — the repair, which should find nothing

The connectivity check, and the pass that cuts a flight the old destructive way
if it finds one missing. On a healthy maze it cuts nothing.

It stays precisely because "nothing to do" is a claim worth testing on every
maze. If it ever starts cutting, the terraces have grown a shape pass two cannot
span, and that is worth knowing on the maze it first happens to rather than a
hundred mazes later. In practice it cuts a handful on some seeds, which is what
the sixth pass exists to clean up after.

Two things about how it measures, both of which were wrong first:

**It floods through floor only.** Flooding through every cell and then counting
which pieces happen to contain floor reports a maze as whole that is not: two
terraces with no staircase between them are joined, in that version, by any chain
of *wall tops* that happens to run from one to the other at climbable heights — a
route along the tops of the walls, which nothing can reach and nothing would
take.

**It steers by stranded floor, not by the number of pieces.** A repair flight that
joins two pieces and severs a third leaves the count unchanged, and a check
insisting the count fall rejects a staircase that did most of its job. How many
floor cells are outside the biggest piece falls whenever a flight brings in more
than it strands, which is the question actually worth asking.

Anything left that no flight can reach and that is smaller than `orphan_max` is
**filled in** — raised to wall height. A pocket of floor at the bottom of a shaft
with no straight run into it is not a place: nothing can get to it, nothing can
leave it, and a body spawned in it would stand there for the whole run. Removing
it is honest; papering over it with a tunnel is not. The count of what was filled
is in every report, so a change that starts quietly filling in a quarter of the
maze shows up as a number rather than as a maze that feels smaller.

Anything bigger than that is a **hard error**, with a diagnosis attached: per
piece, its size, its height range, how many straight runs out of it reach other
floor at all, and how much longer the shallowest flight would need to be. "It is
in four pieces" is not actionable; those numbers say which of a small number of
things went wrong.

## Six — putting the walls back

The repair pass cuts notches, and a notch raises floor that the walls beside it
were measured against in pass four. A wall beside a step that has risen to meet it
is no longer a wall — it is a step, in a place the renderer draws as a wall, which
a body can climb onto and then walk along the top of.

So every wall is re-measured against whatever floor is actually beside it now.
This is last, and running it before the repair leaves a handful of climbable
walls in a maze of sixteen thousand cells — precisely the sort of thing that is
never found by looking.

## The knobs

Every one of these lives in the maze parameters table, which is the only place in
the project any of these numbers appear. Documents refer to them by name and
never restate their values, so the numbers cannot go stale on this page.

| Knob | What it changes |
| --- | --- |
| `width`, `depth` | the footprint, in cells. Odd, so the lattice fits with a rim. |
| `layers` | how tall the world is allowed to be, at most 32 |
| `terrace_count` | how many slabs in the nested pile |
| `terrace_max`, `terrace_min` | the bottom slab's width and the summit's |
| `terrace_rise` | how many layers one slab adds |
| `terrace_wander` | how far a slab's centre strays. Zero is a wedding cake. |
| `outcrops` | small bumps and hollows on top, for irregularity |
| `wall_rise` | how far a wall stands above what it flanks |
| `climb_limit` | the tallest step a body may climb. One. Not a knob. |
| `braid` | the fraction of closed links reopened to make loops |
| `stair_steps` | the longest flight, in room-steps of two layers each |
| `extra_stairs` | flights beyond what connectivity demanded |
| `stair_rounds`, `stair_reach`, `stair_candidates` | what the repair pass is allowed to try |
| `orphan_max` | the biggest pocket that gets filled in rather than reported as a failure |
| `seed` | the whole thing |

## Related documents and tools

- [The stone and what is inferred](002-the-stone-and-what-is-inferred.md)
- [Standing somewhere and going elsewhere](004-standing-somewhere-and-going-elsewhere.md)
- `./run-tests` — the invariants, over a spread of seeds and shapes
- `./run-maze --describe` — one maze's statistics, without opening a window
