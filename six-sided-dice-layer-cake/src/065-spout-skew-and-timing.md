# 065 — Getting sixteen million edges to agree

```meta
phase  | 9
issues | 904
```

## Where the skew is not

**The bond.** Ten microns is nothing; every conductor in the array is the same
length to within a fraction of a picosecond. A reader will assume the width is
the problem and it is not.

## Where it is

Distributing one launch edge across fifty millimetres of silicon on the sending
side, and gathering it across fifty on the receiving side. A signal crosses a die
at a fraction of the speed of light, so corner to centre is hundreds of
picoseconds — **a large part of a cycle spent on nothing**, before any mismatch in
the distribution network is counted.

A balanced tree reduces it, at a cost in power and area that scales with the
number of leaves. There are sixteen million leaves.

## The answer, and why it is the answer

**Stop trying to make one edge.**

```drawing
one strobe per tile [not-dimensioned]

   sending side                     receiving side
   ┌────┐ data ──────────────────▶ ┌────┐
   │tile│ strobe ────────────────▶ │ rx │ capture on its own strobe
   └────┘                          └────┘ then cross into local time
   ┌────┐ data ──────────────────▶ ┌────┐
   │tile│ strobe ────────────────▶ │ rx │ arrives whenever it arrives
   └────┘                          └────┘
     ⋮                               ⋮
   tiles may arrive across a window; the receiver reassembles
```

Skew now has to be controlled only **within** a tile, and tiles may arrive in any
order across a window because the receiver deskews each against its own strobe.
**One impossible timing closure becomes thousands of easy ones**, for a couple of
conductors per tile out of the millions available.

The tile size is derived here from the intra-tile budget, and `063` reads it —
`C-063-4` requires the two to agree.

## The interaction nobody expects

`064`'s stagger deliberately fires tiles at different times to reduce
simultaneous switching. **That consumes part of this budget**, so the two are
sized together and the window below carries the sum rather than each pretending
the other is free.

## Symbols

```symbols
v_prop_die    | 1 | given | 0.33     | how fast a signal crosses a die, as a fraction of the speed of light
t_skew_intra  | ps | given | 8.0      | skew budget within one tile
t_skew_mismatch | ps | given | 40.0   | distribution network mismatch between tiles, from process and supply variation
t_skew_window | ps | given | 500.0    | the arrival window the receiver must tolerate, stated as a contract the far end may rely on

t_cross_die   | s | derived | L_plate / (c_light * v_prop_die) | time for a signal to cross a face, which is the naive single-edge skew
f_cycle_naive | 1 | derived | t_cross_die * f_spout_burst | that as a fraction of a cycle at the burst rate, which is the number that kills the single-edge approach
L_tile_skew   | um | derived | t_skew_intra * c_light * v_prop_die | the largest tile whose corner-to-corner skew fits the intra-tile budget
t_window_used | ps | derived | t_skew_mismatch + t_stagger_all   | the window actually consumed: distribution mismatch plus 064's stagger
n_strobe_cost | 1 | derived | n_strobe / (n_pane_bit / b1)        | what the per-tile strobes cost, as a share of the conductors
d_buffer_tile | 1 | given | 4                                     | pane transfers of buffering the receiver holds per tile, to absorb the window
C_rx_buffer   | MB | derived | n_pane_bit * d_buffer_tile          | receiver buffering in total, which lands in 069a
```

## Constraints

```constraints
C-065-1 | f_cycle_naive > 0.25         | distributing one edge across a face costs at least a quarter of a cycle. Asserted in the direction that confirms the problem, because it is what justifies every conductor the tiling spends and a reader who does not believe it will try the simple thing
C-065-2 | L_tile_pad <= L_tile_skew    | the tile 063 builds must be no larger than the tile this budget permits
C-065-3 | t_window_used < t_skew_window | mismatch and stagger together must fit inside the window the receiver is told to expect. Stating the window as a contract is what lets 069a size its buffers without knowing how the sending side is built
C-065-4 | n_strobe_cost < 0.001        | the strobes must cost under a thousandth of the conductors, which is what makes thousands of easy closures cheaper than one hard one
C-065-5 | C_rx_buffer < C_pane_mb * 8  | receiver buffering must stay within a few panes, or the translation unit becomes a memory rather than a bridge
```

## What is still open

**The window is a contract with no enforcement.** Five hundred picoseconds is
stated as something the far end may rely on; nothing measures it, and a bonded
pair whose sending side drifts outside it fails in a way the hash in `069` sees
as corruption rather than as a timing fault.

**The receiving side's own distribution is not budgeted.** Everything here
concerns getting edges out of the cube. Gathering them across the far side is the
same problem again, and it belongs to `069a`, which does not have it.
