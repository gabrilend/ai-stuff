# 034-walking

How a body gets from one place to another.

## What it is for

**There is no pathfinding in this game.** No A*, no flow field, no per-tick search. A
body's position is always "on the edge between node 14 and node 15, 0.62 of the way
along," and advancing is: add speed divided by the edge's length to progress; if it
passes 1, step to the next node and carry the remainder.

With a thousand bodies on the map, that difference is the whole frame budget.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `step(world, id)` | | `true` if the body crossed at least one node. |
| `place_on_lane(world, id, lane, path_index, facing)` | | — The one way a body enters a lane. |
| `place_at_node(world, id, node)` | | — A body with no lane: a guard at its tower. |
| `mode_of(world, id)` | | Which of the four ways this body is moving. |
| `position_of(world, id)` | | — Writes `x` and `y` from the edge it is on. |
| `next_node` | *(table)* | The movement dispatch table. |

## The four ways of moving

Only *which node comes next* varies, and it is a dispatch on what the body is doing
rather than a branch inside the move loop.

| Mode | Used by | Next node is |
| --- | --- | --- |
| `lane` | everything with a lane | the next entry in the lane's path array |
| `wander` | a guard on patrol | a random neighbour still inside its leash |
| `home` | a guard leashing | whichever neighbour is nearer its tower |
| `toward` | a guard closing | whichever neighbour is nearer its target |

All four are "read one number out of a table." None searches.

## Movement is capped by speed **in the world**

`move_limited` takes a step in lane coordinates, measures how far the body actually
moved, and scales the step back if it went too far.

This is the correction for the one thing lane coordinates get wrong, and the error
was invisible until somebody asked for it to be measured. Holding a formation in
lane coordinates makes a turn free: every body in a rank shares one distance-along,
so going round a bend costs each of them the same number. But the body on the
**outside** has further to walk in the world, and nothing was telling it so — it was
covering that extra ground for nothing, moving faster than its own speed, silently.

Now the outer body genuinely falls behind its place, the inner one gets ahead, and
the cohesion budget does the rest. Turning left, the left of the line gives way and
the right hurries, which is what keeps it a line.

Measured in [the sandbox](../tests/060-the-formation-sandbox.info.md): through a
left bend the outer body covers 321 paces to the inner's 290, is hurried to a
multiplier of 1.0043 while the inner gives way to 0.9972, and the line never bends
more than 1.7 paces.

Three passes rather than a solve. Displacement is monotonic in the fraction, the
first correction is nearly exact, and a fixed pass count keeps the cost the same
every tick — which a search would not.

## Facing, and the one path array read two ways

Team 1 walks **up** the path array and team 2 walks **down** it. `facing` is +1 or
−1, and folding it into the index arithmetic is why there is one path array rather
than two. It is also why every "how far along am I" comparison in the project
multiplies by facing.

## Three details that are load-bearing

**The remainder is carried.** A fast body on a short edge can cross more than one
node in a tick; truncating at the first would make speed upgrades quietly stop
paying above a threshold nobody wrote down.

**The crossing loop is bounded** at eight steps rather than being a bare `while`. A
body that somehow cannot advance would otherwise spin forever, and a frozen frame is
a much worse symptom than a body that stops.

**Reaching the end of a lane is not an error.** `next_along_lane` returns 0, which
means the body is standing at the enemy library. It stops there and lets targeting
find the structure.

## Why a guard closing gets its own mode

Without `toward`, a guard with a target would keep random-walking and reach its
enemy only by luck — which reads as a guard that cannot see. The greedy
nearest-neighbour step is correct here and would not be in general: a guard only
ever chases inside its own leash radius, and the graph in there is a corridor. A
guard that needed a real path search would already have wandered further from its
tower than it is allowed to be.
