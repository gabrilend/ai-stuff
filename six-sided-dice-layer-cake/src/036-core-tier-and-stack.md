# 036 — Twenty-four layers, and what is between them

```meta
phase  | 5
issues | 503
```

One tier in section, the repeating unit, and the vertical connectivity that lets
any face reach any tier. This is the layer cake the project is named after.

```drawing
the repeating unit of the core stack

   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   memory tier, [t_tier_si]
   ═══════════════════════════════════════   copper-to-copper bond
   ┌─────┬─────┬─────┬─────┬─────┬───────┐
   │  ╷  │  ╷  │  ╷  │  ╷  │  ╷  │  ╷    │   cooling lamina, [t_lamina]
   │  ╵  │  ╵  │  ╵  │  ╵  │  ╵  │  ╵    │   copper-molybdenum, channels cut
   └─────┴─────┴─────┴─────┴─────┴───────┘
   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓   the next tier down
        │                        │
        └── through-stack vias ──┘           the whole [L_core] height

   one pitch is [t_tier_pitch]; [n_tier] of them make [L_core]
```

**Three per cent silicon by volume.** The core is a heat exchanger with memory in
it, and the ratio is not a compromise — it is what makes a solid block of static
memory at the geometric centre of a sealed cube survivable at all.

## Why twenty-four and not thirty-two

Thirty-two was the first sketch, chosen because it made the pitch a round
number. `035` then derived an areal density from the bitcell up, and at that
density thirty-two tiers hold half again what the reference model needs — silicon
nobody uses, paying leakage forever.

Twenty-four lands just above sixty-four gibibytes usable, and gives each tier a
lamina a third thicker into the bargain, which the core's own cooling wanted
anyway.

## What the tier's heat actually crosses

Seven watts leave a tier and reach a channel wall by three steps in series, and
until the copper-molybdenum's conductivity was noticed sitting unused in `011`,
only the last of the three was being counted.

| step | resistance | rise |
|---|---|---|
| out of the silicon, half a tier | small | negligible |
| through the lamina's metal, half a lamina | twenty times the silicon's | a fiftieth of a kelvin |
| off the metal into the water | — | a quarter of a kelvin |

**The lamina is the larger conduction term and it is still nothing.** That is
worth stating because it is the opposite of what the material choice suggests:
copper-molybdenum was picked for its conductivity, conducts almost twice as well
as silicon, and is nonetheless twenty times the resistance — because it is thirty
times thicker. The lamina is thick because the stack height demanded it, which
this blueprint already said, and this is that trade charged in kelvin.

**The film governs, by a factor of twelve.** So the thing to change if a tier ever
runs hot is the channel geometry, not the metal. `C-036-10` is what would notice
if that stopped being true.

Every number in that table is recomputed by `./run-demo 5`; the words round.

## Why the lamina is copper-molybdenum

The same argument as `014`'s cold plate, one axis further in. Copper against
silicon across forty millimetres over a sixty kelvin swing is thirty-three
microns of relative motion, at twenty-four interfaces. A composite at
eighty-five per cent molybdenum sits near seven parts per million per kelvin
instead of sixteen and a half, cutting that to about eleven, and costs
conductivity — a hundred and ninety watts per metre per kelvin against four
hundred.

**The core's heat load is a tenth of the faces', so it can afford the loss where
the faces could not.** That asymmetry is why the two use different materials, and
saying so here is what stops somebody unifying them.

## Vertical connectivity, which is the hard part

Every face must reach every tier. Four faces look at the stack's sides, where
every tier's edge is exposed. Two look at its ends, where only the outermost tier
is.

So the stack is threaded by **through-stack vias** running the full forty
millimetres — and a via forty millimetres long is not a via, it is a transmission
line, with real capacitance and a delay that is not negligible at the core clock.

`009` entry M5 asks whether the end faces should instead reach deep tiers by a
redistribution route around the outside of the stack. **This blueprint takes the
through-stack answer** and prices it, because the alternative adds a route whose
length differs per tier and would make the end faces' timing depend on which tier
they are talking to — which `037` cannot absorb and `034`'s single-face-takes-all
requirement will not tolerate.

## Symbols

