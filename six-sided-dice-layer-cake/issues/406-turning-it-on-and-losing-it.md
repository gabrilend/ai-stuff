# 406 — Turning it on, and losing it

Produces `src/033-power-sequencing.md`.

## Current behavior

Nothing. `009` entry P2 asks what happens on a brownout and there is no answer.

## Intended behavior

**The order the five domains come up in, the order they go down in, and what
happens when they go down without being asked.**

### Why order matters at all

Two failure mechanisms make sequencing a requirement rather than a nicety.

**Latch-up.** A signal driven into an input whose supply is not yet up forward-biases
a parasitic junction and creates a low-resistance path that persists until power is
removed. It destroys parts. The rule that prevents it — a domain's inputs may not
be driven before its own supply is valid — orders the whole tree.

**Inrush.** Every decoupling capacitor in `404` has to be charged. Thirty-four
microfarads per die, twenty-four dies, plus the core's, is over a millifarad at
three quarters of a volt. Bringing that up in a microsecond wants kiloamperes, so
the ramp rate is limited, and the limit sets the power-up time.

### The order

Auxiliary first, because the interlock in `308` has to be watching before anything
else exists. Then port, because the outside world must be able to talk before the
inside works. Then array, then logic, then link — array before logic so that memory
is stable before anything reads it, and link last because it has the smallest swing
and the least noise margin.

Down is the reverse, with one exception the blueprint must justify: auxiliary goes
down last, and on an uncommanded loss it must stay up on stored energy long enough
to record why.

### The uncommanded case, which is the real content

**Brownout.** The forty-eight volt input sags mid-token. The blueprint must specify
a threshold, a detection time, and an action, and it must answer the question `009`
entry P2 actually asks: what state is the machine in afterward.

The three possibilities, and the design should choose the second:

- The core loses its contents. Sixty-four gibibytes of resident model gone, thirty
  milliseconds to reload from the storage lines. Survivable, and detectable.
- The core keeps its contents. Static memory holds as long as its rail does, so if
  the array domain is held up on stored energy while logic collapses, the model
  survives and only the in-flight token is lost. **This costs a bulk capacitor and
  is worth it**, because thirty milliseconds of reload against a few millijoules of
  storage is a good trade and because a machine that does not lose its model on a
  flicker is a different machine to operate.
- The core keeps *half* its contents. Unacceptable and currently what would happen,
  because nothing distinguishes a completed write from an interrupted one. This is
  the case the design must make impossible, and the mechanism is that the array
  domain's collapse must be slower than the longest in-flight write, so writes
  finish rather than tear.

**Coolant loss** is not a power fault and is handled by `308`'s interlock, but the
sequencer has to accept its cut and get there without latch-up, which means the
emergency down-sequence must be fast and ordered at the same time.

## Symbols this must publish

Domain order up and down. Ramp rate limits and inrush current per domain. Power-up
and power-down times. Brownout threshold and detection time. Hold-up energy
required to preserve the array domain, and the capacitance that provides it.
Longest in-flight write from `506`. Emergency down-sequence time.

## Constraints this must assert

- No domain's inputs can be driven before its supply is valid, checked across the
  whole ordering.
- Inrush at every step stays under the input supply's capability.
- Array hold-up time exceeds the longest in-flight write, so nothing tears.
- Emergency down-sequence completes faster than `307`'s fatal thermal excursion.
- Auxiliary hold-up exceeds the time needed to write the fault record.

## Suggested implementation steps

1. Fix the order and write the latch-up rule that produces it.
2. Sum the decoupling from `404` and derive inrush and ramp limits.
3. Choose the second brownout behaviour and size the hold-up capacitor.
4. Get the longest in-flight write from `506` and assert against it.
5. Specify the fault record: what is written, where, and by what, when power is
   already failing.

## Blocks

`1204`, `1205`.

## Blocked by

`402`, `404`, `506`, `307`, `308`.

## Related documents

`006`. `009` entry P2, which this closes if it is done properly.
