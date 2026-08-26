# 404 — Holding the rail up for ten nanoseconds

Produces `src/031-decoupling-and-impedance.md`.

## Current behavior

**Done.** `src/031-decoupling-and-impedance.md` exists, and the ramp turns out to
be worth more than the ticket estimated.

Without it, a die needs twenty-seven microfarads — two hundred and seventy square
millimetres of trench capacitor under a five hundred and seventy-six square
millimetre die, which does not fit alongside anything else. Admitting operands
over sixty-four cycles does not change the total current, it changes how fast it
arrives, and the charge deficit while a regulator catches a ramp is the area of a
triangle rather than a rectangle. Three microfarads instead of twenty-seven, for
forty-five nanoseconds at the start of a layer that takes a hundred and fifty
microseconds.

Six constraints. The impedance one is written to fail when somebody removes a
capacitor bank without checking what it was damping.

**Nothing models six dies stepping at once.** At the crossover batch all
twenty-four switch together, and whether their steps correlate is `053`'s
schedule — if they do, the planes and the via islands see twenty-four times the
slew and neither has been checked for it.

## Intended behavior

**The impedance the power network must present, across frequency, and the
capacitance that produces it.**

### The problem

A matrix engine is two hundred and fifty-six by two hundred and fifty-six cells
that either have operands or do not. It goes from idle to fully switching **in one
clock cycle**: seventy-six point seven amperes in about a nanosecond, seventy-seven
billion amperes a second.

A regulator, however good, takes tens of nanoseconds to respond. In between,
nothing holds the rail up except stored charge. The charge required is the current
step times the response time divided by the droop allowed:

    C = I_step * t_response / dV_droop

Seventy-six point seven amperes, ten nanoseconds, twenty-two millivolts:
**thirty-four microfarads, per die.** At the roughly hundred nanofarads per square
millimetre a deep trench capacitor gives, that is three hundred and forty square
millimetres of interposer under a five hundred and seventy-six square millimetre
die. **Decoupling is a floorplan constraint**, not a component to add at the end,
and the blueprint must present it that way.

### The other half of the answer

Do not make the step. `608`'s sequencer ramps engine activity over sixty-four
cycles rather than starting it all at once, which divides the peak slew by
sixty-four and costs forty-five nanoseconds at the start of a layer, against a
layer that takes a hundred and fifty microseconds. **Three parts in ten thousand of
the time, for a factor of sixty-four on the hardest electrical problem in the
machine.**

The blueprint should present the trade as a curve — ramp length against required
capacitance — and mark the chosen point, because somebody will later want to know
whether ramping harder would free interposer area.

### The impedance target

Droop divided by step current gives a target impedance the network must stay under
from direct current up to the clock. That is a curve, not a number, and it has
three regions: the regulator holds the low frequencies, the deep trench array holds
the middle, and on-die capacitance holds the top. **The dangerous part is where two
regions meet**, because an inductance and a capacitance in series resonate there,
and an antiresonant peak above the target is a rail that rings at exactly the
frequency the engine switches at.

## Symbols this must publish

Step current and slew rate at each domain. Response time per regulator stage.
Allowed droop from `402`. Required capacitance per die and per domain. Deep trench
areal density and the area it implies. Target impedance curve. Antiresonant peak
frequency and amplitude. Ramp length and the capacitance it saves.

## Constraints this must assert

- Network impedance stays under the target at every frequency, including at the
  antiresonant peaks. This is the constraint; everything else is inputs to it.
- Deep trench area required fits within the interposer area available under a die
  in `014`.
- Ramp length times the clock period stays under a stated fraction of a layer
  time, so the mitigation does not cost throughput.
- Total decoupling capacitance summed over all dies times the array voltage
  squared gives a stored energy under what `406`'s sequencing can safely discharge.

## Suggested implementation steps

1. Derive the step and slew from `401`.
2. Compute required capacitance without the ramp, so the raw number is visible.
3. Add the ramp and plot the trade.
4. Build the impedance curve in three regions and find the antiresonances.
5. Check the area against `014` and, if it does not fit, say which of the two
   moves rather than quietly shrinking the requirement.

## Blocks

`406`, `608`, `1005`.

## Blocked by

`401`, `402`, `403`.

## Related documents

`006` for the mechanism. `605` for what makes the step.
