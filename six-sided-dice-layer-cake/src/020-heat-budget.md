# 020 — The heat budget

```meta
phase  | 3
issues | 301
```

Every watt in the machine, attributed to a **mechanism** rather than to a
component, so the budget moves when the design does instead of being re-entered
by hand.

The distinction matters. *The compute dies dissipate thirteen hundred watts* is a
number somebody typed. *Each die dissipates the switching energy of its
multiplier array at its clock and its utilisation, plus its leakage at its
temperature, plus its slice's read energy at its access rate* is a number that
changes correctly when the clock, the batch size or the die area changes.

## The mechanisms

```drawing
where the energy goes [not-dimensioned]

   twenty-four compute dies ────┬─── multiplier switching      the bulk
                                ├─── scalar and sequencer
                                ├─── slice reads
                                └─── leakage, at temperature

   thirty-two memory tiers ─────┬─── array read energy
                                └─── retention leakage

   the cage ────────────────────┬─── six link drivers
                                └─── the crossbar

   six port fields ─────────────────  mostly idle; the spout is a burst

   six interposers ─────────────────  power conversion, and it is not small
```

## The loop that has to be closed by hand

**Leakage depends on temperature and temperature depends on leakage.** Silicon
leakage roughly doubles every ten kelvin, so a budget computed at room
temperature and run at sixty degrees is out by a factor of sixteen on that term.

The notation cannot iterate. So the junction temperature is entered here as a
`given` — the answer of an iteration done outside — `025` derives the temperature
that the resulting power actually produces, and a constraint requires the two to
agree within a per cent. **The fixed point is expressed as a constraint rather
than as a loop**, which is the only honest way to put a circular calculation into
a set of one-way derivations, and it means that if somebody changes the cooling
the mismatch is reported rather than hidden.

## The three operating points

One number is not enough, because three different states stress different parts.

**Idle.** Model resident, nothing generating. Leakage and clocks. Not small:
sixty-four gibibytes of static memory leaks whether or not anyone is asking it
anything, and this figure is what the machine costs to have switched on.

**Single stream.** One face working, five idle, memory saturated. Lowest
arithmetic power, full memory power.

**At the crossover.** All six faces working, memory saturated. The design point,
and the largest number.

## Symbols

