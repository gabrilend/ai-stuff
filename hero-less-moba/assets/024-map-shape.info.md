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

## Where the width goes

`lane_width` feeds exactly two things: how many bodies the frontline queue lets
stand abreast, and how wide the renderer draws the lane. **It is not a movement
constraint** — soldiers walk the graph in single file regardless.

The centre being wider is topography, not a rule that switches on. Two even teams
meeting in a side lane fight rank against rank and a fourth body contributes
nothing until somebody dies; the same teams meeting in the middle get more bodies
into contact at once. Stacking a side lane is a bet on quality; stacking the
centre is a bet on quantity.
