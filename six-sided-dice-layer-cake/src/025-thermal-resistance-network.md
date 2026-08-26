# 025 — Junction to room, every term

```meta
phase  | 3
issues | 306
```

The complete chain from a transistor junction to the air in the room, every term
derived from a geometry and a material property, and **worst case at every step**.

## The chain

```drawing
one path for one joule [not-dimensioned]

   junction
      │  local convection excess over the engine        the dominant term
      ▼
   die back face
      │  conduction through the die
      ▼
   bond
      │  copper to copper, negligible
      ▼
   cold plate base
      │  conduction through silicon
      ▼
   channel wall
      │  convection into the fluid, at the worst-served face
      ▼
   the fluid
      │  sensible heating, half the rise at the mean point
      ▼
   the radiator
      │  convection into air, outside the cube
      ▼
   the room
```

## Where the heat gets stuck, which is not where anybody expects

Not the coolant. The coolant is responsible for about two kelvin out of a chain
of thirty-something. **The largest single term by a factor of five is the local
convection excess over the multiplier array** — and the mechanism is not what the
word *spreading* suggests.

The heat does not have far to go. The cold plate is bonded to the whole back of
the die and the channels are directly above, so getting out of the silicon
vertically is a fifth of a kelvin.

The problem is that **only the channels directly above the engine are available
to it.** The multiplier array is a tenth of the die and makes seventy per cent of
its heat, so a tenth of the wetted area removes seventy per cent of the load.
Locally that is about twelve kelvin instead of the face's two.

**This is a silicon floorplanning problem wearing a plumbing costume**, and
`041` is where it is actually solved — by not putting all the multipliers in one
place.

## Worst case, everywhere, and why

Every term takes its worst value at the same time: the worst-served field from
`024`, the hottest point in the coolant path, the highest-power die, the hottest
region on it.

That is pessimistic and it is correct. A thermal design validated at the mean is
a design that fails on one part in six, and one part in six of a fleet of these
is not an acceptable answer.

## The fixed point

`020` evaluates leakage at a junction temperature it cannot compute. This
blueprint computes it. The two must agree, and `C-020-1` is where that is
enforced — a circular calculation expressed as a constraint, which is the only
way to put one into a set of one-way derivations.

## Symbols

```symbols
dT_margin_min  | K | given | 20.0  | the least margin the hottest transistor must keep against its limit, given that the hot spot term rests on a floorplan that could still move
dT_conv_max    | K | given | 4.0   | the most 022's convection term may take of the budget between the coolant and the silicon
T_room         | K | given | 295.0 | air the radiator rejects into

# conduction, all of it small, and derived anyway so that a thinner die shows up
R_die          | K/W | derived | t_die / (k_si * A_die_total)                     | one-dimensional conduction through all twenty-four dies in parallel
R_plate_base   | K/W | derived | (t_coldplate - h_uchan) / (k_si * n_face * A_plate) | through the base of the six cold plates
dT_die         | K   | derived | P_dies * R_die                                   | the drop across the dies
dT_plate       | K   | derived | P_heat * R_plate_base                            | the drop across the plate bases

# the local term, which is the one that matters
A_wet_engine   | mm^2 | derived | f_engine_area * A_die * A_wet_face / A_plate     | heated channel area lying above one die's multiplier array
dT_conv_local  | K    | derived | f_engine_power * P_die / (h_conv * eta_surface * A_wet_engine) | convection rise directly over the array, where a tenth of the area carries seventy per cent of the heat
dT_hotspot     | K    | derived | dT_conv_local - dT_conv_worst                    | how much hotter the array is than the face average; this is what 005 calls the hot spot term

# the chain
dT_fluid_mean  | K | derived | dT_rise / 2                                        | the coolant's own rise at the mean point along its path
T_j_peak       | K | derived | T_coolant_in + dT_rise + dT_conv_worst + dT_hotspot + dT_plate + dT_die | junction temperature at the hottest point of the hottest die on the worst-served face, with the coolant at its outlet temperature
T_j_mean       | K | derived | T_coolant_in + dT_fluid_mean + dT_conv + dT_plate + dT_die | and the same for an average die in the middle of the coolant path
margin_thermal | K | derived | T_si_max - T_j_peak                                | how far the hottest transistor is from what the silicon is qualified to
fix_point_err  | 1 | derived | abs(T_j_assumed - T_j_peak) / T_j_assumed          | how far 020's assumed leakage temperature is from what this chain produces

# sensitivity, so a reader can see at a glance which number to go and improve
s_hotspot      | 1 | derived | dT_hotspot / (T_j_peak - T_coolant_in)             | the hot spot's share of everything above the inlet
s_conv         | 1 | derived | dT_conv_worst / (T_j_peak - T_coolant_in)          | the channel wall's share
s_fluid        | 1 | derived | dT_rise / (T_j_peak - T_coolant_in)                | the coolant's own share
s_solid        | 1 | derived | (dT_plate + dT_die) / (T_j_peak - T_coolant_in)    | everything conducted through solid
```

## Constraints

```constraints
C-025-1 | T_j_peak < T_si_max          | the hottest transistor on the worst die on the worst-served face must stay under what the silicon is qualified to. The one constraint the whole phase exists for
C-025-2 | margin_thermal > dT_margin_min | and by at least twenty kelvin, because the hot spot term rests on a floorplan that 041 has not finished and could move
C-025-3 | dT_conv_worst < dT_conv_max  | the channel wall's share must stay inside its allowance
C-025-4 | s_hotspot > s_conv           | the hot spot must be the largest term. Asserted not because it is desirable but because it is true, and a design change that made the coolant dominant instead would mean something had gone badly wrong in 022
C-025-5 | s_hotspot + s_conv + s_fluid + s_solid ~= 1 | the four shares account for everything between the inlet and the junction, with nothing unattributed
C-025-6 | T_j_mean < T_j_peak          | the average die is cooler than the worst one, which is trivially true and catches a worst-case term accidentally applied to both
```

## What is still open

**The hot spot term rested on a floorplan that did not exist** when this was
written; `041` now derives both shares from a layout, so the term follows from
one rather than from an intention. If the array turns out denser than a tenth of the die
or hotter than seventy per cent of its power, this term grows in proportion and
the twenty kelvin of margin in `C-025-2` is what absorbs it. **`009` entry T1, and
it is the highest-value open question in the project.**

**In-die lateral spreading is ignored.** The local term assumes the array's heat
goes straight up into the channels above it and none of it moves sideways into
the cooler silicon around it. That is pessimistic — real spreading would reduce
the term — and it is pessimistic in a direction that does not cost anything to
keep, since the alternative is a two-dimensional calculation nobody has done.

**`dT_conv_worst` inherits a target.** It is the mean convection rise divided by
`024`'s worst-served fraction, and that fraction is a target rather than a solved
network. So the headline junction temperature is derived from an estimate, and
that is the honest state of it.