```symbols
# --- what a die spends ------------------------------------------------------
E_op          | pJ/flop  | measured | 0.250 | switching energy per operation in a multiplier cell at this node and voltage
P_scalar_die  | W        | given    | 3.00  | scalar core, sequencer, clock tree and control on one die, which barely varies with what it is doing
E_slice_bit   | pJ/bit   | measured | 0.150 | energy to read one bit out of a face slice, array and local routing together
leak_ref      | W/mm^2   | measured | 0.003 | logic leakage per unit die area at 300 K and the nominal supply
dT_leak_dbl   | K        | measured | 10.0  | temperature rise that doubles leakage
T_ref_leak    | K        | given    | 300.0 | temperature the leakage figure above is quoted at
T_j_assumed   | K        | given    | 314.0 | junction temperature the leakage term is evaluated at; the answer of a fixed-point iteration that C-020-1 checks against what 025 derives

# --- what the memory spends -------------------------------------------------
E_core_bit    | pJ/bit   | measured | 0.480 | energy to read one bit out of a core tier, array and tier routing together
P_core_leak   | W        | given    | 40.0  | retention leakage of all thirty-two tiers at the operating temperature

# --- what the switch spends -------------------------------------------------
E_link_bit    | pJ/bit   | measured | 0.100 | energy to move one bit across a radial link, driver and receiver together
P_crossbar    | W        | given    | 39.0  | the cage's switch fabric at full traffic
P_ports       | W        | given    | 10.0  | six port fields, storage lines and the spout, averaged; the spout's burst is an energy and lives in 026

# --- conversion, which is inside the cube and therefore inside the budget ----
eta_conv_1    | 1        | measured | 0.960 | efficiency of the first stage, forty-eight volts to five
eta_conv_2    | 1        | measured | 0.900 | efficiency of the second, five volts to the point of load
eta_dist      | 1        | measured | 0.985 | resistive efficiency of the planes and grids between them

# --- derived: one die -------------------------------------------------------
ops_die       | flop/s | derived | 2 * n_mac * f_face                                   | operations a die can issue a second, two per multiplier cell per cycle
P_engine_die  | W      | derived | E_op * ops_die * util_design                          | switching power of one die's multiplier array at the design utilisation
B_slice_die   | bit/s  | derived | (n_mac / batch_design + n_mac_row) * f_face * 8       | bits a second a die reads out of its own slice to keep the array fed
P_slice_die   | W      | derived | E_slice_bit * B_slice_die                             | what those reads cost
leak_factor   | 1      | derived | 2^((T_j_assumed - T_ref_leak) / dT_leak_dbl)          | how much worse leakage is at the operating temperature than at the quoted one
P_leak_die    | W      | derived | leak_ref * A_die * leak_factor                        | leakage of one die at that temperature
P_die         | W      | derived | P_engine_die + P_scalar_die + P_slice_die + P_leak_die | everything one compute die dissipates at the design point

# --- derived: the machine ---------------------------------------------------
P_dies        | W | derived | n_die * P_die                                     | all twenty-four compute dies
P_core_read   | W | derived | E_core_bit * B_core                               | the core's array read energy at its full bandwidth
P_core        | W | derived | P_core_read + P_core_leak                         | the whole memory block
P_link        | W | derived | E_link_bit * B_core                               | six radial links carrying everything the core delivers
P_cage        | W | derived | P_link + P_crossbar                               | the switch shell
P_load        | W | derived | P_dies + P_core + P_cage + P_ports                | power delivered to the point of load
eta_conv      | 1 | derived | eta_conv_1 * eta_conv_2 * eta_dist                | end-to-end conversion and distribution efficiency
P_input       | W | derived | P_load / eta_conv                                 | power drawn from the forty-eight volt supply
P_conv_loss   | W | derived | P_input - P_load                                  | what turning voltage into other voltage costs, deposited on the face interposers
P_heat        | W | derived | P_input                                           | total heat to remove. It is the input power, because everything drawn from a supply leaves as heat, and naming it separately is what lets the plumbing be checked against the electrics
P_density     | W/m^3 | derived | P_heat / V_cube                              | heat per unit volume of the finished object
P_idle        | W | derived | n_die * (P_scalar_die + P_leak_die) + P_core_leak + P_ports | what the machine costs to have switched on with a model resident and nothing being asked of it
```

## Constraints

```constraints
C-020-1 | fix_point_err < 0.01     | the junction temperature this budget evaluates leakage at must agree within a per cent with the one 025 derives from the resulting power. This is a circular calculation expressed as a constraint, which is the only honest way to put one into a set of one-way derivations
C-020-2 | P_heat ~= P_input        | everything drawn from the supply leaves as heat. The one energy statement in this project that cannot be approximately true, and a failure here is a structural error rather than a design one
C-020-3 | P_conv_loss / P_heat < 0.20 | under a fifth of the machine's heat may be spent on nothing but changing voltage. Past that, 029 should be revisiting the domain count rather than the plumbing absorbing it
C-020-4 | P_idle < P_load / 4      | the machine switched on and doing nothing must cost under a quarter of what it costs working, or leakage is running the design
C-020-5 | P_engine_die > P_leak_die | the multipliers must dominate their own leakage. If this inverts, the die is too large or too hot, and either way the floorplan in 041 is wrong
C-020-6 | P_dies > P_core          | the compute dies dominate the memory. Asserted because it is what makes the cold plates and not the core laminae the hard cooling problem, and a change that inverted it would move the whole thermal design
```

## What is still open

**`E_op` is the number this whole budget rests on** and it is a `measured` figure
with no source. A quarter of a picojoule per operation is plausible for an
eight-bit multiply-accumulate at a leading node, and everything from the cold
plate's channel width to the radiator's face area is downstream of it.

**Leakage is modelled as one exponential.** Real leakage is several mechanisms
with different temperature dependencies, and the single doubling constant here is
a fit rather than a physics. It is accurate enough over a twenty kelvin span and
would not be over eighty.

**The spout does not appear.** It is a hundred and sixty-eight watts for
thirty-three microseconds, which is an energy rather than a power, and it lives
in `026`. If the spout ever runs continuously rather than in bursts, this budget
is missing nine per cent.
