# 701 — Six spokes and no rim

Produces `src/050-sieve-topology.md`.

## Current behavior

Nothing. "No face-to-face wire anywhere" has been asserted three times and never
argued.

## Intended behavior

**The interconnect graph: six radial links, face to cage, and nothing else.** A
short blueprint whose entire job is to justify an absence.

### The absence

There is no wire between any two faces. Everything one face sends another goes
into the core and comes out of it.

Three reasons, in descending order of how much they matter:

**Length.** A face-to-face wire runs around the outside of the cube or diagonally
across a cavity full of coolant and memory. Adjacent faces are sixty millimetres
apart the short way; opposite faces are a hundred and twenty. A face-to-core link
is seven. **A seven millimetre link and a hundred and twenty millimetre link are
different technologies**, not the same technology at different lengths — the long
one needs equalisation, retiming and far more energy per bit.

**Uniformity.** Fifteen face pairs, of two distinct distances, would mean two link
designs and fifteen timing closures. Six identical radial links mean one design and
one closure, which is the property `000` claims as a reason for the cube's shape
and this is where it is cashed.

**It is not needed.** The sieve's traffic is entirely stage *n* to stage *n+1*, and
that handoff is sixteen kibibytes against six gigabytes of weight traffic — four
parts in a million. Building a mesh to carry four parts in a million is not a
trade, it is a mistake.

### What the absence costs

**Tensor parallelism is impossible.** Splitting one layer across several faces
requires an all-reduce between them every layer, which is exactly the face-to-face
traffic this topology refuses. So the model must be split by layer and only by
layer, which is `1101`'s constraint and is why `009` entry B1 — whether this
machine ever trains — is blocking: training needs that traffic.

The blueprint must state this cost in those words, because it is the one thing
this topology forecloses and somebody will want it later.

### What is in the cage

Six link terminations, the crossbar from `504`, address decode, and the
distribution to thirty-two tiers. The cage is the rim the faces do not have, and
every path between two faces goes through it.

## Symbols this must publish

Link count. Link length. Face-to-face distances that would have been required, for
the comparison. Handoff size per token per sequence. Handoff traffic as a fraction
of weight traffic. Cage port count.

## Constraints this must assert

- Link count equals face count from `010`.
- All links have the same length. The uniformity claim, as a constraint that would
  catch a geometry change.
- Handoff traffic is under a stated fraction of weight traffic, which is the
  justification for having no mesh, expressed as arithmetic that would notice if
  the model shape changed enough to invalidate it.

## Suggested implementation steps

1. Draw the graph. It is six edges and takes one figure.
2. Write the three reasons with the distances derived from `012`.
3. Derive the handoff fraction from `1102`.
4. State the tensor-parallelism cost plainly and cross-reference `009` entry B1.

## Blocks

`702`, `703`, `704`, `1101`.

## Blocked by

`101`, `103`, `504`.

## Related documents

`003`. `000` for the equidistance claim this delivers.
