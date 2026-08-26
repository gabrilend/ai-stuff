# 305 — Where the flow actually goes

Produces `src/024-flow-network.md`.

## Current behavior

**Done in part.** `src/024-flow-network.md` exists with every branch resistance
derived from a geometry that another blueprint owns: the friction factor in the
microchannels is the laminar rectangular-duct polynomial rather than a circular
approximation, and the rails and corners take theirs from `016` and `015`.

Seven constraints. The counter-intuitive result is written down: in laminar flow
the convection coefficient does not depend on velocity, so halving the flow does
not halve the cooling -- it doubles only the coolant's own rise, which is a fifth
of the chain. `027` builds its pump redundancy on that.

## What is not done

**The network is not solved and the ticket asked for it to be.** The worst-served
fraction is a `target`, and the checker reports it as unfinished on every run.
Until it is solved the junction temperature in `025` rests on an estimate. **This
is the largest unfinished piece in the phase**, and it is blocked twice over.

**Blocked on a topology.** `304` has not enumerated which rail feeds which face,
so there is no network to solve even with a solver. Both tickets want the same
thing: a program holding the cube's eight corners, twelve edges and six faces as
data, rather than as prose in `010` and counts in `023`.

**Blocked on somewhere to put the answer.** The notation's four kinds are a
decision, a material property, an expression, and a goal. A solver's output is
none of those, and writing it as a `given` would invite the reader to argue with
it by choosing differently, and would go stale in silence the first time a rail's
cross-section changed. `1411` adds the kind that fits and the drift check that
keeps it honest.

**The solve is not linear.** The first estimate assumed it was. The microchannel
fields are laminar, so their loss rises with the first power of flow; the rails
are turbulent on Blasius, so theirs rises with the power one and three quarters;
the plenum entry losses go as the square. Three exponents in one network means
the answer comes from iterating rather than from one elimination, and the
blueprint should say which method and how far it converged.

**Part-flow behaviour is described and not plotted**, and `027` builds its pump
redundancy on the description.

## Intended behavior

**The hydraulic network solved: pressure at every node, flow in every branch, and
the pump curve that intersects the system curve at the design point.**

### Why it is not just a division

Six fields in parallel do not each take a sixth. They take shares set by their
resistances and by where they sit in the manifold, and the whole reason `304`
matters is that the parity arrangement makes those shares nearly equal — *nearly*
being the word this blueprint has to put a number on.

The network is small enough to solve exactly: eight corner nodes, twenty-four rail
branches, six field branches, one pump. Every branch's resistance comes from a
geometry already fixed by `203`, `204` and `022`, so there is nothing to fit and
nothing to assume.

### The resistances, in order

| branch | pressure drop | fraction |
|---|---|---|
| microchannel field | ~11 kPa | ~90 % |
| corner block division | <0.1 kPa | <1 % |
| edge rail | ~0.5 kPa | ~4 % |
| plenum and field entry loss | ~0.6 kPa | ~5 % |

**Ninety per cent of the loss is in the load.** That is the correct shape for a
parallel network and it is what makes the distribution robust: a manifold that is
ten per cent of the resistance can only introduce ten per cent of maldistribution
even if it is badly built. `204` and `203` were written to produce this and this
blueprint is where it is confirmed.

### What must be reported, not just computed

**The worst-served field.** Not the average. If one face gets eight per cent less
flow than its neighbours, its junction temperature is higher and `306` needs the
worst case, not the mean.

**The laminar assumption's validity.** Reynolds number in the microchannels is
about a hundred, solidly laminar. In the rails it is above two thousand and
transitional, which is the awkward regime where correlations disagree by tens of
per cent. The blueprint must say which correlation it used and how much the answer
would move under the other one — and since the rails are four per cent of the
loss, the honest answer is that it barely matters, which is itself worth stating.

**What happens at part flow.** The pump is not always at the design point. Halving
the flow does not halve the cooling, because the convection coefficient in laminar
flow does not depend on velocity at all — only the coolant temperature rise
doubles. This is a genuinely counter-intuitive and useful property and the
blueprint should show the curve.

### The pump

System curve from the network, pump curve from a real pump, and the intersection.
The blueprint should show that the intersection is on a flat part of the pump
curve, so that a small change in system resistance — a partially blocked channel —
does not move the operating point much.

## Symbols this must publish

Resistance per branch type, total system resistance, design flow, pressure at each
of the eight corner nodes, flow through each of the six fields, the worst-served
fraction, Reynolds numbers throughout, pump duty point, hydraulic and electrical
pump power.

## Constraints this must assert

- The worst-served field receives at least a stated fraction of the mean.
- Total loss at design flow is inside the pump's capability with margin.
- Field loss is at least eighty per cent of total loss. The manifold-transparency
  requirement, as a number.
- Flow in equals flow out at every one of the eight corner nodes. Conservation,
  checked node by node, which catches a network wired up wrong.
- Reynolds in the microchannels stays under two thousand three hundred at maximum
  flow, so the laminar derivation in `022` remains valid.

## Suggested implementation steps

1. Write the network as nodes and branches and let the checker enforce
   conservation at each node.
2. Get each branch resistance from its own blueprint rather than re-deriving it.
3. Solve and report the worst case, not the mean.
4. Do the part-flow curve and show the counter-intuitive result.
5. Overlay a real pump curve and mark the duty point.

## Blocks

`306`, `307`, `308`.

## Blocked by

`203`, `204`, `302`, `303`, `304`.

## Related documents

`005`. `027`'s loop is the other half of this network.
