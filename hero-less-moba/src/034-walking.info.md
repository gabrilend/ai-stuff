# 034-walking

How a body gets from one place to another.

## What it is for

**There is no pathfinding in this game.** No A*, no flow field, no per-tick search. Every
route anything could take was decided when the map was built, and a body's whole idea of
where it is going is one number that goes up.

With a thousand bodies on the map, that difference is the whole frame budget.

## Two layers, and only the lower one knows other bodies exist

**A goal** — a point in the world and a pace — is placed fresh every tick by the body's
[movement pattern](072-the-movement-patterns.info.md). It may be a very long way off: a
formation's place for a body can be ninety paces away. A pattern may not look at whether
anything is standing between here and there.

**A step** — the point the body will actually occupy at the end of this tick — is derived
from the goal by three rules in order:

| | |
| --- | --- |
| **cap** | pulled back along the line to the body until it is no further off than this pace allows, measured **in the world** |
| **clear** | moved out of anybody standing on it, by the rule that already exists, asked about the step and not the goal |
| **place** | written through whichever representation this body's position lives in |

### What the cap replaced

Holding a formation in lane coordinates makes a turn free, so a body on the outside of a
bend was covering more ground in the world than its speed allowed. That used to be caught
*afterwards*: measure how far it actually went, scale the step back, three passes.

Capping a world point at a world distance means the extra ground is never taken. There is
nothing to roll back — the outer body simply falls behind its place, honestly, and the
gears deal with it.

### Why there is a conversion at all

A body on a road keeps how far along its lane it has got and how far across it stands, and
its world position is derived from those. Anything with no lane — a guard, or a hero partway
across a connector — keeps its world position and nothing else. Every rule that ever wanted
to move a body had to know which kind it was holding, **and two of them got it wrong** —
writing a world position into a lane body, watching the next move pass re-derive it, and
achieving nothing while firing every tick. Intentions are one currency now, and one
function converts.

A guard used to be a third kind: a node, a fraction along an edge, and an offset in world
paces to stand it clear of whoever else was at the same tower. [216d](../issues/216d-a-guard-is-still-an-edge-walker.md)
made it a point, and the offset went with it.

### One thing that has not moved

A marching body's goal is computed **in lane coordinates and converted at the end**. That
is what makes a rank curve round a bend as a rank, and it is a property of how the goal is
worked out rather than of how it is stored. Nothing in the layer below cares — which is
also the risk, since nothing enforces it either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `place_on_lane(world, id, lane, path_index, facing)` | | — The one way a body enters a lane. |
| `place_at_node(world, id, node, beside_x, beside_y)` | | — A body with no lane: a guard at its tower. It stands at the node plus the displacement given, which is required whenever more than one body is put at one node, because a node is a point and a point holds one body. Both of its graph nodes are set to this one. |
| `arrived_at_node(world, id, node)` | | `true` once the body is within a body's room of the node — measured from the face of any live building standing on it. |
| `next_patrol_node(world, id)` | a guard | A random neighbour of the node it last reached, inside its leash, from the wander stream. |
| `round_the_stone(world, id, x, y)` | a goal | The same goal, or the side of a building to aim at first when the straight line to it runs through one. |
| `clear_step(world, id, delta_along, delta_across)` | a step in lane coordinates | The same step, moved if it would end inside somebody. |
| `set_lane_position(world, id, along, across)` | | — Puts a body at a distance down a lane and an offset from its centre line. |
| `project_onto_lane(world, lane, x, y, hint)` | | Where on that lane a point in the world is. |
| `move_limited(world, id, along, across, allowance)` | | — A step capped by a distance **in the world**, so a body on the outside of a bend cannot buy ground by being offset. |
| `aim(world, id, x, y, pace)` | | — Writes down where a body wants to be. |
| `aim_on_lane(world, id, along, across, pace)` | | — The same, for a goal said in lane coordinates. |
| `take_step(world, id)` | | — Cap, clear, place: one tick of movement. |
| `place_at(world, id, x, y)` | | — Puts a body on a world point, through its own representation. |
| `nudge(world, id, dx, dy)` | | — The same, said as a displacement. |
| `step_in_formation(world, id)` | | — One body's step toward its place in its wave. |
| `march_pass(world)` | | — Every formed body's step, in one pass. |
| `step_toward_point(world, id, along, across)` | | — Closing on something, with no cohesion applied. |
| `begin_crossing(world, id, connector, from_lane)` | | — Onto a connector between lanes. |
| `step_crossing(world, id)` | | — Along one. |

