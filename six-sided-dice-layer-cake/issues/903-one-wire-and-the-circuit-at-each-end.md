# 903 — One wire, and the circuit at each end

Produces `src/064-spout-driver-and-receiver.md`.

## Current behavior

Nothing. Ten femtojoules per bit is asserted in `007` and `901` with no circuit
behind it.

## Intended behavior

**The transmitter and receiver for one conductor, designed under a constraint that
dominates everything: it must fit and work sixteen million seven hundred and
seventy-seven thousand two hundred and sixteen times.**

### The constraint that shapes it

A ten micron pitch gives a hundred square microns per conductor, and a share of
that has to hold the pad itself. **The circuit gets a few tens of square microns**,
which rules out anything with a current source, a bias network, an amplifier, or
any per-lane calibration state.

What is left is an inverter driving a pad and an inverter receiving it. The
blueprint should say that plainly, because it is the correct answer and it sounds
too simple until the area budget is stated.

### Why that works here and nowhere else

The bond is ten microns long. It carries perhaps a femtofarad, has no meaningful
inductance, no reflection to speak of, and no attenuation. Every technique a
serial link needs — equalisation, clock recovery, termination, calibration —
exists to fight a channel this one does not have.

The blueprint must state the **reach** over which that is true, so that nobody
reuses the circuit for the cabled grade in `906`, where the channel is a metre of
twinax and every one of those techniques comes back.

### The energy

Ten femtojoules is capacitance times voltage squared, plus the driver's own
switching. The blueprint must derive it rather than quote it, from `902`'s pad
geometry and `402`'s supply, because the whole burst framing in `901` and the
thermal transient in `026` scale directly with it.

**And it must derive the worst case**, not the average: all sixteen million
conductors switching in the same direction on the same edge is the maximum, and it
is not a rare pattern — a pane of zeroes followed by a pane of ones is an ordinary
thing for memory to contain.

### The simultaneous switching problem

That worst case is the hard part of this ticket. Sixteen million drivers changing
state together pull a large current spike through the local supply, and the
resulting bounce is seen by every receiver at once as a shift in its own reference.

Three mitigations, and the blueprint must pick and price:

- **Ground density.** `902`'s one-in-five, justified here rather than assumed.
- **Stagger.** Fire tiles in a fixed sequence over a few hundred picoseconds
  rather than all at once. Costs a little of the edge, and is nearly free given
  that `904` already tolerates half a nanosecond of tile skew.
- **Data conditioning.** Invert a tile's data when it would reduce transitions, and
  send one bit saying so. Costs one conductor in four thousand and ninety-six and
  halves the worst case.

**Stagger plus conditioning is the likely answer** and both are cheap because the
tiling already exists.

## Symbols this must publish

Driver and receiver area per conductor. Pad capacitance. Energy per bit at the
supply voltage. Worst-case simultaneous switching current per tile and for the
array. Supply bounce and receiver margin. Reach limit. Stagger interval.
Conditioning overhead. Receiver sensitivity.

## Constraints this must assert

- Circuit area per conductor fits inside `902`'s pitch, after the pad.
- Energy per bit times pane size equals `901`'s pane energy.
- Supply bounce at the worst-case switching pattern, after mitigations, leaves the
  receiver its stated margin.
- Stagger interval is inside `904`'s tile skew tolerance, so the mitigation costs
  nothing already spent.
- Reach limit is stated and is shorter than `906`'s channel, so the two grades
  cannot be confused.

## Suggested implementation steps

1. State the area budget first; it eliminates most of the design space.
2. Derive the energy from geometry and supply rather than quoting it.
3. Work the all-switching worst case honestly.
4. Choose stagger plus conditioning and show both are free against existing
   tolerances.
5. State the reach limit loudly.

## Blocks

`904`, `905`, `907`, `909`, `026`.

## Blocked by

`402`, `901`, `902`.

## Related documents

`007`. `064` is the smallest circuit in the project and the most copied.
