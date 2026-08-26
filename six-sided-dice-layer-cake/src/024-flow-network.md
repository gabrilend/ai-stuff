# 024 — Where the flow actually goes

```meta
phase  | 3
issues | 305
```

Pressure at every node, flow in every branch, and the pump duty point that
results.

## Why it is not a division by six

Six fields in parallel do not each take a sixth. They take shares set by their
resistances and by where they sit in the manifold — and `016` withdrew the claim
that the manifold is negligible, so the shares are genuinely in question rather
than obviously equal.

What keeps them close is `023`: every point of either network is at most one edge
from a port, and no channel carries flow away from a load. That is the argument
now, and this blueprint is where it has to produce a number.

## The resistances, in order

```drawing
one path through the loop, from a fed corner to a drained one [not-dimensioned]

   inlet fitting
        │
   corner block ────────── divides three ways
        │
   supply rail ─────────── the largest manifold term
        │
   plenum ──────────────── spreads across the plate's width
        │
   microchannel field ──── the load, and where the heat crosses
        │
   plenum
        │
   return rail
        │
   corner block
        │
   outlet fitting
```

The field is the load and should dominate. It does, but not by the margin the
first attempt assumed: the two rails together are comparable to it, which is what
`016` found and did not paper over.

## The property nobody expects

**In laminar flow the convection coefficient does not depend on velocity.** So
halving the flow does not halve the cooling — it doubles only the coolant's own
temperature rise, which is under eight kelvin of a thirty-something kelvin chain.

A pump at half speed therefore costs about four kelvin of junction temperature,
not a factor of two. That makes partial pump failure genuinely graceful, and it
is the opposite of what a reader will assume, so `027` builds its redundancy
around it.

## Symbols

```symbols
f_wet_max     | 1 | given | 0.15 | the most of the cube's volume that may be standing fluid
eta_pump      | 1 | measured | 0.30 | wire-to-water efficiency of a pump of this size and duty; small pumps are poor and this is a realistic figure rather than a hopeful one
K_plenum      | 1 | given    | 2.20 | loss coefficient for entering and leaving a plenum and turning into the channel field, summed over both ends

Q_total       | m^3/s | derived | mdot_design / rho_fluid            | volumetric flow through the whole machine
Q_face        | m^3/s | derived | Q_total / n_face                   | through one face's field
Q_uchan       | m^3/s | derived | Q_face / n_uchan                   | through one microchannel
A_uchan       | mm^2  | derived | w_uchan * h_uchan                  | cross-section of one microchannel
v_uchan       | m/s   | derived | Q_uchan / A_uchan                  | velocity in one microchannel
Re_uchan      | 1     | derived | rho_fluid * v_uchan * D_uchan / mu_fluid | Reynolds number there; laminar by a wide margin, which every correlation in 022 depends on

fRe_uchan     | 1  | derived | 24 * (1 - 1.3553*alpha_uchan + 1.9467*alpha_uchan^2 - 1.7012*alpha_uchan^3 + 0.9564*alpha_uchan^4 - 0.2537*alpha_uchan^5) | the Fanning friction factor times Reynolds number for laminar flow in a rectangular duct, which is a constant for a given shape and is why laminar pressure drop is linear in velocity
f_uchan       | 1  | derived | 4 * fRe_uchan / Re_uchan             | Darcy friction factor in a microchannel
dp_field      | Pa | derived | f_uchan * (L_plate / D_uchan) * rho_fluid * v_uchan^2 / 2 | pressure lost crossing one face's field
dp_plenum     | Pa | derived | K_plenum * rho_fluid * v_uchan^2 / 2 | entering and leaving the plenum at both ends
dp_loop       | Pa | derived | dp_field + dp_plenum + 2 * dp_rail + 2 * dp_corner | the whole circuit inside the cube, one path from a fed corner to a drained one
f_field_loss  | 1  | derived | dp_field / dp_loop                   | the load's share of the loss, which is what says whether this is a manifold feeding a load or two comparable restrictions in series

V_field_wet   | mm^3 | derived | n_face * n_uchan * A_uchan * L_plate      | fluid standing in the six microchannel fields
V_plenum_wet  | mm^3 | derived | n_face * 2 * h_plenum * L_plate * w_rail  | and in the twelve plenums that feed and drain them
V_core_wet    | mm^3 | derived | n_tier * A_core_side * t_lamina * f_void_lam | and in the twenty-four cooling laminae inside the core, at the void fraction 036 derives from their channel geometry
V_coolant     | mm^3 | derived | V_field_wet + V_plenum_wet + V_rail_wet + V_corner_wet + V_core_wet | all of it, which is what 013 weighs and 027 has to make up when it leaks

P_hydraulic   | W | derived | Q_total * dp_loop        | work a second the fluid needs
P_pump        | W | derived | P_hydraulic / eta_pump   | electrical power the pump draws, which is outside the cube and outside 020's budget
f_pump_of_heat| 1 | derived | P_pump / P_heat          | what moving the coolant costs against what it carries

f_worst_served | 1 | target | 0.90 | share of the mean flow the worst-served face receives. A target rather than a derivation: solving a twenty-branch network needs a solver this notation does not have, and the figure here is an estimate from the manifold's share of the loss
dT_conv_worst  | K | derived | dT_conv / f_worst_served | the convection rise at the worst-served face, which is what 025 must use rather than the mean
```

## Constraints

```constraints
C-024-1 | Re_uchan < 2300               | the field must stay laminar. Every correlation in 022 assumes it, and turbulence would change the coefficient and multiply the pressure drop
C-024-2 | f_field_loss > 0.30           | the load must still be the largest single term even though the manifold is not negligible. Below this the rails are running the design and the cube has to grow
C-024-3 | v_uchan < v_erosion_max       | velocity in the channels must stay under what erodes silicon over the life in 086; it is under half a metre a second, so this is slack, and it is the rails that are close
C-024-4 | f_pump_of_heat < 0.01         | moving the coolant must cost under a hundredth of what it carries. It comes out near a thousandth, and this is the constraint that would notice if the channels were ever made much narrower
C-024-5 | f_worst_served > 0.85         | the worst-served field must get within fifteen per cent of the mean, or 025's worst case is not the one being computed
C-024-6 | V_coolant < V_cube * f_wet_max | the fluid standing in the machine must be a bounded part of its volume, which is a sanity check on five separately derived wetted volumes. A tenth was tried and failed at eighteen per cent -- the core's laminae were being cut half through to remove seven watts a tier. The channels are shallower now and the bound is set at what a machine that is genuinely part heat exchanger comes to
C-024-7 | dp_loop < p_work              | the circuit's own loss must be inside the working pressure the seals in 017 are rated for
```

## What is still open

**`f_worst_served` is a target and the checker says so.** Solving the network
properly means twenty branches, eight nodes and a linear solve, which this
notation cannot express and a small program could. Until then the worst case in
`025` rests on an estimate, and `025` is where the junction temperature comes
from. **This is the largest unfinished piece in the phase.**

**Which rail feeds which face is still not assigned** (`023`). Without it there
is no network to solve even if there were a solver.

**Part-flow behaviour is described and not plotted.** The claim that halving the
flow costs about four kelvin is arithmetic anybody can do from the terms above,
and `027` builds its pump redundancy on it, so it should be a curve in this
blueprint rather than a sentence.
