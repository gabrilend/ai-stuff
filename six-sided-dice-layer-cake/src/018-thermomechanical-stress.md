# 018 — What heating it does to it

```meta
phase  | 2
issues | 206
```

What differential expansion does to every bonded interface, over the temperature
swings it will actually see, repeated for the life required.

## The number the whole blueprint turns on

Silicon expands at two and a half parts per million per kelvin. Copper at sixteen
and a half. Across a fifty-two millimetre part and a sixty kelvin swing that is
**forty microns of relative motion at a bond ten microns thick.**

If the bond is rigid the strain goes into the silicon, and a hundred megapascals
is enough to break a die with an ordinary edge finish. If the bond is compliant
the strain goes into the bond, and the bond fatigues. There is no third option;
the only real lever is to stop the mismatch existing.

## The interfaces

```drawing
where two materials are bonded and disagree about temperature [not-dimensioned]

   die  ──── silicon ──── cold plate      matched, by choice in 014
   tier ──── silicon ──── CuMo lamina     4.4 ppm/K apart, once per tier
   die  ──── silicon ──── glass core      0.6 ppm/K apart, glass chosen for it
   plate ─── silicon ──── steel rail      14.7 ppm/K apart, taken by a seal
   cage ──── silicon ──── CuMo            4.4 ppm/K apart
```

The first row is what choosing silicon for the cold plate bought: exactly zero.
The second is what it did not buy — one interface per tier, each moving eleven
microns, and the molybdenum composite is the compromise that got it down from
thirty-three.

The fourth row is large and does not matter, because that joint is a compression
seal rather than a bond and a seal is a thing designed to slide.

## The three swings, which are not the same

**Assembly.** From bonding temperature to room, once. Largest excursion, and it
is built into the part as residual stress before anything is ever powered on.

**Power cycling.** Room to operating, a hundred thousand times over the life in
`086`. Smaller amplitude, enormous count. This is what fatigues.

**Load stepping.** A face going idle to full within a token, four thousand
million million times over ten years. Tiny amplitude, astronomical count,
confined to the die and its nearest bond. `026` produces the history; this turns
it into a count.

## Warpage, which is how a thermal problem becomes a sealing problem

A stack of dissimilar layers bonded flat at one temperature is not flat at
another. The face assembly is eight layers and several are asymmetric about the
neutral axis, so it bows like a bimetallic strip — and the bow is what breaks the
tolerance stack in `013`, which breaks the seal in `017`.

## Symbols

```symbols
dT_assembly   | K | given | 130.0 | swing from the hybrid bonding temperature down to room, taken once
dT_power      | K | given | 60.0  | swing from cold to operating, taken a hundred thousand times
dT_load       | K | given | 8.0   | local swing at a die when its engine goes idle to full and back
n_cyc_power   | 1 | given | 1e5   | power cycles over the machine's life, from 086
n_cyc_load    | 1 | given | 4e12  | load steps over the same, at thirteen layers a token and a thousand tokens a second
bow_coeff     | ppm/K | measured | 12.0 | effective expansion mismatch of the face stack about its own neutral axis, six times the layer-to-layer difference, which is what sets its curvature

strain_tier   | 1  | derived | (cte_cumo - cte_si) * dT_power              | strain at a tier-to-lamina interface over a power cycle
strain_glass  | 1  | derived | (cte_glass - cte_si) * dT_power            | the same at a die-to-interposer interface
strain_plate  | 1  | derived | (cte_ss - cte_si) * dT_power               | the same at a plate-to-rail joint, which is a seal and not a bond
strain_cu_alt | 1  | derived | (cte_cu - cte_si) * dT_power               | what the tier interface would be if the laminae were copper; the number that chose the material
disp_tier     | mm | derived | strain_tier * L_core                       | relative motion at a tier interface, corner to corner
disp_plate    | mm | derived | strain_plate * L_plate                     | the same at a plate-to-rail joint
disp_cu_alt   | mm | derived | strain_cu_alt * L_core                     | and what copper would have moved
sigma_tier    | Pa | derived | E_si * strain_tier                         | stress in the silicon at a tier interface, taking the bond as rigid, which is the pessimistic case and the cheap one to compute
sigma_glass   | Pa | derived | E_si * strain_glass                        | the same at a die-to-interposer interface
sigma_cu_alt  | Pa | derived | E_si * strain_cu_alt                       | and what copper laminae would have induced
sigma_assembly| Pa | derived | E_si * (cte_cumo - cte_si) * dT_assembly    | residual stress frozen into a tier interface at bonding, before the machine is ever switched on
sigma_cu_assy | Pa | derived | E_si * (cte_cu - cte_si) * dT_assembly      | residual a copper lamina would have frozen in at bonding
sigma_cu_total| Pa | derived | sigma_cu_alt + sigma_cu_assy                | everything a copper lamina would put into the silicon, operating and residual together
margin_tier   | 1  | derived | sigma_si_plas / (sigma_tier + sigma_assembly) | how many times the fracture stress of a plasma-diced edge exceeds what a tier interface actually carries, residual included
margin_cu_alt | 1  | derived | sigma_si_plas / sigma_cu_total              | the same margin copper laminae would have left
bow_face      | mm | derived | bow_coeff * dT_power / t_stack * L_plate^2 / 8 | mid-span bow of a face assembly over a power cycle, taken as a circular arc of curvature bow_coeff times the swing over the stack thickness
```

## Constraints

```constraints
C-018-1 | sigma_tier + sigma_assembly < sigma_si_plas | stress at a tier interface, with the residual from assembly included, must stay under what plasma-diced silicon breaks at. Residual is included because it is already there before the machine runs, and a check that ignores it is checking the wrong number
C-018-2 | margin_tier > 2.0                | and by at least a factor of two. Against an ordinary sawn edge this comes out at one point four, which is what turned plasma dicing from a preference into a requirement on 1201
C-018-3 | margin_cu_alt < 2.0              | asserted deliberately in the direction of alarm: copper laminae would leave no usable margin at all, against the composite's three. This is the calculation that chose the material, and having it here as a constraint means the choice cannot be quietly reversed
C-018-4 | sigma_glass < sigma_si_plas / 10 | the die-to-interposer interface should be far from trouble; glass was chosen for its expansion and if this is close, the wrong glass is specified
C-018-5 | bow_face <= flat_plate           | a face assembly's bow over a power cycle must stay inside the flatness 013 assumed, or the tolerance stack that 017 already fails is worse than it looks
C-018-6 | disp_tier < disp_cu_alt          | the composite moves less than copper would, which is the only reason to use a material with half the conductivity
```

## What is still open

**The bow turned out to be three times the flatness allowance**, which is the
finding that mattered most in this phase. Forty-five microns against fifteen.
Fifteen was never a real number: it is what the process achieves at one
temperature, and this machine runs at another. `013`'s flatness went to fifty,
`017`'s cord to two and a half millimetres, and `014` gave up seventy microns of
plenum height to make room. The alternative — reordering the face stack to move
its neutral axis and stop it bowing — was not attempted and is the better answer
if anybody wants those seventy microns back.

**The bow coefficient is a `measured` figure with no source.** It is the least
defensible number in the phase and it decided all three of the changes above. It
wants a layered-beam calculation from `014`'s actual stack, which is an
afternoon's work nobody has done.

**Fatigue life is not computed at all.** Three swings are counted here and none
is turned into a number of cycles to failure for the bonds that take them. `086`
asserts a lifetime that this blueprint is supposed to support and currently does
not.
