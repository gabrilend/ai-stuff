# 602 — Why a face is four dies

Produces `src/042-face-tile-and-reticle.md`.

## Current behavior

**Done.** `src/042-face-tile-and-reticle.md` exists and states plainly that four
dies is a lithography limit rather than a decision, so that nobody revisits it as
though it were one.

Both open questions the ticket left are answered. The radial link is **split four
ways** rather than relayed through one die, which costs the cage more logic and
keeps the four dies identical — and identical dies are what make `083`'s yield
arithmetic tractable. The sequencers are **four in lockstep** rather than one
driving four dies over an interposer.

Six constraints, all holding.

**The inter-die crossing fraction is a `given`.** Two per cent is what a
partitioning that works looks like; nothing has computed what `075`'s actual
assignment produces, so the constraint is checking an assumption against a budget
rather than a design against a requirement.

## Intended behavior

**The reticle limit, what it forces, and how four dies are made to behave as one
face.**

### The constraint

A photolithography scanner exposes a field of about twenty-six by thirty-three
millimetres. Nothing larger can be printed in one exposure. A face wants to be
fifty-two millimetres square — two thousand seven hundred and four square
millimetres — which is more than three times the largest die that can exist.

So a face is a tile array, and the only remaining questions are how many tiles and
how they are joined. Two by two, twenty-four millimetres each, is the answer that
fits: five hundred and seventy-six square millimetres per die, two thirds of a
reticle field, leaving margin for the scribe lane and for yield.

**This is not a design decision and the blueprint should say so.** It is a physical
limit the design accommodates, and treating it as a choice invites somebody to
revisit it.

### What four dies have to pretend

The face has to look like one thing to the rest of the machine. Three things must
be arranged for:

**One radial link, not four.** `702`'s interface is per-face. Either one die
carries the link and relays for the other three — which makes it asymmetric and
hotter — or the link is split four ways and the cage sees four half-width ports it
treats as one. The second is better and costs the cage more logic; the blueprint
must choose and price it.

**One slice, not four.** The nine hundred and twenty-two megabyte slice is four
lots of two hundred and thirty and the sequencer wants to address it as one. That
means die-to-die traffic for any access that crosses a boundary, which means the
layer's weights must be **partitioned so that crossings are rare** — each die owns
the rows of the weight matrix its own multipliers consume.

**One sequencer, or four in lockstep.** Four sequencers each walking a quarter of
the layer, synchronised at layer boundaries, is simpler than one sequencer driving
four dies over an inter-die link. `608` decides; this blueprint states the
requirement.

### The inter-die link

Twenty-four millimetre dies, one millimetre apart, on a shared interposer. Short,
so cheap in energy, but not free, and the traffic across it is whatever the
partitioning failed to avoid. The blueprint must estimate that traffic from `1102`'s
dataflow rather than assuming it is small.

## Symbols this must publish

Reticle field dimensions. Die dimensions and area. Dies per face and their
arrangement. Scribe lane and street widths. Inter-die link width, energy per bit,
and estimated traffic per token. Radial link split ratio. Slice partitioning
granularity.

## Constraints this must assert

- Die area is under the reticle field with a stated margin.
- Die block dimensions from `012` equal the die and street arithmetic.
- Inter-die traffic per token is under a stated fraction of radial link traffic,
  or the partitioning in `1101` is wrong.
- The four radial link segments sum to the per-face bandwidth in `501`.

## Suggested implementation steps

1. State the reticle limit and derive the tile count.
2. Choose split-link over relay-link and price the cage's extra logic.
3. Define the slice partitioning that keeps crossings rare, from `1102`'s dataflow.
4. Estimate inter-die traffic and assert against it.
5. Hand the sequencer requirement to `608`.

## Blocks

`607`, `608`, `702`, `1203`.

## Blocked by

`103`, `601`, `1201`.

## Related documents

`000` for the face picture. `1203` for why die size and yield are the same
question.
