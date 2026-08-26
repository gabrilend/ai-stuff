# 028 — The power budget

```meta
phase  | 4
issues | 401
```

Current at every node of the delivery tree. `020` counts the same energy as heat;
this counts it as current, and the two must reconcile.

```drawing
the delivery tree [not-dimensioned]

   [V_supply] in, one connection per face
        │
        ├─ face 0 .. face 5
        │     │
        │     ├─ first stage, [V_supply] to [V_mid]
        │     │     │
        │     │     ├─ [V_logic]  engines, scalar, crossbar
        │     │     ├─ [V_array]  the slice, and a sixth of the core
        │     │     ├─ [V_link]   the radial driver
        │     │     └─ inward, to the cage
        │     │
        │     └─ [V_port] and [V_aux], directly from the first stage
        │
        └─ the core, fed by all six faces at once
```

**The core is fed by all six faces**, one sixth each. That is not an arrangement
anybody designed for redundancy and it delivers redundancy anyway: a face that
loses its regulator stops computing and the middle keeps running on the other
five. Worth naming as a property rather than leaving as an artefact.

## Everything here is derived

Not one ampere in this blueprint is a `given`. Every current is a power from
`020` divided by a voltage from `029`. That is what keeps the two budgets locked
together: change the multiplier's switching energy and both the heat and the
current move, in step, with nobody editing either.

## Symbols

```symbols
P_logic_load  | W | derived | n_die * (P_engine_die + P_scalar_die + P_leak_die) + P_crossbar | everything on the logic rail: engines, control, leakage and the switch fabric
P_array_load  | W | derived | n_die * P_slice_die + P_core                | everything on the array rail: the face slices and the whole memory block
P_link_load   | W | derived | P_link                                      | the six radial link drivers
P_port_load   | W | derived | P_ports                                     | port fields, storage lines and the spout, averaged
P_aux_load    | W | given   | 1.0                                         | sensors, telemetry and the interlock, which must run when nothing else does
I_alarm       | A | given   | 1000.0                                      | a current large enough that reaching it would mean the delivery scheme had been abandoned; it exists to give C-028-5 something named to compare against

I_logic       | A | derived | P_logic_load / V_logic     | current on the logic rail across the whole machine
I_array       | A | derived | P_array_load / V_array     | on the array rail
I_link        | A | derived | P_link_load / V_link       | on the link rail
I_port        | A | derived | P_port_load / V_port       | on the port rail
I_aux         | A | derived | P_aux_load / V_aux         | on the auxiliary rail
I_die_logic   | A | derived | (P_engine_die + P_scalar_die + P_leak_die) / V_logic | logic current into one compute die, which is the number the power grid in 030 is sized by
I_supply      | A | derived | P_input / V_supply         | current drawn from the external supply
I_face_supply | A | derived | I_supply / n_face          | and per face, which is what a port field connector has to carry
I_core_inward | A | derived | P_core / V_array           | current the memory block draws, arriving radially
I_core_face   | A | derived | I_core_inward / n_face     | one face's share of it, sent inward through the same interface the data uses

I_would_be    | A | derived | P_input / V_logic          | what the supply current would be if power arrived at the voltage the transistors run at. Two and a half kiloamps: not a connector, a pair of busbars nobody could bolt to this object, and the reason the whole two-stage conversion exists
conv_ratio    | 1 | derived | V_supply / V_logic         | how far the voltage has to fall between the outside world and a gate
```

## Constraints

```constraints
C-028-1 | P_input ~= P_heat                                          | the power drawn and the heat removed are the same energy counted twice, and the two budgets must reconcile. This is the check no single document can do against itself, and what it usually catches is a mechanism counted in both
C-028-2 | P_logic_load + P_array_load + P_link_load + P_port_load + P_aux_load ~= P_load | the five rails account for everything delivered to the point of load, with nothing on a rail that does not exist
C-028-3 | I_core_face * n_face ~= I_core_inward                       | the six faces' inward contributions add up to what the core draws
C-028-4 | I_face_supply < I_port_max                                  | the current one face brings in must be inside what a port field connector will carry
C-028-5 | I_would_be > I_alarm                                        | asserted in the direction of alarm and never expected to fail: at the transistor's own voltage this machine would draw over a kiloampere, which is what makes the two-stage conversion structural rather than an efficiency measure
C-028-6 | I_die_logic < I_die_max                                     | logic current into one die must be inside what its power grid and microbump array can carry, from 032
```

## What is still open

**Peak current is not distinguished from average.** Every figure here is a design
point average. `031` needs the *step* — how much of `I_die_logic` appears in one
clock cycle — and takes it from `045` rather than from this budget, which means
the two could drift apart. The step belongs here and is not here.

**Nothing accounts for the spout's burst current.** A hundred and sixty-eight
watts for thirty-three microseconds on the port rail is over a hundred amperes at
one and a fifth volts, which is fourteen times the port rail's average. `026`
established it is thermally nothing; nobody has checked it is electrically
nothing.