```symbols
n_tier        | 1  | given | 24     | memory tiers in the stack. Twenty-four rather than the thirty-two first sketched, because at the density 035 derives, thirty-two holds half again what is needed
f_si_volume   | 1  | derived | t_tier_si / t_tier_pitch | share of the core's volume that is silicon rather than heat exchanger
h_stack       | mm | derived | n_tier * t_tier_pitch    | height of the stack, which must be the cavity's core dimension
p_tsv         | um | given | 18.0    | pitch of the through-stack via array
d_tsv         | um | given | 7.0     | diameter of one through-stack via. Three microns was tried, then five: a forty millimetre column is a resistance and a capacitance in series, its time constant goes as the reciprocal of the via's area, and five microns settled in two hundred and eleven picoseconds against a two hundred picosecond budget. Seven gives a hundred and eight
n_tsv_col     | 1  | derived | floor(L_core / p_tsv) | via columns across one edge of a tier
n_tsv         | 1  | derived | n_tsv_col^2               | through-stack vias in the whole array
f_tsv_area    | 1  | derived | n_tsv * pi * (d_tsv/2)^2 / A_core_side | share of a tier's area the via array occupies, which is part of what 035's tier overhead pays for
C_tsv         | F  | derived | 2 * pi * eps_0 * eps_ox * L_core / ln(3) | capacitance of one through-stack via against its oxide liner, taking the shield spacing as three times the via radius
R_tsv         | ohm| derived | res_cu * L_core / (pi * (d_tsv/2)^2) | resistance of the same. Copper rather than tungsten: tungsten is three times the resistivity and over forty millimetres that is the difference between settling inside a core cycle and not
t_tsv_delay   | s  | derived | 0.69 * R_tsv * C_tsv       | the time constant of a via running the whole height of the stack, which is what decides whether the end faces can be treated like the side faces
R_tsv_w       | ohm | derived | res_w * L_core / (pi * (d_tsv/2)^2) | what the same via would be in tungsten, which is the process's more usual choice for a via this deep
t_tsv_delay_w | s  | derived | 0.69 * R_tsv_w * C_tsv     | and what it would settle in. The rejected alternative, costed rather than dismissed: the sentence above says tungsten is three times the resistivity and over forty millimetres that is the difference between settling inside a core cycle and not, and this is that sentence as a number

P_tier        | W  | derived | P_core / n_tier            | heat one tier makes
w_lam_chan    | mm | given | 0.30     | width of a channel in a cooling lamina; wider than a face's because the heat here is a tenth as dense
h_lam_chan    | mm | given | 0.30      | depth of the same. Half the lamina's thickness was tried first and made the core a quarter void, which is far more cooling than seven watts a tier needs and put nearly forty cubic centimetres of fluid inside the machine. The lamina is thick because the stack height demanded it, not because the heat did
f_void_lam    | 1  | derived | (w_lam_chan / (2 * w_lam_chan)) * (h_lam_chan / t_lamina) | share of a lamina that is channel rather than metal, from the channel geometry rather than assumed
n_lam_chan    | 1  | derived | floor(L_core / (w_lam_chan * 2)) | channels across one lamina, on a pitch of twice their width
Q_lamina      | m^3/s | derived | Q_core / n_tier          | flow through one lamina
A_wet_lam     | mm^2 | derived | n_lam_chan * 2 * (w_lam_chan + h_lam_chan) * L_core | wetted area of one lamina
dT_core       | K  | derived | P_tier / (h_conv_lam * A_wet_lam) | temperature a tier sits above its coolant *film*. Two hand-written conversions -- millimetres to metres in the coefficient and square millimetres to square metres here -- between them made this term a thousand times too large, which is what a checker is for
R_tier_si     | K/W | derived | t_tier_si / (2 * k_si * A_core_side) | getting out of the silicon: half a tier's thickness, because a tier is cooled from both faces and each half sends its heat the shorter way
R_lam_metal   | K/W | derived | t_lamina / (2 * k_cumo * A_core_side * (1 - f_void_lam)) | and then through half a lamina's metal to reach a channel wall, across whatever cross-section the channels have not removed
dT_tier_cond  | K  | derived | P_tier * (R_tier_si + R_lam_metal)  | how much of the tier's rise is conduction rather than convection. This term was missing entirely until the copper-molybdenum's own conductivity was noticed sitting in 011 with nothing reading it -- a material chosen for its thermal conductivity, in a design that never used the number
dT_tier_total | K  | derived | dT_core + dT_tier_cond               | the whole rise from a bitcell to the coolant that carries its heat away. This is what has to fit the budget, and the film alone was what was being checked
h_conv_lam    | W/(m^2*K) | derived | 4.0 * k_fluid / (2 * w_lam_chan * h_lam_chan / (w_lam_chan + h_lam_chan)) | convection coefficient in a lamina channel, at the laminar Nusselt number for a duct of about this shape
Q_core        | m^3/s | derived | Q_total * P_core / P_heat | the core's share of the machine's flow, in proportion to its share of the heat
disp_tier_lam | mm | derived | (cte_cumo - cte_si) * dT_power * L_core | relative motion at one tier-to-lamina interface over a power cycle
```

