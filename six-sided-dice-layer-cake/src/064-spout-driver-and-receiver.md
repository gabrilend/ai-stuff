# 064 — One wire, and the circuit at each end

```meta
phase  | 9
issues | 903
```

## The constraint that shapes it

A ten micron pitch gives a hundred square microns per conductor, and the pad
takes a share of that. **The circuit gets a few tens of square microns** — which
rules out a current source, a bias network, an amplifier, or any per-lane
calibration state.

What is left is an inverter driving a pad and an inverter receiving it. That is
the correct answer and it sounds too simple until the area budget is stated
first, which is why it is.

## Why that works here and nowhere else

The bond is ten microns long. It carries about a femtofarad, has no meaningful
inductance, no reflection worth the name and no attenuation. **Every technique a
serial link needs — equalisation, clock recovery, termination, calibration —
exists to fight a channel this one does not have.**

The reach over which that holds is published, so nobody reuses this circuit for
`067`'s cabled grade, where the channel is a metre of twinax and all of it comes
back.

## The simultaneous switching problem

This is the hard part. Sixteen million drivers changing state together pull a
large current spike through the local supply, and the bounce is seen by every
receiver at once as a shift in its own reference.

**The worst case is not rare.** A pane of zeroes followed by a pane of ones is an
ordinary thing for memory to contain.

Three mitigations, and two are nearly free because the tiling already exists:

**Ground density.** `063`'s one in five, justified here rather than assumed.

**Stagger.** Fire tiles in a fixed sequence over a few hundred picoseconds rather
than all at once. `065` already tolerates tile-to-tile skew, so this costs
nothing that was not already spent.

**Data conditioning.** Invert a tile's data when that reduces transitions, and
send one bit saying so. One conductor in four thousand and ninety-six, and it
halves the worst case.

## Symbols

```symbols
a_driver      | um^2 | measured | 14.0 | area of one driver: an inverter sized for a femtofarad
a_receiver    | um^2 | measured | 16.0 | area of one receiver: an inverter and a small latch
c_bond        | fF | measured | 1.0    | capacitance one bonded conductor presents
f_circuit_over | 1 | measured | 13.89  | how much more a bit costs than moving the bond's own charge. The bond is a fourteenth of it; the rest is the two inverters switching, the local strobe distribution and the receiver's latch
L_bond        | um | given | 10.0      | length of the bond itself
L_reach_bond  | um | given | 50.0      | the furthest this circuit is valid over, beyond which a channel exists and 067 applies
v_bounce_max  | V | given | 0.060      | supply bounce the receiver still resolves a bit through
n_stagger     | 1 | given | 16         | groups the tiles are fired in, one after another
t_stagger     | ps | given | 20.0      | interval between two stagger groups
f_cond_gain   | 1 | given | 0.50       | share of the worst-case switching that data conditioning removes

a_conductor   | um^2 | derived | p_bond_fine^2                        | area one conductor has, pad and circuit together
a_circuit     | um^2 | derived | a_driver + a_receiver                | area the circuit needs
f_circuit_area| 1 | derived | a_circuit / a_conductor                 | how much of the pitch the circuit uses
E_bit_derived | pJ/bit | derived | c_bond * V_port^2 / 2 / b1 * f_circuit_over | energy to move one bit: the bond's own charge, times what the circuits at each end add
I_ssn_raw     | A | derived | n_pane_bit / b1 * c_bond * V_port * f_spout_burst | current if every conductor switched the same way on the same edge
I_ssn_mit     | A | derived | I_ssn_raw * f_cond_gain / n_stagger     | and after conditioning and stagger
v_bounce      | V | derived | I_ssn_mit * z_supply                    | the bounce that produces
z_supply      | ohm | given | 2.0e-6   | impedance the local supply presents to the array at the switching frequency
f_gnd_min     | 1 | derived | 0.15     | the least share of positions that must be ground and shielding for the bounce above to be what it is
t_stagger_all | ps | derived | n_stagger * t_stagger                  | how long the whole stagger sequence takes, which 065 has to absorb
```

## Constraints

```constraints
C-064-1 | a_circuit < a_conductor * 0.4 | the circuit must fit in well under half the pitch, since the pad and its keep-out take the rest. This is the constraint that eliminates every technique a serial link uses
C-064-2 | E_bit_derived ~= e_pane_bit   | the energy derived from the capacitance and the swing must be the figure 062 budgets. Two routes, one number
C-064-3 | v_bounce < v_bounce_max       | supply bounce at the worst-case switching pattern, after conditioning and stagger, must leave the receiver able to resolve a bit. A pane of zeroes followed by a pane of ones is not a rare pattern
C-064-4 | L_bond < L_reach_bond         | the bond must be inside the reach where equalisation and clock recovery can be omitted
C-064-5 | t_stagger_all < t_skew_window | the whole stagger sequence must fit inside the arrival window 065 already tolerates, so that this mitigation costs nothing that was not already spent
C-064-6 | I_ssn_mit < I_ssn_raw / 10    | the mitigations together must take an order of magnitude off the worst case
```

## What is still open

**The supply impedance is a `given` with nothing behind it.** Two microhms is
what a very good local grid presents, and the bounce is directly proportional to
it. `031` sized decoupling for the compute dies and nothing has done the same for
the spout face, which switches sixteen million drivers in one edge.

**Data conditioning needs a decision at the far end.** The inversion bit says
what was done; something has to undo it, and `069a`'s receiver is where — which
means the cube-side interface is not quite as protocol-free as `062` claims.
