# 101 — The Path Graph Is Built by a Tool

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | — |
| Blocks | 102, 103, 202, 301, 305, 508 |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md) |
| Open questions | none |

## Current behavior

The map builder emits the path graph from the shape parameters, and the map
validator refuses a malformed one at load rather than repairing it — which is what
lets the movement loop have no nil checks anywhere in it. Three junctions on the
other diagonal, bends rounded into curves, and both halves exact mirrors of each
other, which the validator asserts.

It also emits a standalone lane from any list of points, which was added so the
formation could be measured on a bare field.

## Intended behavior

A map-building tool takes a small table of shape parameters and emits a **path
graph**: a flat array of nodes, each with a position, a kind, a lane, a
milestone index, a team side, a neighbour list, and a structure slot. Everything
that will ever walk, walks on this graph.

The standard map it emits: two bases at opposite corners of a square field, three
lanes joining them.

**There are three junctions, not four**, and they sit on the field's *other*
diagonal — the top-left corner, the middle of the field, the bottom-right corner.
Each side lane bends once at its own corner; the centre lane's junction is its
midpoint, a plain point on a straight line rather than a bend. A short
**connector** joins each side lane's junction to the middle, which is the ground
the jungle used to occupy with everything that made it jungle taken out.

Giving the centre a junction of its own is what makes the middle a place a body can
*leave*. An earlier version of this issue described four junctions, all of them on
side lanes, which meant anything walking into the centre was committed to it
permanently — a decision nobody ever made. See
[the map](../docs/002-the-map-and-its-milestones.md).

**The bends are rounded rather than sharp.** A vertex is a corner no formation can
walk round: capped by the distance actually travelled, the body on the outside would
have to cover most of a right angle's arc in a single step.

The graph is authored once and never changes at runtime. It lives in one
contiguous array, is read-only during a match, and is shared across every worker
in the thread pool without a lock.

There is no map editor and no hand-editable map file. **Never create a map
manually; create the tool that creates maps.** A map that has been hand-tweaked
cannot be regenerated, and a map that cannot be regenerated is a map nobody dares
change.

No field of a node is ever nil. A node with no structure on it holds the integer
zero. Whether the builder got that right is the validator's question, asked once
at load, not the movement loop's question asked a thousand times a tick.

## Suggested implementation steps

1. Write the node record as a flat struct-of-arrays. Fields are listed in the map
   document; every one of them is an integer or a double.
2. Write the shape parameter table: field size, lane spacing, connector length,
   distance between milestones, and **a width per lane**. These are the only
   inputs.
3. Emit the center lane first — it is a straight run of evenly spaced nodes and
   it is the easiest thing to check by eye.
4. Emit a side lane as two straight runs joined at **one** junction node, at its
   own corner. Mirror it for the other side lane.
4b. Round the bend before measuring anything, and measure the arc lengths after --
   they are distances between nodes the rounding moves.
5. Emit the connectors, joining each junction to the nearest center-lane node.
   Give connector nodes `lane = 0` so nothing treats them as part of a lane.
6. Write a **map validator** that runs at load and refuses to continue if: any
   node has an empty neighbour list, any lane's path does not reach from one
   library to the other, the two halves are not exact mirrors, or any milestone
   index is missing. A refusal names what was missing and where. It does not
   substitute a default.
7. Write a text dump that prints the graph as a coordinate list, so the graph can
   be checked before anything can draw it.

## Lanes have a width, and the center's is greater

Each lane carries a **width** in paces, and the **center lane's is larger than the
side lanes'.** Permanently, as topography — not a rule that switches on during a
challenge.

The width feeds exactly two things and nothing else: how many bodies the
frontline queue lets stand abreast (issue 206), and how wide the renderer draws
the lane. **It is not a movement constraint.** Soldiers still walk the path graph
in single file; width only decides how many of them may stop at the same point on
it.

The immediate reason is the challenge phase, where all three lanes' production
funnels into the middle and a monster has to be able to fight a whole team at
once rather than a single file waiting its turn to die. The permanent reason is
larger: **the center lane is where numbers matter most.** Two even teams meeting
in a side lane fight rank against rank and a fourth body contributes nothing
until somebody dies; the same teams meeting in the middle get more bodies into
contact at once.

That is the only real difference between the three lanes, and it is one number in
this table. Stacking the top lane is a bet on **quality**; stacking the center is
a bet on **quantity**.

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- The map validator (this issue creates it)
- The map text dump (this issue creates it)

## Still open

Does the builder ever need to emit a non-standard map — more lanes, asymmetric
shapes, a different junction count? If the standard map is permanent the builder
can be far simpler, and the milestone system can keep assuming nine.
