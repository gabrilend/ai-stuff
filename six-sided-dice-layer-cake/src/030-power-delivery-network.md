# 030 — Where the copper goes

```meta
phase  | 4
issues | 403
```

The physical conductor from the forty-eight volt input to the last transistor,
level by level, with a resistance for each and an accumulated drop.

## The rule this blueprint exists to enforce

**No current passes through a corner or along an edge.**

The corners are hydraulic and the edges are hydraulic. Mixing a power plane with
water inside a sealed object that cannot be opened is a decision nobody should be
able to make by accident, so it is written at the top as a rule and every drawing
is checkable against it.

The consequence is that power is purely radial: in at a face, outward-to-inward
through that face's own stack, and one sixth of the core's share continuing
inward through the same interface the data uses.

```drawing
one face's power path, outward to inward [not-dimensioned]

   the outside      [V_supply], a few amperes
        │
   port field land array
        │
   through the cold plate, via islands ─── every ampere entering a face
        │                                   passes through sixteen small
   first stage, on the interposer           holes in a water-cooled plate
        │
   interposer planes at [V_mid]
        │
   integrated regulators
        │
   microbump array ─────────── [I_die_logic] into each die
        │
   die power grid
        │
   the transistors

   and, separately, inward through the radial pillar array to the cage
```

## The two hard levels

**The via islands.** `014` sized them for conductor count; this sizes them for
current, and for the heat those conductors make — which is deposited *inside a
channel field*, the one place in the machine where a resistive loss is also a
thermal load sitting in the coolant path. The finding is that they are
comfortable: at the supply voltage the current is a few amperes, and the pads
available are three orders of magnitude more than that needs.

**The regulator output.** Seventy amperes at three quarters of a volt over a few
millimetres, with about twenty-two millivolts to spend. That is a third of a
milliohm, which is an area problem rather than a routing one: it decides how much
of the interposer is copper, which decides its thickness, which feeds back into
`014`'s stack and `012`'s face thickness.

## Symbols

```symbols
t_plane_mid   | mm | given | 0.070 | thickness of one interposer plane carrying the intermediate rail
n_plane_mid   | 1  | given | 2     | such planes, one out and one back
t_grid_metal  | um | given | 3.0   | thickness of the top metal layer a die's power grid is built in
f_grid_metal  | 1  | given | 0.60  | share of that layer given to power rather than signal
L_reg_to_die  | mm | given | 3.0   | distance from a regulator's output to the microbumps it feeds
n_pillar_pwr  | 1  | derived | n_radial_pad * f_radial_power | radial pillars carrying current inward rather than data
i_pad_max     | mA | given | 5.0   | current one twenty-micron copper pillar carries, a fifth of what it would take, because 032 wants the margin

R_island      | ohm | derived | res_cu * t_coldplate / (n_island_pad * pi * (p_island_pad/4)^2) | resistance of all the via island feedthroughs on one face in parallel
dV_island     | V   | derived | I_face_supply * R_island                    | drop across them at the supply voltage, where the current is small
P_island_loss | W   | derived | I_face_supply^2 * R_island                  | heat those conductors make, deposited inside the channel field
R_plane       | ohm | derived | res_cu * L_plate / (n_plane_mid * t_plane_mid * L_plate) | resistance of the interposer planes carrying the intermediate rail across a face
dV_plane      | V   | derived | (P_input / n_face / V_mid) * R_plane       | drop across them
A_grid        | mm^2| derived | L_die * t_grid_metal * f_grid_metal        | cross-section of one die's power grid, taken across the die's width in the top metal
R_grid        | ohm | derived | res_cu * L_reg_to_die / A_grid             | resistance from a regulator's output to the far side of a die
dV_grid       | V   | derived | I_die_logic * R_grid                       | drop across it at the design current
dV_total      | V   | derived | dV_grid + dV_plane                         | accumulated static drop to the worst-placed transistor, at the logic rail
R_to_load     | ohm | derived | dV_grid / I_die_logic                      | the resistance the last level actually presents
R_to_load_max | ohm | derived | dV_droop_logic / I_die_logic               | the most it may present, from the droop allowance in 029
I_pillar_cap  | A   | derived | n_pillar_pwr * i_pad_max                   | current the radial pillar array will carry inward
f_pillar_used | 1   | derived | I_core_face / I_pillar_cap                 | how much of that capability the core's inward supply actually uses
```

## Constraints

```constraints
C-030-1 | dV_total < dV_droop_logic      | the accumulated static drop to the worst-placed transistor must fit inside the droop allowance, leaving nothing for the transient in 031. That is deliberately harsh: static drop is always present, so spending the whole allowance on it would mean the rail is out of specification the moment anything switches
C-030-2 | R_to_load < R_to_load_max      | the same statement at the level where it binds
C-030-3 | f_pillar_used < 0.20           | the radial interface must spend under a fifth of its power-carrying capability on the core's supply, because the rest of it is 051's signal integrity budget and current is not what limits that interface
C-030-4 | P_island_loss < P_heat / 1000  | the heat the via island conductors make, which lands inside the coolant channels, must be under a thousandth of the machine's total. It comes out far below, which is the finding: the islands are a sealing problem and not an electrical one
C-030-5 | t_plane_mid * n_plane_mid < t_interposer | the planes must fit inside the interposer they are built in
C-030-6 | I_pillar_cap > I_core_inward   | the six radial interfaces together must carry the whole core's current even though each carries a sixth, so that losing a face is a loss of compute and not of memory
```

## What is still open

**Five volts or twelve.** `009` entry P1. Twelve quarters the current in the
interposer planes and therefore the copper needed there, at the cost of a harder
second conversion ratio and a worse efficiency. It changes the interposer
thickness, which changes the face thickness, which changes the cube — so it
should not stay open long. The comparison is two lines of arithmetic and it has
not been written.

**The regulator itself is not specified.** `031` needs its response time and
`033` needs its behaviour on a sagging input, and neither is here. An integrated
regulator responding in ten nanoseconds is assumed throughout and nothing says
what kind it is.
