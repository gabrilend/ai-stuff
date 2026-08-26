# 901 — The idea, and what it costs

Produces `src/062-spout-concept.md`.

## Current behavior

Nothing. `007` tells the story; no blueprint states the idea in symbols.

## Intended behavior

**The output tube's central claim, sized against what a face can physically carry,
with the energy accounting that turns it from a wish into a burst device.**

### The claim, reduced to arithmetic

One wire per bit of memory is five hundred and fifty billion wires. A fifty-two
millimetre square face at the finest bond pitch anyone can make holds twenty-seven
million positions. The ask exceeds the possible by about twenty thousand.

So the quantity to specify is not *all of memory* but **the largest window a face
can carry**: two mebibytes, sixteen million seven hundred and seventy-seven
thousand two hundred and sixteen conductors, one per bit, all switching on one
edge. The **pane**.

### The energy accounting, which is the real content

A pane costs about a hundred and sixty-eight nanojoules — sixteen million bits at
roughly ten femtojoules each across a ten micron bond. Pushing the whole core
through it is thirty-two thousand seven hundred and sixty-eight panes and five and
a half millijoules, in thirty-three microseconds at a gigahertz.

That is a hundred and sixty-eight watts while it runs, which is nine per cent of
the machine's total, arriving and leaving in a time far shorter than the silicon's
millisecond thermal constant. **So the spout has an energy budget rather than a
power budget**, which is an unusual thing for a chip interface and is the property
the blueprint must establish, because everything in `026` and `907` depends on it.

Sustained rather than burst, the spout runs at about a hundred megahertz for
seventeen watts, which is still two hundred and ten terabytes a second.

### The limit that is not the wires

The core reads at thirty-nine terabytes a second. A pane is two mebibytes, so
filling one takes fifty-four nanoseconds and emptying it takes one. **The tube can
leave faster than the memory can be read**, by a factor of about fifty, and
sustained output is bounded by `501` rather than by any of phase 9.

This should be stated before any wire count, because a reader who counts
conductors will size the spout wrong in the same way a reader who counts pads
sizes the radial link wrong in `702`.

### The reframing that justifies it

Since `909` and `910`, the spout's purpose is clearer than "fast output". A
translation unit on the far side is between one and three orders of magnitude
slower than the pane, so the spout is not a throughput device. **It is a zero-cost
one**: the cube spends a single edge handing over any two mebibytes it holds, and
is then free while the far side takes as long as it likes. That is what sixteen
million wires actually buy, and the blueprint should say so in those words.

## Symbols this must publish

Pane size in bits and bytes. Conductor count. Energy per bit, per pane, and for a
whole-core copy. Burst power and duration. Sustained rate and its power. Core fill
time per pane. Ratio of empty rate to fill rate. Comparison against a network link.

## Constraints this must assert

- Conductor count equals pane size in bits, exactly. The definition, asserted.
- Pane size is a power of two and matches `505`'s window alignment.
- Whole-core burst energy divided by the face's thermal capacitance from `026`
  gives a rise under the stated allowance.
- Sustained power is within `301`'s spout allocation.
- Fill time exceeds empty time, which is the statement that the core bounds the
  spout, as a constraint that would notice if either changed.

## Suggested implementation steps

1. Do the twenty-thousand-fold arithmetic first and let it kill the literal
   reading.
2. Size the pane from `902`'s pad count and round to a power of two.
3. Build the energy accounting and establish the burst framing.
4. State the fill-versus-empty limit before the wire count.
5. Write the zero-cost reframing, citing `909`.

## Blocks

`902`, `903`, `905`, `906`, `907`, `908`, `909`, `910`, `307`.

## Blocked by

`501`, `505`, `801`.

## Related documents

`007`. `008` entry 2 for the substitution this makes and what survives it.
