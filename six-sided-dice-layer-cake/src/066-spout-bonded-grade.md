# 066 — The bonded grade

```meta
phase  | 9
issues | 905
```

## It is a bond, not a connector

The face and whatever receives it are pressed together at temperature and become
one object. No socket, no compliance, no mating cycle, and no way back. **Every
consequence below follows from that sentence**, so it is first.

## What it buys

The pane on one edge. The whole core in tens of microseconds. Three orders of
magnitude against a network interface, and two against the cabled grade in `067`.

## What it costs

**Serviceability, completely.** `019` says a cube has no field-replaceable parts
and service means replacing the whole cube. A bonded spout means service replaces
*two* whole objects, because they are one object.

**Yield, multiplicatively.** Sixteen million bonds, all of which must work, made
in one operation at the very end of assembly when both objects are already at
their most valuable. `083` carries it as its own term and `063`'s spares are what
make it survivable.

**Alignment.** Ten micron pads want sub-micron placement across fifty
millimetres, on two surfaces flat to a fraction of that, at temperature. **This is
the hardest mechanical tolerance in the project** and `C-066-3` compares it
explicitly against `013`'s stack, which is two orders of magnitude looser.

## When it is right, and how it probably ships

It is right when the two objects were always going to live and die together.

**The useful case is a cube bonded to its own translation die** — small, cheap,
never separately serviced — with the detachable interface on the far side of
*that*. The cube's spout is permanent; the machine's output is not. That resolves
most of the serviceability objection and is how this grade is expected to ship.

## Symbols

```symbols
T_bond        | K | given | 483.0    | temperature the copper-to-copper bond is made at. Five hundred and twenty-three was the first figure and is hotter than the bond that put the faces on, which would reflow it -- surface activation before bonding is what brings this down, and it is a process requirement rather than a preference
F_bond        | kg | given | 2000.0  | force applied across the array during bonding
t_bond_dwell  | s | given | 1800.0   | how long it is held
tol_align_xy  | um | given | 0.5      | in-plane placement tolerance the pitch demands
tol_flat_bond | um | given | 0.2      | flatness both surfaces must hold across the array
n_rework      | 1 | given | 0         | rework attempts available. There are none: this is the last operation and both objects are finished

y_array_raw   | 1 | derived | y_bond_hybrid^n_bond_total           | probability every bond in the array is good with no spares at all
n_bad_expect  | 1 | derived | n_bond_total * (1 - y_bond_hybrid)   | bonds expected to fail in one array
y_array_spare | 1 | derived | 1 - n_bad_expect / n_spare_pane      | roughly, the chance the spares cover the failures -- a crude bound rather than a distribution, and marked as such
p_area_bond   | MPa | derived | F_bond * g_accel / A_fine | pressure the bonding force puts on the array
ratio_align   | 1 | derived | flat_plate / tol_flat_bond    | how much looser 013's face flatness is than this bond needs, which is the number that says where the difficulty is
t_core_out_b  | s | derived | t_core_out                            | whole-core transfer time for this grade, which is 062's burst figure unmodified
```

## Constraints

```constraints
C-066-1 | y_array_raw < 0.5            | with no spares, an array this size fails more often than it works. Asserted in the alarming direction on purpose: it is the entire justification for 063's spare conductors, and a reader who has not multiplied it out will not believe the spares are needed
C-066-2 | y_array_spare > 0.95         | with them, it must succeed nearly always
C-066-3 | ratio_align > 100            | this bond needs a flatness two orders of magnitude tighter than the face flatness 013 specifies. Asserted so the difficulty is located: it is not the number of wires, it is that two fifty millimetre surfaces must be flat to a fifth of a micron while being pressed together hot
C-066-4 | T_bond < T_bond_max_prior    | the bond temperature must be below the lowest temperature anything already inside the cube can survive, since this is the last operation and everything else is already assembled
C-066-5 | p_area_bond < p_area_max     | the bonding pressure must not exceed what the assembled stack beneath it will take
C-066-6 | n_rework == 0                | there is no rework. Asserted as a value so that an assembly plan assuming a second attempt fails outright
```

## Symbols this owns and needs

```symbols
T_bond_max_prior | K | given | 543.0 | the lowest temperature any earlier bond, solder or seal in 082's sequence survives
p_area_max       | MPa | given | 15.0 | pressure the assembled stack will take across its face without damage
```

## What is still open

**The spare coverage bound is crude.** `y_array_spare` is one minus expected
failures over spares, which is not a probability and is marked as such. The real
question — the chance that failures cluster inside one tile's remap group faster
than spares can cover — needs a distribution and `083` should supply it.

**Nothing says how a failed bond is found.** The remap needs to know which
conductors are bad, and the only opportunity is after the bond, when the object
cannot be taken apart. `084`'s test access does not cover the spout.
