# 904 — Getting sixteen million edges to agree

Produces `src/065-spout-skew-and-timing.md`.

## Current behavior

Nothing. `007` names the tiling as the answer and never derives the budget it is
answering.

## Intended behavior

**The timing of a pane transfer: where the skew comes from, why the obvious
approach fails, and the budget the tiling has to meet.**

### Where the skew is not

The bond. Ten microns is nothing; every conductor in the array is the same length
to within a fraction of a picosecond. **A reader will assume the width is the
problem and it is not.**

### Where it is

Distributing one launch edge across fifty-two millimetres of silicon on the
sending side, and gathering it across fifty-two millimetres on the receiving side.
A signal crosses a die at roughly a third of the speed of light, so corner to
centre is twenty-six millimetres and about two hundred and sixty picoseconds. At a
gigahertz that is a quarter of the cycle spent on nothing, before any mismatch in
the distribution network is counted.

A balanced tree can bring that down, at a cost in power and area that scales with
the number of leaves — and there are sixteen million leaves.

### The answer, and why it is the answer

Stop trying to make one edge. **Divide the pane into four thousand and ninety-six
tiles and let each forward its own strobe alongside its own data.**

Skew now has to be controlled only within a tile — six hundred and forty microns,
about six picoseconds — and the tiles may arrive in any order across a window of
half a nanosecond, because the receiver deskews each against its own strobe. One
impossible timing closure becomes four thousand and ninety-six easy ones, for four
thousand and ninety-six extra conductor pairs out of twenty-one million available.

The blueprint must derive the tile size **from** the intra-tile budget rather than
taking `902`'s number as given, and the two must then agree.

### What the receiver has to do

Per tile: capture on the incoming strobe, cross into its own clock domain, and
present the whole pane aligned. That crossing needs a buffer sized by the arrival
window, and four thousand and ninety-six of them. `909`'s translation unit is where
they live, and this blueprint owns their requirement.

The blueprint must also state the **arrival window** as a specification the
receiver may rely on, because a window that is stated too tight makes receivers
that fail and one stated too loose makes buffers that are needlessly large.

### The interaction nobody expects

`903`'s stagger mitigation deliberately fires tiles at different times to reduce
simultaneous switching. That consumes part of this budget. The two must be sized
together, and this blueprint should carry the sum rather than each pretending the
other is free.

## Symbols this must publish

On-die propagation velocity. Corner-to-centre delay. Intra-tile skew budget. Tile
size derived from it. Inter-tile arrival window. Strobe conductor count. Receiver
buffer depth per tile. Stagger allocation from `903`. Total window and its
breakdown.

## Constraints this must assert

- Intra-tile skew at the derived tile size is under the budget.
- Tile size derived here equals `902`'s. Two routes, one number.
- Stagger allocation plus distribution mismatch plus process variation is under
  the stated arrival window.
- Receiver buffer depth covers the arrival window at the line rate.
- Strobe count equals tile count, and both fit `902`'s array.

## Suggested implementation steps

1. Derive the naive single-edge skew and show it fails. It is one calculation and
   it justifies everything after.
2. Derive tile size from the intra-tile budget.
3. Add `903`'s stagger into the same budget.
4. State the arrival window as a contract and size the receiver buffers from it.

## Blocks

`902`, `905`, `907`, `909`.

## Blocked by

`901`, `902`, `903`.

## Related documents

`007`. `072` is the same problem for the clock, inside the cube.
