# 013 — The cube envelope

```meta
phase  | 2
issues | 201
```

The finished object as a mechanical part: what sticks out of it, what it weighs,
and how much any of it is allowed to be wrong by.

## What is on the outside

```drawing
one face, looking inward along its own normal

    C-- ────────────── [L_cube] ────────────── --C
     │  ┌──┬────────────────────────────┬──┐  │
     │  │  │                            │  │  │   ── [w_rail] of edge rail
     │  ├──┼────────────────────────────┼──┤  │      on all four sides
     │  │  │                            │  │  │
     │  │  │      the port field,       │  │  │   ── the face plate,
     │  │  │      [L_plate] square      │  │  │      [A_plate]
     │  │  │                            │  │  │
     │  │  │                            │  │  │
     │  ├──┼────────────────────────────┼──┤  │
     │  │  │                            │  │  │
     C-- └──┴────────────────────────────┴──┘  --C
         corner manifold blocks at all four corners,
         four of the eight cube corners carry a fitting
```

Six port fields, all identical, populated differently (`056`). Eight corner
manifold blocks, four with a coolant inlet fitting and four with an outlet, by
the parity rule in `010`. Twelve edge rails, internal to the envelope but
defining it. Four mounting features, on the corner blocks of one chosen face
(`019`).

## What it weighs

Worth deriving rather than guessing, because a two hundred and sixteen cubic
centimetre object weighing a kilogram is a surprising thing to hand somebody, and
because `019` has to bolt it to something.

Nearly all of it is the core's cooling laminae. The cube is, by mass, a block of
molybdenum composite with some silicon laminated through it and a shell of
electronics around the outside.

Every mass term below is a volume from `012`'s geometry times a density from
`011`. None is entered. The moment a mass is written in grams it stops tracking
the shape.

## Tolerances

The stack that matters closes around a **loop** rather than along a line: four
face plates meeting edge to edge around one great circle of the cube, each
carrying a compression seal. Errors do not cancel; they accumulate around the
loop and the last joint takes the sum.

The binding number is face plate flatness, and `017` cannot be written until it
exists. It is carried here as a given because it is a manufacturing capability
rather than a derivation.

## Symbols

```symbols
# --- tolerances, all of them manufacturing capabilities rather than choices ---
tol_L_cube    | mm  | given | 0.050 | tolerance on the cube's outer edge, achievable by grinding the assembled rails
tol_L_plate   | mm  | given | 0.025 | tolerance on a face plate's edge
flat_plate    | mm  | given | 0.050 | flatness of a face plate over its full width, at any temperature in the operating range. Fifteen microns was tried first, which is what the process achieves cold; 018 then found the assembly bows forty-five when hot, and a flatness figure that only holds at one temperature is not one
tol_stack_n   | 1   | given | 4     | face plates in the loop the tolerance stack closes around

# --- what the outside looks like ---
A_exterior    | mm^2 | derived | n_face * L_cube^2 | outer surface area of the cube, ignoring the corner chamfers
tol_loop      | mm   | derived | tol_stack_n * (tol_L_plate + flat_plate) | worst-case accumulation around one great circle, where every plate errs the same way

# --- mass, all derived from 012's geometry and 011's densities ---
t_coldplate   | mm | given | 2.000 | thickness of a face cold plate, base and channels and cover together
t_interposer  | mm | given | 1.500 | thickness of a face interposer, glass core with its planes
t_die         | mm | given | 0.100 | thickness of a compute die after thinning
rho_glass     | kg/m^3 | measured | 2500 | density of the interposer's glass core
f_solid_rail  | 1  | given | 0.60  | fraction of an edge rail's square section that is metal rather than channel
f_solid_plate | 1  | given | 0.75  | fraction of a cold plate that is silicon rather than channel
L_corner      | mm | given | 12.0  | edge of a corner manifold block, set by the two chambers that have to fit inside it (015)
f_solid_corner| 1  | given | 0.55  | fraction of a corner block that is metal rather than chamber
rho_cage      | kg/m^3 | given | 3000 | mean density of the cage shell, silicon and copper and void together
m_ports       | kg | given | 0.150 | port fields, regulators and connectors on all six faces, weighed as an assembly

m_laminae     | kg | derived | n_tier * A_core_side * t_lamina * rho_cumo    | the thirty-two cooling plates inside the core, which are most of the machine's mass
m_tiers       | kg | derived | n_tier * A_core_side * t_tier_si * rho_si     | the thirty-two memory tiers between them
m_coldplate   | kg | derived | n_face * A_plate * t_coldplate * f_solid_plate * rho_si | six silicon cold plates, less the channels etched out of them
m_dies        | kg | derived | n_die * A_die * t_die * rho_si                | twenty-four compute dies
m_interposer  | kg | derived | n_face * A_plate * t_interposer * rho_glass   | six face interposers
m_rails       | kg | derived | n_edge * w_rail * w_rail * L_plate * f_solid_rail * rho_ss | twelve edge rails
m_corners     | kg | derived | n_corner * L_corner^3 * f_solid_corner * rho_ss | eight corner manifold blocks
m_cage        | kg | derived | (L_cavity^3 - L_core^3) * rho_cage            | the switch shell filling the space between the cavity wall and the core
m_coolant     | kg | derived | V_coolant * rho_water                         | the fluid standing in the machine when it is running
m_cube        | kg | derived | m_laminae + m_tiers + m_coldplate + m_dies + m_interposer + m_rails + m_corners + m_cage + m_ports + m_coolant | the finished object, wet
rho_mean      | kg/m^3 | derived | m_cube / V_cube                           | mean density of the whole machine
```

## Constraints

```constraints
C-013-1 | tol_loop <= seal_compression_range | the tolerance accumulated around a loop of four face plates must fit inside what the compression seal in 017 can take up. This is expected to be tight and is the constraint most likely to force either a flatter plate or a softer seal
C-013-2 | rho_mean > rho_water        | the machine is denser than the fluid in it, which is the weakest possible sanity check on a mass built from ten separate volume-times-density terms and would still catch a factor of a thousand
C-013-3 | rho_mean < rho_cumo         | and less dense than the densest thing in it, which catches a term counted twice
C-013-4 | m_laminae > m_tiers         | there is more cooling plate than memory in the core, by a large factor. This is the design and not an accident, and asserting it means a change to the tier pitch that quietly inverted it would be noticed
C-013-5 | A_exterior > 6 * A_plate    | the outer surface is larger than the six face plates, because the edge rails are part of it
C-013-6 | L_corner < L_cube / 4       | a corner block is small next to the cube; a block that grew past this would be interfering with its neighbours along an edge
```

## What is still open

**`C-013-1` is the phase's real question** and it cannot be answered here.
Fifteen microns of flatness over fifty-two millimetres is a real requirement for
a bonded silicon assembly, and four of them plus four edge tolerances is a
hundred and sixty microns accumulated around the loop. Whether an elastomer seal
in a groove can take that up while holding two bar is `017`'s to say, and if it
cannot, one of the two has to move.

**The chamfers are not modelled.** `A_exterior` treats the cube as six flat
squares, which it is not — the corner blocks are chamfered where three faces
meet, and the mass and area terms both ignore it. The error is under a per cent
and it should be either fixed or stated in the drawing rather than left as an
unmarked simplification.