## Constraints

```constraints
C-036-1 | h_stack ~= L_core             | the tier count times the pitch must equal the core's edge as the cube's own geometry produces it. The two-chain check, from the other side, and the partner of C-012-9
C-036-2 | t_tsv_delay < t_cycle_core / 4 | a via running the whole height of the stack must settle in well under a core cycle, or the two end faces cannot be treated like the four side faces and 034's single-face-takes-all requirement fails for two of the six
C-036-3 | f_tsv_area < 0.15             | the via array must not take a sixth of a tier's area, since 035's tier overhead has other things to pay for
C-036-4 | dT_tier_total < dT_conv_max   | a tier must sit no further above its coolant than a face does, which is easy here because the heat is a tenth as dense and is asserted so that a change to the lamina thickness is noticed. It compares the whole rise and not just the film; comparing the film alone was leaving out the metal the lamina is made of
C-036-9 | dT_tier_cond > 0              | the conduction term must be a real number and not a rounding of zero. Asserted in the direction of alarm: it comes out at about a fiftieth of a kelvin against a quarter of a kelvin of film, so the film is what governs -- and knowing that by measurement rather than by assumption is the difference between a budget and a hope
C-036-10 | dT_tier_cond < dT_core      | conduction must stay under convection, which is what says the film is the term that governs. Asserted rather than assumed because the first attempt asserted the opposite -- that the lamina would be a better path than the silicon it cools, on the grounds that copper-molybdenum conducts almost twice as well. It is twenty times worse, because it is thirty times thicker: the lamina is thick because the stack height demanded it and not because the heat did, and that trade is charged here in a fiftieth of a kelvin
C-036-5 | disp_tier_lam < disp_cu_alt   | the composite must move less at a tier interface than copper would, which is the only reason to accept its conductivity
C-036-6 | Q_core + Q_total * (1 - P_core / P_heat) ~= Q_total | the core's flow plus everything else's is the machine's flow. Trivial arithmetic, and it is here because 024's network omitted the core entirely and this is what notices
C-036-7 | f_si_volume < 0.05            | under a twentieth of the core is silicon. Asserted because it is the surprising fact about this part and a reader who has not internalised it will size something wrongly
C-036-11 | t_tsv_delay_w > t_cycle_core / 4 | tungsten must actually fail the test copper passes, or the reason given for choosing copper is not a reason. This is a rejected alternative asserted in the direction of alarm: if a process change ever made tungsten fast enough, this constraint fails and somebody is told that the argument in this blueprint has expired
```

## What is still open

**`009` entry M5 is decided here and not closed.** Through-stack vias are chosen
over an outside route on the grounds that a route whose length varies per tier
would make the end faces' timing depend on which tier they address. The
alternative was never costed, and if `C-036-2` turns out to fail the outside
route is what is left.

**The lamina's flow does not appear in `024`'s network** except through the
constraint above. The core's coolant enters and leaves through the cage, and the
cage's plumbing has not been drawn at all.

**Bonding twenty-four tiers is twenty-four chances to lose a stack.** `083` is
where that lands, and this blueprint's contribution to it — the per-interface
bond area and the alignment each one needs — is not written.
