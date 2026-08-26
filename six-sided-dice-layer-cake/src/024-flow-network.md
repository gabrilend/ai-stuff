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

f_served_min   | 1 | given | 0.85 | least share of the mean flow any face may receive and still have 025's worst case be the one being computed. A limit rather than a result, named so it is not a bare number sitting in a constraint

n_node_net     | 1 | solved | 29    | nodes in the hydraulic network the solve runs on -- from 102: eight supply corners, eight return corners, six supply plenums, six return plenums and the inlet header, with the outlet header as the reference every pressure is measured against
n_branch_net   | 1 | solved | 50    | branches joining them -- from 102: four inlet fittings, four outlets, six faces, and thirty-six rail segments, because a rail carrying a plenum is two rails with a tap between them
f_worst_served | 1 | solved | 1.0   | share of the mean flow the worst-served face receives under the assignment 023 chose -- from 102. Exactly one, and exactly rather than nearly: the chosen arrangement has a threefold symmetry that makes all six faces the same face, so no arithmetic can separate them
f_best_served  | 1 | solved | 1.0   | and the best-served face, which is the same number for the same reason -- from 102. Declared separately because the two being equal is the result, and a result written once looks like an assumption
f_worst_any    | 1 | solved | 0.9449244 | share of the mean the worst-served face receives under the least even of the sixty-four legal assignments -- from 102. This is the number the thermal chain is built on, not the one above, because a builder who wires the plumbing legally but not optimally must still get a machine that works
dp_network     | Pa | solved | 11393.29 | pressure from the pump's outlet to its inlet at the design flow, from the network solve rather than from summing one path -- from 102

dT_conv_worst  | K | derived | dT_conv / f_worst_any | the convection rise at the worst-served face, which is what 025 must use rather than the mean
f_path_over_net| 1 | derived | dp_loop / dp_network  | how much the single-path sum overstates the real circuit. Above one, and the amount is the manifold delivering to each plenum from both of its ends at once
```

## Constraints

```constraints
C-024-1 | Re_uchan < 2300               | the field must stay laminar. Every correlation in 022 assumes it, and turbulence would change the coefficient and multiply the pressure drop
C-024-2 | f_field_loss > 0.30           | the load must still be the largest single term even though the manifold is not negligible. Below this the rails are running the design and the cube has to grow
C-024-3 | v_uchan < v_erosion_max       | velocity in the channels must stay under what erodes silicon over the life in 086; it is under half a metre a second, so this is slack, and it is the rails that are close
C-024-4 | f_pump_of_heat < 0.01         | moving the coolant must cost under a hundredth of what it carries. It comes out near a thousandth, and this is the constraint that would notice if the channels were ever made much narrower
C-024-5 | f_worst_served > f_served_min | the worst-served field must get within fifteen per cent of the mean, or 025's worst case is not the one being computed. Under the chosen assignment it is the mean exactly, so this holds with the whole margin to spare -- which is why C-024-8 is the one that matters
C-024-8 | f_worst_any > f_served_min    | and so must the worst-served field under the least even legal assignment. This is the constraint C-024-5 was meant to be: it asks whether the design survives being built by somebody who followed the rules and not the drawing, and the answer is that the worst legal wiring costs five and a half per cent of one face's flow
C-024-9 | f_best_served >= f_worst_served | the best-served face cannot receive less than the worst-served one. A tautology, asserted because the two are separate solved values and a solver that returned them the wrong way round would otherwise go unnoticed
C-024-10 | dp_network < p_work          | the circuit's own loss, solved properly, must be inside the working pressure the seals in 017 are rated for. C-024-7 asks the same of the single-path sum, and the two are different numbers
C-024-11 | f_path_over_net > 1.0        | the single path must overstate the circuit rather than understate it. If this ever inverts, the hand sum has become optimistic and every estimate resting on it is unsafe rather than merely rough
C-024-12 | n_branch_net > n_node_net    | a network with more branches than nodes has loops in it, and a manifold that reaches every load from more than one direction is the whole point of the parity arrangement. A tree would mean somebody had simplified the plumbing into something that no longer describes it
C-024-13 | n_branch_net > 2 * n_face + n_corner | the network must be larger than one branch per face plus one per corner, which is what a solve that had quietly collapsed the rails into nothing would give. The estimate this blueprint started with -- twenty branches -- would fail this
C-024-6 | V_coolant < V_cube * f_wet_max | the fluid standing in the machine must be a bounded part of its volume, which is a sanity check on five separately derived wetted volumes. A tenth was tried and failed at eighteen per cent -- the core's laminae were being cut half through to remove seven watts a tier. The channels are shallower now and the bound is set at what a machine that is genuinely part heat exchanger comes to
C-024-7 | dp_loop < p_work              | the circuit's own loss must be inside the working pressure the seals in 017 are rated for
```

## What the solve found

**The network is bigger than this blueprint said it was.** Twenty branches across
eight nodes was the estimate, and it was the cube's own edges and corners rather
than its plumbing. The real object is fifty branches across twenty-nine nodes: the
supply and return networks are separate objects that happen to share a geometry,
every rail carrying a plenum is two rails with a tap between them, and the corner
blocks are branches rather than junctions.

**It is not a linear solve either.** Three regimes meet in one circuit. The
microchannel fields are laminar and lose pressure in proportion to flow. The rails
are turbulent on Blasius and lose it as flow to the power one and three quarters.
Every plenum entry, corner tee and rail end is a fitting and loses it as the
square. `102` solves it as a sequence of linear networks, each one built from the
last one's flows, which converges in about forty passes.

**The single path overstates the circuit by a quarter.** `dp_loop` adds up one
route from a fed corner to a drained one and charges that route for two whole
rails. The real manifold delivers to each plenum from both of its ends at once, so
the rails carry roughly half what the single path assumes and lose considerably
less than half the pressure. `f_path_over_net` is the ratio and `C-024-11` keeps
it on the safe side. **The hand sum is the conservative one, which is the right
way round for an estimate to be wrong.**

**The worst-served face is the mean face.** Not nearly — exactly. `023`'s chosen
assignment has a threefold rotation about a body diagonal that carries each face
onto another, so the six are one face seen six ways and no arithmetic can separate
them. Forty-eight of the sixty-four legal assignments do not have that symmetry
and leave one face five or six per cent short.

**So the thermal chain uses `f_worst_any` and not `f_worst_served`.** Building the
junction temperature on a perfect distribution would make the whole thermal budget
depend on the plumbing being assembled to the drawing rather than merely to the
rules. The worst legal wiring costs five and a half per cent of one face's flow,
and that is what `025` is given.

## What is still open

**Part-flow behaviour is described and not plotted.** The claim that halving the
flow costs about four kelvin is arithmetic anybody can do from the terms above,
and `027` builds its pump redundancy on it, so it should be a curve in this
blueprint rather than a sentence. `102` could produce it by solving at a sweep of
flows, which is a loop around something that already exists.

**No channel is ever blocked in this model.** `T2` in `009` asks how many of the
hundred and seventy-three channels in a field can stop before the face overheats,
and the network here has no way to express one. Removing channels from one face's
branch and re-solving is the experiment, and `102` is now the place to run it.

**The pump curve is not overlaid.** The solve fixes the flow and reports the
pressure that results, which is the system curve at one point. A real pump has a
curve of its own and the duty point is where the two cross; whether that crossing
sits on a flat part of the pump curve decides how much the operating point moves
when a channel partially blocks.
