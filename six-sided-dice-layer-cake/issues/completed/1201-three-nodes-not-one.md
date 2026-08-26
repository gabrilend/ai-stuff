# 1201 — Three nodes, not one

Produces `src/081-process-and-node.md`.

## Current behavior

**Done.** `src/081-process-and-node.md` exists with three nodes and a binding
constraint behind each choice.

It also **answers a question `036` left open**: a memory tier is forty millimetres
square and a reticle field is not, so tiers are stitched and compute dies are not.
`C-081-7` asserts it.

Two requirements arrived here from earlier phases and both are now checked rather
than remembered. **Plasma dicing**, handed over by `018`'s stress analysis, is a
constraint — somebody choosing a cheaper dicing process fails a check rather than
shipping cubes that crack. And the **microchannel aspect ratio** is checked
against a process that exists, which is the only place `022`'s geometry meets a
real etch capability.

**Stitching is named and not designed.** How the seam is handled, and what it
costs in yield, is not written and `083` needs it. **And the cost figures are
relative and arbitrary**, so that ratios mean something in `088` and prices do
not.

## Intended behavior

**Which silicon process each part of the machine is made on, and why they are not
all the same one.**

### Three, and the reason for each

**The compute dies** want the newest node available: half of their area is static
memory whose density sets the slice, and the other half is multipliers whose
switching energy sets the power. Both improve with the node and both are binding
constraints. This is where the money goes.

**The memory tiers** want a node optimised for array density and low leakage
rather than for logic speed. `502`'s one and a half megabytes per square
millimetre assumes a dedicated array tier with the periphery elsewhere, and the
process that gives the best bit cell is not the process that gives the fastest
transistor.

**The interposers, the cage's passive layers, and the silicon cold plates** want
nothing modern at all. They are wiring, capacitors and etched channels. An older
node is cheaper, yields better on a large area, and — for the cold plates —
supports the deep etching that `022`'s one millimetre channels need, which a
leading-edge line will not do.

### Reticle and stitching

`602` established that a face is four dies because the reticle field is about
twenty-six by thirty-three millimetres. The **memory tiers** are forty millimetres
square and hit the same wall, so a tier is also multiple dies, or is stitched.
`503` did not say which and this blueprint must.

**The silicon cold plate is fifty-two millimetres square** and needs no
lithography finer than tens of microns, so it is a single piece on a coarse line
with no reticle problem at all. Worth stating, because it looks like it should
have one.

### What the choice costs

Three processes means three mask sets, three qualifications, three suppliers and
three yield curves that must all be good on the same day for a cube to exist.
`1203` carries the yield consequence; this blueprint carries the **schedule and
supply** consequence, which is that the machine's availability is the intersection
of three, and the blueprint should say so plainly rather than leaving it to be
discovered.

## Symbols this must publish

Node per part. Bit cell area, logic density and leakage per node. Reticle field.
Dies per tier and the stitching decision. Cold plate etch depth and aspect ratio
against the process capability. Mask set count. Wafer cost per node, as `measured`
with a source.

## Constraints this must assert

- Bit cell area at the memory node gives `502`'s areal density.
- Logic density at the compute node fits `601`'s floorplan into `012`'s die.
- Cold plate etch aspect ratio is within the named process's capability. The
  constraint most likely to be violated silently, because a one millimetre deep,
  hundred and fifty micron wide feature is an aspect ratio of nearly seven.
- Die and tier dimensions are under the reticle field, or the stitching decision
  is stated.

## Suggested implementation steps

1. Choose the three and give each its reason from a binding constraint.
2. Settle the tier stitching question `503` left open.
3. Check the cold plate etch against real process capability.
4. State the three-way supply intersection.

## Blocks

`1202`, `1203`, `1302`.

## Blocked by

`022`, `502`, `503`, `601`, `602`.

## Related documents

`012` for the dimensions these processes must produce.
