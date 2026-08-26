# 608 — The thing that walks a layer

Produces `src/048-face-sequencer.md`.

## Current behavior

**Done.** `src/048-face-sequencer.md` exists with the descriptor chain specified
exactly, because `085` will need somebody to build one by hand on a bench.

It carries the three things the ticket noticed it also does: the prefetch, the
sixty-four cycle current ramp that `031` sized its decoupling against, and
`039`'s two barriers. It adds a fourth — the four sequencers on a face agree once
per layer rather than once per operation, which is the difference between thirteen
interposer crossings a token and a hundred and sixty.

Six constraints, all holding.

**Chains are built rather than patched.** If nothing in a chain is
token-dependent besides the position, the scalar core's four hundred instructions
collapse to almost nothing, and nobody has checked.

**The buffer swap at a layer boundary is not specified** and it recurs thirteen
times a token.

## Intended behavior

**The state machine that executes a transformer layer from a descriptor chain
without the scalar core touching a single step.**

### Why it exists

A layer is normalise, three projections, positional rotation, attention over the
cached keys and values, an output projection, a residual add, another
normalisation, a gated feedforward, and another residual add. About a dozen tensor
operations, thirteen or fourteen times per token per face, with every operand
address a function of the layer index and the head index.

A scalar core issuing those would be in an inner loop, and `604` established that
a scalar core in an inner loop is a bug. So the sequencer takes a chain of
descriptors and walks it: computing addresses, issuing engine operations, waiting
on the slice, and advancing.

### What it also does, which is not obvious

**The prefetch.** While walking layer *n* it issues the core reads for layer *n+1*
into the other slice buffer. `805` owns the policy; the sequencer is the mechanism
and the two must not disagree about who decides when.

**The current ramp.** `404` needs the engine to reach full activity over sixty-four
cycles rather than one, which divides the peak supply slew by sixty-four. The
sequencer is what does that, by admitting operands progressively at the start of an
operation. It is three lines of state machine and it is worth twenty-two millivolts.

**The barriers.** At the end of a layer chain, the sequencer writes the staging
buffer and executes `506`'s release. At the start, it waits on the acquire. These
are the only points in a whole token where a face touches another face's data.

**The four-die synchronisation.** `602` leaves open whether there are four
sequencers in lockstep or one driving four dies. If four, they must agree at layer
boundaries, and the mechanism for that agreement is this blueprint's.

### The descriptor chain

The real content. A descriptor names an operation, its operands' addresses and
shapes, its output, and the next descriptor. A layer is a chain; a face's whole
token is thirteen chains; and the chains for a given model are **built once at load
time and reused for every token**, which is why the scalar core's few hundred
instructions per token are enough.

The blueprint must specify the chain's memory layout exactly, because `1205` will
need to build one by hand on the bench.

## Symbols this must publish

Descriptor format and size. Chain length per layer. State machine states and
transitions. Address generation rule per operand class. Prefetch trigger point.
Ramp length in cycles. Barrier placement. Synchronisation mechanism and its cost.
Area and power. Small reads per token, which `507` needs.

## Constraints this must assert

- Chain length times descriptor size fits in the sequencer's local storage or the
  slice, whichever holds it.
- Prefetch trigger is early enough that the next layer's weights are resident
  before they are needed, at the worst-case core latency from `703`.
- Ramp length matches the figure `404` sized the decoupling against.
- Small reads per token matches the number `507` used to choose its correction
  granularity.
- Area and power within `601`.

## Suggested implementation steps

1. Write the twelve tensor operations of a layer as a chain and count it.
2. Fix the descriptor layout, exactly, because a person will type one.
3. Draw the state machine.
4. Specify the prefetch trigger from `703`'s latency and `805`'s policy.
5. Add the ramp and the barriers.
6. Resolve the four-die synchronisation with `602`.

## Blocks

`704`, `805`, `1205`.

## Blocked by

`602`, `603`, `604`, `605`, `607`, `506`.

## Related documents

`003` for what a layer does. `004` for the prefetch it drives.
