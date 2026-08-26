# 062 — The idea, and what it costs

```meta
phase  | 9
issues | 901
```

## The claim, reduced to arithmetic

One wire per bit of memory. The core holds tens of gibibytes, which is hundreds
of thousands of millions of bits. At the finest bond pitch anyone can make, a
face holds a few tens of millions of positions. **The ask exceeds the possible by
about four orders of magnitude.**

So the quantity to specify is not *all of memory* but **the largest window a face
can physically carry**: the **pane**, a power-of-two number of bits with one
conductor each, all switching on one edge, and a register that says which part of
the core it is currently looking at.

## The energy accounting, which is the real content

A pane costs a few hundred nanojoules — millions of bits across a ten micron bond
at femtojoules each. Pushing the entire core through it is tens of thousands of
panes and a few millijoules, in tens of microseconds.

That is over a hundred watts while it runs, arriving and leaving far faster than
the silicon can warm up. **So the spout has an energy budget rather than a power
budget** — which is unusual for a chip interface, is what `026` confirmed
thermally, and is the same treatment `057`'s model load needed for the same
reason.

## The limit that is not the wires

The core reads at some tens of terabytes a second. A pane is a couple of
mebibytes, so **filling one takes far longer than emptying it**. The tube can
leave faster than the memory can be read, and sustained output is bounded by
`034` rather than by anything in phase 9.

This is stated before any wire count, because a reader who counts conductors will
size the spout wrong in exactly the way a reader who counts pads sizes the radial
link wrong in `051`.

## What sixteen million wires actually buy

Since `069a`, the far side is a translation unit between one and three orders of
magnitude slower than the pane. So the spout is **not a throughput device. It is
a zero-cost one**: the cube spends a single edge handing over any two mebibytes
it holds, and is free while the far side takes as long as it likes.

```drawing
what one edge does [not-dimensioned]

   the core          the pane window          the far side
   ┌────────┐        ┌──────────┐             ┌──────────┐
   │        │  fill  │          │  one edge   │          │
   │  any   │───────▶│ [C_pane] │────────────▶│  buffer  │───▶ slowly
   │ window │  ~µs   │          │  ~ns        │          │
   └────────┘        └──────────┘             └──────────┘
        ▲                                            │
        └──── the cube is free again from here ──────┘
```

## Symbols

```symbols
p_bond_fine   | um | given | 10.0   | the finest pitch a permanent copper-to-copper bond reaches
f_pane_overhead | 1 | given | 0.20  | share of the fine zone's positions spent on power, ground, shielding and strobes
e_pane_bit    | pJ/bit | measured | 0.010 | energy to move one bit across a ten micron bond, driver and receiver together
f_spout_burst | GHz | given | 1.0    | rate a pane transfer runs at during a burst
f_spout_sust  | MHz | given | 50.0   | rate it may run at continuously without exceeding the steady port allocation. A hundred megahertz was the first figure and costs seventeen watts against a ten watt steady budget -- which is the difference between a burst the silicon absorbs and a load the coolant sees

n_fine_col    | 1 | derived | floor(sqrt(A_fine) / p_bond_fine) | pad columns across the fine zone
n_fine_pad    | 1 | derived | n_fine_col^2                             | positions in it
n_pane_avail  | 1 | derived | n_fine_pad * (1 - f_pane_overhead)       | conductors available for data
n_pane_bit    | bit | derived | b1 * 2^floor(log(n_pane_avail) / log(2)) | the pane, rounded down to a power of two so that its window aligns naturally in 038. It carries the unit because it is a quantity of bits rather than a count of things, and everything downstream of it is a size or a rate
C_pane_mb     | MB | derived | n_pane_bit                              | the pane, in the unit a person reads it in
E_pane        | J | derived | e_pane_bit * n_pane_bit                  | energy of one pane transfer
n_pane_core   | 1 | derived | C_core_usable / n_pane_bit               | panes needed to move the whole core
t_core_out    | s | derived | n_pane_core / f_spout_burst              | time to do it at the burst rate
P_spout_burst | W | derived | E_pane * f_spout_burst                   | power while a burst runs
B_spout_burst | bit/s | derived | n_pane_bit * f_spout_burst           | the burst rate as a bandwidth
B_spout_sust  | bit/s | derived | n_pane_bit * f_spout_sust            | and the sustained one
t_pane_fill   | s | derived | n_pane_bit / B_core                      | how long the core takes to fill a pane
t_pane_empty  | s | derived | 1 / f_spout_burst                        | how long the spout takes to empty it
ratio_fill    | 1 | derived | t_pane_fill / t_pane_empty               | how much slower the memory is than the tube, which is the limit that is not the wires
ratio_net     | 1 | derived | t_core_net / t_core_out                  | how much faster this is than sending the same bytes over a network interface
t_core_net    | s | derived | C_core_usable / r_net_ref                | time to move the whole core over a fast network interface, for the comparison
r_net_ref     | bit/s | measured | 4.0e11 | a fast network interface, as the comparison everybody will make
```

## Constraints

```constraints
C-062-1 | n_pane_bit / b1 <= n_pane_avail | the pane must fit in the conductors the fine zone actually has after power, ground and strobes are taken out
C-062-2 | ratio_fill > 10              | the memory must be an order of magnitude slower to fill a pane than the tube is to empty it. This is the limit that is not the wires, asserted so that a reader who counts conductors meets it as a number
C-062-3 | P_spout_burst * t_core_out < E_burst_max | pushing the whole core out must deposit less energy than 026's thermal masses absorb, which is what makes this an energy budget rather than a power one
C-062-4 | B_spout_sust * e_pane_bit < P_ports | the sustained rate must fit inside the steady port allocation, since sustained means the coolant does see it
C-062-5 | ratio_net > 1000             | moving the whole core this way must be three orders of magnitude faster than a network interface, which is the only comparison that makes sixteen million wires worth their manufacturing risk
C-062-6 | C_pane_mb ~= n_pane_bit      | the pane expressed in megabytes and in bits must be the same quantity. Trivially true now that both carry the unit, and it was not before: the first version divided by eight million by hand and produced a dimensionless number that no other blueprint could use
```

## What is still open

**The pane is a power of two by choice, not by necessity.** Rounding down throws
away up to half the available conductors — at the current fine zone it costs
about a tenth — and it buys an aligned window in `038` and a tiling in `063` that
divides evenly. Whether that is worth the conductors has not been argued.

**The burst rate is a `given`.** One gigahertz across sixteen million
simultaneously switching drivers is optimistic and `064` is where it either holds
or does not.
