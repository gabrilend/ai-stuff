# 067 — The cabled grade

```meta
phase  | 9
issues | 906
```

## Why it exists

Because a machine you cannot take apart is a machine you cannot service, and
`019`'s whole position is that service means swapping a cube. A cube whose output
is bonded to something is a cube that cannot be swapped alone.

## What it is

Differential pairs on `056`'s **perimeter zone** at a detachable pitch, through
the via islands, to a connector, to twinax.

Two comparisons, and both belong in the blueprint because either alone is
misleading. Against the bonded grade it is two orders of magnitude narrower and
looks like a failure. Against a fast network interface it is more than an order
of magnitude wider and looks like a triumph. **It is neither.**

## Everything `064` omitted comes back

`064`'s driver is an inverter because its channel is ten microns of copper. This
channel is a metre of twinax, and it needs termination, equalisation at both
ends, clock recovery, a training sequence and per-lane calibration state.

**This is a different circuit, not a variant**, and saying so is what stops
somebody reusing the wrong one. The right move is to adopt an existing serial
standard rather than specify one: nothing about this link is unusual, and a
standard brings connectors, cables, retimers and test equipment that already
exist.

## The conflict this blueprint has to resolve

`069a` requires the **cube-side interface to be identical across every variant**,
which is the whole point of building one part six times.

A pane is two mebibytes arriving at once. Over a couple of thousand serial lanes
it arrives over hundreds of nanoseconds, in lane order. **That is not the same
thing arriving.**

The resolution: **what leaves the core stays the same and what leaves the cube
does not.** A fixed-function serialiser sits on the face, between the pane and
the pairs. The core, the cage and the pane window are identical in every variant;
the port field's population differs, which is exactly what `056` already says.
`069a` is updated to say *core-side* rather than *cube-side*.

## Symbols

```symbols
n_pair_spout  | 1 | given | 512      | differential pairs the cabled grade uses. Two thousand was the first figure and draws two hundred and sixty watts, which is three times even the transient port allowance -- a serial link costs picojoules a bit where a ten micron bond costs femtojoules, and that is the real reason this grade is narrow
r_pair_spout  | bit/s | given | 3.2e10 | rate one pair carries
n_mate_cycle  | 1 | given | 200      | mating cycles the connector is rated for
L_cable_spout | mm | given | 1000.0  | reach
e_ser_bit     | pJ/bit | measured | 4.0 | energy a bit costs over this link, both ends and the serialiser included

B_cabled      | bit/s | derived | n_pair_spout * r_pair_spout       | what the cabled grade carries
ratio_bonded  | 1 | derived | B_spout_burst / B_cabled              | how much narrower it is than the bonded grade
ratio_net_c   | 1 | derived | B_cabled / r_net_ref                  | and how much wider than a network interface
t_pane_ser    | s | derived | n_pane_bit / B_cabled                 | how long one pane takes to serialise, which is what makes it not the same thing arriving
t_core_out_c  | s | derived | C_core_usable / B_cabled        | whole-core transfer time on this grade
P_cabled      | W | derived | e_ser_bit * B_cabled                  | what it costs while running
n_pad_spout_c | 1 | derived | n_pair_spout * 2                      | perimeter positions it needs
```

## Constraints

```constraints
C-067-1 | n_pad_spout_c + n_port_conductor <= n_pad_perim | the pairs and the power must both fit the perimeter zone, since this grade shares it with the face's own supply
C-067-2 | ratio_bonded > 100          | this grade is two orders of magnitude narrower than the bonded one. Asserted so the comparison is in the record rather than left for somebody to be disappointed by
C-067-3 | ratio_net_c > 10            | and more than an order of magnitude wider than a network interface. Both comparisons, because either alone misleads
C-067-4 | P_cabled < P_port_burst     | it must fit inside the transient port allowance while it runs
C-067-5 | t_pane_ser > t_pane_empty * 100 | serialising a pane takes far longer than emitting one, which is the arithmetic behind saying the cube-side interface cannot be identical -- and therefore behind moving that requirement to the core side
C-067-6 | L_cable_spout < L_reach_line | the cable must be inside the reach of the standard adopted for it
```

## What is still open

**No serial standard is named**, exactly as in `057`. The rate, the reach and the
energy per bit are figures from a standard nobody has chosen.

**The serialiser is not designed.** It sits on the face between the pane and the
pairs, it is fixed function, and it is the piece that makes this grade possible.
It also has to buffer a whole pane, which is memory on a face that `041`'s
floorplan does not have.
