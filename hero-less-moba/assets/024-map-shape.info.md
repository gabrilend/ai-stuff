# 024-map-shape

The map's shape parameters — every number that decides where the ground is.

Read this rather than the source. The source is a table of numbers with comments
on each; this is what they mean together.

## What it is for

No document in this project quotes a distance, because a document that quotes a
number is a document that will be wrong. They live here instead, and the map
validator and the map builder are the only things that read them.

The picture the numbers describe: a **square field**, team 1's library set in from
the bottom-left corner and team 2's from the top-right, so the two bases face each
other along one diagonal. The **other** diagonal — top-left corner, middle,
bottom-right corner — is where the three junctions stand.

Coordinates are in **paces**, with y increasing downward to match the screen.

## Exports

| Name | Type | Meaning |
| --- | --- | --- |
| `parameters` | table | The whole shape, described below. |

## The parameter record

| Field | Type | Meaning |
| --- | --- | --- |
| `field_size` | double | One side of the square field, in paces. Everything else is measured against it. |
| `base_inset` | double | How far a library sits in from its corner. The base is the wedge between the two. |
| `node_spacing` | double | Target paces between two plain lane nodes. Smaller is a finer graph and a slower move pass, and nothing else. |
| `connector_nodes` | integer | How many nodes a connector is built from, not counting the junctions at either end. |
| `milestone_fraction` | double[0..8] | Where each milestone sits along its lane, as a fraction of the lane's length from team 1's library to team 2's. **Indexed from 0** — do not take its length. |
| `milestone_count` | integer | Nine. Walk `milestone_fraction` with this rather than with `#`. |
| `lane_width` | double[1..3] | How many paces across each lane is. The centre's is larger. |
| `personal_space` | double | How far apart two bodies stand when queueing. |
| `bend_smoothing_window` | integer | How many nodes each way of a junction may move when the corner is rounded. |
| `bend_smoothing_passes` | integer | How round it gets. |

## The two properties a reader should know

**The fraction table is a mirror of itself.** `fraction[k] + fraction[8 - k] == 1`
for every k, and [the map validator](031-map-validator.info.md) asserts exactly
that. An asymmetric table would hand one team a shorter walk, and nothing else in
the project would ever notice.

**Milestone 4 is fixed at 0.5** and this is not a preference. Every side lane
bends at its own corner, and because the two libraries are mirror images, that
bend falls at exactly half the lane's length. [The map
builder](030-map-builder.info.md) places every other milestone relative to it, so
moving milestone 4 off the midpoint breaks the placement of all the others rather
than merely shifting one mark.

## The corner is rounded, and it has to be

A lane's junction used to be an infinitely sharp corner — two straight legs meeting
at a vertex — and a body walking it turned ninety-odd degrees between one tick and
the next.

That was invisible for as long as a formation could teleport round the outside of a
turn, and became a hole in the map the moment movement was capped by the distance
actually travelled: the body on the outside needed to cover most of a right angle's
arc in one step, could not, and fell most of a formation's length behind.

So the nodes either side of the bend are relaxed toward their neighbours, which cuts
the corner into a curve. At sixty passes the sharpest turn on a side lane is about
eleven degrees per step instead of ninety-nine, and a formation rounds it losing
seven paces of cohesion rather than seventy-five.

**Real roads do not have vertices.** And a curve is what makes "the formation curves
to match the path it is on" a sentence with something to match.

The junction node **moves and keeps its identity** — same id, same milestone index,
same sign-post standing on it — so everything that refers to the junction goes on
referring to the same node. The relaxation is symmetric about the bend, so a lane
that mirrored itself before still does, which the map validator checks.

## Where the width goes

`lane_width` feeds exactly two things: how many bodies the frontline queue lets
stand abreast, and how wide the renderer draws the lane. **It is not a movement
constraint** — soldiers walk the graph in single file regardless.

The centre's width is **derived rather than chosen**. Three formations stand abreast
there during a challenge — a side lane's, the centre's, and the other side lane's —
and the width is how much road that takes: the centre's own radius, plus a side
lane's on either side, plus the gaps. 136 paces of formation in 140 of road.

That is what the centre lane is wide for, and it is the reason the documents gave
for widening it before there was arithmetic to put behind it.
