# 701 — Six spokes and no rim

Produces `src/050-sieve-topology.md`.

## Current behavior

**Done.** `src/050-sieve-topology.md` exists: six edges, one figure, and a
blueprint whose whole job is to justify an absence.

Five constraints. The one worth having derives the handoff traffic as a share of
what one stage reads and requires it to be under a thousandth — which turns *a
mesh would carry nothing* from an assertion into arithmetic that would notice if
a model shape ever made it false.

The correction the ticket carries is in the blueprint: **backpropagation is not
foreclosed by this topology.** Cutting a model by layer is pipeline parallelism
and a backward pass is the same stage-to-stage handoff in the other direction.
What limits training is memory.

**Nothing here could be revisited cheaply.** Adding a rim later means a second
link technology, a second timing closure, and a route through either the coolant
or the memory.

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

### What the absence costs, and what it does not

**Tensor parallelism is impossible.** Splitting one layer across several faces
requires an all-reduce between them every layer, which is exactly the face-to-face
traffic this topology refuses. So the model must be split by layer and only by
layer, which is `1101`'s constraint. The blueprint must state that in those words,
because it is the one thing this topology forecloses and somebody will want it
later.

**Backpropagation is not foreclosed, and the blueprint must say so** — this
correction matters because the opposite was assumed for a while. Splitting a model
by layer is pipeline parallelism, and a backward pass through a pipeline moves
gradients from stage *n+1* to stage *n*: the same stage-to-stage handoff the
forward pass already uses, in the other direction. It needs a second set of
staging buffers and nothing else from the interconnect. The all-reduce that
training is usually said to require belongs to data parallelism across replicas
and to tensor parallelism inside a layer, and this machine does neither.

What actually limits training here is **memory, not topology**, and it is `1107`'s
subject: full-parameter training of the reference model needs master weights,
gradients and optimiser moments at roughly twelve bytes per parameter — eight
hundred and forty gigabytes against sixty-four gibibytes. Low-rank adapter
training needs a few gigabytes and fits comfortably.

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
