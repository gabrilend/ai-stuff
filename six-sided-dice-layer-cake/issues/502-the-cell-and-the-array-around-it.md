# 502 — The cell, and the array around it

Produces `src/035-core-bitcell-and-macro.md`.

## Current behavior

Nothing. One and a half megabytes per square millimetre is used in the capacity
chain and has no basis written down.

## Intended behavior

**The static memory cell, the array built from it, and the three numbers everything
else needs: areal density, access time, and energy per bit.**

### Why static and not dynamic

A dynamic cell is a fraction of the area and would give perhaps six times the
capacity in the same volume. It is not used, and the blueprint must say why in one
paragraph because it is the first question anybody asks:

- **Refresh.** Sixty-four gibibytes of dynamic memory spends a measurable fraction
  of its bandwidth refreshing, and bandwidth is the machine's scarce resource.
- **Access energy.** A dynamic read destroys the row and writes it back. At
  thirty-nine terabytes a second that write-back is a large fraction of the core's
  power budget.
- **Latency and determinism.** The sieve's schedule in `704` depends on transfer
  times being predictable. A row-buffer miss is not.

The trade is capacity for bandwidth, and this machine exists to have bandwidth.

### Areal density, honestly

One and a half megabytes per square millimetre is aggressive and defensible only
under a specific arrangement: a **dedicated array tier** carrying bit cells and
local decode and nothing else, with the sense amplifiers, redundancy logic, error
correction and the interface on a separate logic lamina beneath. A conventional
cache achieves a third of this because it carries all of that on the same die.

The blueprint must present the density as a derivation — cell area from the node,
divided by array efficiency, with the periphery split out — rather than as a
figure, and it must say what array efficiency was assumed. **This is the number
most likely to be optimistic in the entire project** and it should be labelled as
such.

### The three outputs

**Areal density** feeds `501`'s capacity chain.

**Access time** feeds `501`'s clock and `704`'s schedule. It is not one number:
there is a latency to first data and a rate for the rest of a burst, and the sieve
cares almost entirely about the second because its transfers are enormous.

**Energy per bit** feeds `301`'s power budget and, through it, `005`. Read energy,
write energy, and retention leakage per bit at the operating temperature from
`306`, separately.

### Read stability

`402` needs the margin by which the array voltage must exceed the logic voltage.
That comes from here: the static noise margin of the cell at the low end of its
voltage tolerance, at the high end of its temperature range, at the worst process
corner. All three at once, because that is when it fails.

## Symbols this must publish

Cell area at the chosen node. Array efficiency. Areal density. Macro dimensions
and bits per macro. First-word latency and burst rate. Read, write and retention
energy per bit at temperature. Static noise margin and the array-over-logic
voltage requirement.

## Constraints this must assert

- Areal density times tier footprint equals capacity per tier in `501`.
- Burst rate times macro count per tier equals the bits per cycle in `501`.
- Read energy times aggregate bandwidth plus retention times bit count equals the
  core power in `301`.
- Static noise margin at the worst corner exceeds zero with the margin `402`
  requires.

## Suggested implementation steps

1. Derive cell area from the node in `1201` rather than quoting a density.
2. Split the periphery onto the logic lamina and state the array efficiency that
   assumes.
3. Produce the three numbers and label the density as the project's most
   optimistic assumption.
4. Do the noise margin at all three worst corners simultaneously.

## Blocks

`501`, `503`, `507`, `402`.

## Blocked by

`1201` for the node, `306` for the temperature.

## Related documents

`004`. `009` has no entry for the density assumption yet and should.