## The march pass, and why the loop is here

`march_pass` is three lines and looks like the kind of thing a caller can be trusted to
write. It was written out by hand in [the arena](068-the-arena.info.md) for exactly that
reason, which left the project holding two descriptions of what a marching tick is — one
of them the game's and one of them a test harness's. When they disagree, the test is
measuring the harness.

A body with no wave is a **stray**: nothing keeps it in a line and nothing comes to
collect it, so the pass steps over it. That is not an omission — a stray is the thing an
army has to get past, and it has to be able to stand still to be one.

## A guard, and the graph it consults

A guard moves like everything else — its row in [the pattern table](072-the-movement-patterns.info.md)
places a goal, and the step layer caps, clears and places — and the graph is a thing it
*asks* rather than a thing it is on.

| Row | Aims at | Asks the graph? |
| --- | --- | --- |
| `patrol` | the next node of its wander, chosen at random from the neighbours inside its leash | yes, each time it reaches one |
| `leash` | the node it is leashed to | no — it is never more than a leash radius from home |
| `chase` | its target's skin, never past the rope | no — its target is inside its ground |

`node_from` is the last node a guard reached and `node_to` the one it is aiming at. Neither
says where it *is*; that is its x and y.

**Reaching a node is "near enough", not "on it".** A guard aiming at its own tower's node can
never stand there: the masonry is in the way, and the rule about standing in stone puts it
back on the face every tick. So a node counts as reached from a body's room away, measured
from the outside of whatever building stands on it. The same test is what *home* means for a
guard walking back to its leash — which it was not, before: home was a fixed eighteen paces
from the leash node, and a base guard, leashed to a library twenty-one paces in radius, could
never get that close.

**And a guard walks round its tower rather than into it.** One that has reached its tower's
node, on the road, and picks the neighbour on the far side is standing dead in line with the
tower and the place it wants to be. The step layer's correction runs along the line from the
building's centre, and head-on that line has no sideways in it: the guard is put back where
it started, every tick, for ever. `round_the_stone` aims it at the building's side first.
Only stone — a building does not move, so going round it is a question about where to want
to be. Bodies move, and whether one is in the way stays the step layer's question.

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

**Run [the sandbox](../tests/060-the-formation-sandbox.info.md) for the numbers.**
It walks a formation through a left bend and writes out how much ground the outer
and inner bodies each covered, what multiplier each was given, and the worst the
line bent — into a log, every run.

They are not quoted here on purpose. They were, and then the bodies were spread
further apart, and the paragraph went on stating measurements of a formation the
game had stopped building. A number in a document is a number that will be wrong;
the tool that produces it cannot be.

Three passes rather than a solve. Displacement is monotonic in the fraction, the
first correction is nearly exact, and a fixed pass count keeps the cost the same
every tick — which a search would not.

## Facing, and the one path array read two ways

Team 1 walks **up** the path array and team 2 walks **down** it. `facing` is +1 or
−1, and folding it into the index arithmetic is why there is one path array rather
than two. It is also why every "how far along am I" comparison in the project
multiplies by facing.

## A guard used to stand still for the whole match

Worth writing down because nothing noticed. A guard's position was an edge and a fraction,
and a guard was put out with **both ends of its edge on the tower's own node** — an edge of
length nought, which the walk stepped over rather than divide by. It never crossed a node, so
it never asked where to go next, so no guard ever patrolled and no guard ever closed on
anything; the few that seemed to move were being shoved by the crowd. "No guard ever enters
the leashing state", which a scenario recorded as a finding about ordinary play, was this.
