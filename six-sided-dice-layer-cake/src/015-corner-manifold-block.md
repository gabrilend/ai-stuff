# 015 — The corner manifold block

```meta
phase  | 2
issues | 203
```

One part, made eight times, in two variants that differ only in whether a port is
drilled. It joins the three edge rails meeting at a vertex, and it does four jobs
at once.

## What it does

```drawing
a corner block in section, showing both chambers

        to the +z rail                 [L_corner]
              ▲                    ├──────────────┤
              │
        ┌─────┴──────────────────────────────┐   ─┬─
        │  ╔═══════════════════════════╗     │    │
        │  ║   supply chamber          ║─────┼──▶ │  to the +x rail
        │  ╚═══════════════════════════╝     │    │
        │  ────── [t_chamber_wall] ──────    │  [L_corner]
        │  ╔═══════════════════════════╗     │    │
        │  ║   return chamber          ║─────┼──▶ │
        │  ╚═══════════════════════════╝     │    │
        └─────┬──────────────────────────────┘   ─┴─
              │
              ▼ to the +y rail
        the external fitting, on four blocks of the eight,
        opens into one chamber only
```

**It joins three supply channels to each other, and separately three return
channels.** Two chambers in one solid, never connected. That is the whole
hydraulic content: a tee with three legs, twice.

**It carries the external fitting**, on four blocks. Which four is the parity
rule from `010`. The other four are the same casting with the port operation
omitted — the chambers still join their rails, they simply have no opening. One
part number, not two.

**It is the stiffest point of the cube**, so `019` bolts to four of them.

**It closes the corner of the envelope**, meeting three rails and three face
plates along nine seal lines. This is the hardest sealing geometry in the machine
and `017` solves it here, where it is hard, rather than along the edges, where it
is not.

## How transparent it actually is

Three and a half litres a minute enters across four inlet blocks, so a little
under nine tenths of a litre per block, dividing three ways at about a metre a
second.

The intention was that a corner should cost under a hundredth of the loop, so
that `023`'s pressure-balance argument could lean on the manifold being
invisible. **It does not come out that way.** A block loses on the order of six
hundred pascals against a loop total near twenty-four kilopascals — two and a
half per cent, not one, and the rails in `016` are worse again.

That matters more than it sounds. A manifold that is a tenth of the resistance
can introduce at most a tenth of the maldistribution however badly it is built;
one that is a third cannot be waved away, and `024` has to solve the network
rather than assume the loads are equal. The constraint below is set at what the
geometry actually achieves, and the honest version of `023`'s argument is that
the **parity topology** balances the network, not that the manifold is
negligible.

## The wall between the chambers

The dangerous one. A leak from supply to return inside a corner block
short-circuits the cooling loop while showing **nothing** on any external sensor
— flow, pressure and temperature at the inlet all look normal while the faces
stop being cooled. It gets its own thickness requirement, checked as a flat plate
against burst pressure rather than as a cylinder, because that is what it is.

## Symbols

```symbols
A_chamber     | mm^2 | given | 14.0  | cross-section of one chamber inside a corner block; two of these and their walls are what set the block's size
t_chamber_wall| mm   | given | 1.60  | the wall separating the supply chamber from the return chamber
t_outer_wall  | mm   | given | 1.20  | wall between a chamber and the outside of the block
d_port        | mm   | given | 6.0   | bore of the external coolant fitting on the four ported blocks
K_tee         | 1    | given | 1.10  | loss coefficient for a three-way division at this geometry and Reynolds number
n_seal_corner | 1    | given | 9     | seal lines where three rails and three plates meet one block

V_chamber     | mm^3 | derived | A_chamber * L_corner            | volume of one chamber
V_corner_wet  | mm^3 | derived | 2 * V_chamber * n_corner        | fluid standing in all eight corner blocks
Q_corner_in   | m^3/s| derived | Q_total / n_corner_in           | volumetric flow entering one inlet block
v_corner      | m/s  | derived | Q_corner_in / A_chamber         | velocity in an inlet block's supply chamber
dp_corner     | Pa   | derived | K_tee * rho_water * v_corner^2 / 2 | pressure lost dividing three ways in one block
f_corner_loss | 1    | derived | dp_corner / dp_loop             | that loss as a fraction of the whole loop's
p_burst_wall  | Pa   | derived | 2 * sigma_ss_y * t_chamber_wall^2 / (3 * A_chamber) | pressure a flat wall of this thickness spanning this chamber will take before yielding
m_corner_one  | kg   | derived | L_corner^3 * f_solid_corner * rho_ss | mass of one block
```

## Constraints

```constraints
C-015-1 | f_corner_loss < 0.05           | a corner block loses a few per cent of the loop's pressure, not a fraction of one. The first attempt asked for under a hundredth and the geometry could not deliver it, so 024 must solve the network rather than assume the manifold is invisible
C-015-2 | p_burst_wall > p_proof         | the wall between the supply and return chambers must hold proof pressure. A leak here short-circuits the cooling loop and shows nothing on any external sensor, which makes it the most dangerous single failure in the machine
C-015-3 | t_outer_wall * 2 + 2 * sqrt(A_chamber) + t_chamber_wall <= L_corner | two chambers, their shared wall and their outer walls must fit inside the block
C-015-4 | d_port^2 * pi / 4 >= A_chamber | the external fitting's bore must be at least the chamber's own section, or the fitting is the restriction rather than the block
C-015-5 | n_seal_corner * n_corner == 72 | seventy-two seal lines at the corners alone, before 014's ninety-six island rings are counted. Asserted so the number is in the record rather than discovered by 017
C-015-6 | v_corner < v_erosion_max       | velocity in a corner chamber must stay under what the material tolerates before flow erosion becomes a lifetime problem
```

## What is still open

**The loss coefficient is a handbook number.** `K_tee` is entered as a `given`
with a plausible value, not derived from the geometry. The geometry is simple
enough for a first-principles estimate and a handbook coefficient is a number
nobody downstream can change with confidence. It should become `derived`.

**The nine-seal corner has not been drawn.** The section above shows the
chambers, not the sealing geometry where three rails and three plates arrive at
one block. That drawing is what `017` actually needs and it does not exist.
