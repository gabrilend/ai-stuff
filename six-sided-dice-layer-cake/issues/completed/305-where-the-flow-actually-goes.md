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

## What was missing, and how it was closed

**The network is solved.** `102` builds it from `304`'s assignment and runs it,
and the worst-served fraction is a `solved` value that the checker recomputes on
every pass rather than a `target` nobody could produce.

**It is bigger than this ticket estimated.** Twenty branches across eight nodes
was the guess, and it was the cube's own edges and corners rather than its
plumbing. The real object is **fifty branches across twenty-nine nodes**: supply
and return are separate networks that happen to share a geometry, every rail
carrying a plenum is two rails with a tap between them, and the corner blocks are
branches rather than junctions.

**It is not a linear solve either.** Three regimes meet in one circuit. The
microchannel fields are laminar and lose pressure in proportion to flow. The rails
are turbulent on Blasius and lose it as flow to the power one and three quarters.
Every plenum entry, corner tee and rail end is a fitting and loses it as the
square.

**Newton's method diverged, for a reason worth keeping.** The tangent of a
square-law branch at zero flow is zero, so its conductance there is infinite — and
on the first pass every pressure is still equal and half the branches are carrying
nothing, so half of them claim they will pass any flow for no pressure at all. The
first step is enormous, the pressures go negative, and the run ends in numbers with
forty digits. The secant has no such singularity: each pass computes the resistance
`dp/Q` each branch would have at its current flow, solves the resulting linear
resistor network exactly, and averages. Forty-three passes.

**The worst-served face is the mean face, exactly.** `304`'s chosen assignment has
a threefold symmetry that makes all six faces one face seen six ways, and no
arithmetic can separate them.

**So the thermal chain was moved onto the worst legal wiring instead.** Building
the junction temperature on a perfect distribution would make the whole thermal
budget depend on the plumbing being assembled to the drawing rather than merely to
the rules. `025` is given `f_worst_any` — the five and a half per cent shortfall of
the least even of the sixty-four legal arrangements. **This is the one substantive
design change the solve caused, and it makes the design more conservative rather
than less.**

**The single path overstates the circuit by a quarter.** `dp_loop` follows one
route from a fed corner to a drained one and charges it for two whole rails; the
real manifold delivers to each plenum from both ends at once. Eighteen point nine
kilopascals becomes eleven point four. The estimate was the conservative one, which
is the right way round, and `C-024-11` is what notices if it ever inverts.

**Six constraints were added.** Thirteen in `024` now, up from seven.

## What is still not done

**Part-flow behaviour is described and not plotted.** The claim that halving the
flow costs about four kelvin is arithmetic anybody can do, and `027` builds its
pump redundancy on it, so it should be a curve. `102` could produce it by solving
at a sweep of flows, which is a loop around something that already exists.

**No channel is ever blocked in this model.** `T2` in `009` asks how many of the
hundred and seventy-three channels in a field can stop before the face overheats.
Removing channels from one face's branch and re-solving is the experiment, and
`102` is now the place to run it.

**The pump curve is not overlaid.** The solve fixes the flow and reports the
pressure, which is the system curve at one point. A real pump has a curve of its
own and the duty point is where the two cross.

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
