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

P_tier        | W  | derived | P_core / n_tier            | heat one tier makes
w_lam_chan    | mm | given | 0.30     | width of a channel in a cooling lamina; wider than a face's because the heat here is a tenth as dense
h_lam_chan    | mm | given | 0.30      | depth of the same. Half the lamina's thickness was tried first and made the core a quarter void, which is far more cooling than seven watts a tier needs and put nearly forty cubic centimetres of fluid inside the machine. The lamina is thick because the stack height demanded it, not because the heat did
f_void_lam    | 1  | derived | (w_lam_chan / (2 * w_lam_chan)) * (h_lam_chan / t_lamina) | share of a lamina that is channel rather than metal, from the channel geometry rather than assumed
n_lam_chan    | 1  | derived | floor(L_core / (w_lam_chan * 2)) | channels across one lamina, on a pitch of twice their width
Q_lamina      | m^3/s | derived | Q_core / n_tier          | flow through one lamina
A_wet_lam     | mm^2 | derived | n_lam_chan * 2 * (w_lam_chan + h_lam_chan) * L_core | wetted area of one lamina
dT_core       | K  | derived | P_tier / (h_conv_lam * A_wet_lam) | temperature a tier sits above its coolant. Two hand-written conversions -- millimetres to metres in the coefficient and square millimetres to square metres here -- between them made this term a thousand times too large, which is what a checker is for
h_conv_lam    | W/(m^2*K) | derived | 4.0 * k_fluid / (2 * w_lam_chan * h_lam_chan / (w_lam_chan + h_lam_chan)) | convection coefficient in a lamina channel, at the laminar Nusselt number for a duct of about this shape
Q_core        | m^3/s | derived | Q_total * P_core / P_heat | the core's share of the machine's flow, in proportion to its share of the heat
disp_tier_lam | mm | derived | (cte_cumo - cte_si) * dT_power * L_core | relative motion at one tier-to-lamina interface over a power cycle
```

## Constraints

```constraints
C-036-1 | h_stack ~= L_core             | the tier count times the pitch must equal the core's edge as the cube's own geometry produces it. The two-chain check, from the other side, and the partner of C-012-9
C-036-2 | t_tsv_delay < t_cycle_core / 4 | a via running the whole height of the stack must settle in well under a core cycle, or the two end faces cannot be treated like the four side faces and 034's single-face-takes-all requirement fails for two of the six
C-036-3 | f_tsv_area < 0.15             | the via array must not take a sixth of a tier's area, since 035's tier overhead has other things to pay for
C-036-4 | dT_core < dT_conv_max         | a tier must sit no further above its coolant than a face does, which is easy here because the heat is a tenth as dense and is asserted so that a change to the lamina thickness is noticed
C-036-5 | disp_tier_lam < disp_cu_alt   | the composite must move less at a tier interface than copper would, which is the only reason to accept its conductivity
C-036-6 | Q_core + Q_total * (1 - P_core / P_heat) ~= Q_total | the core's flow plus everything else's is the machine's flow. Trivial arithmetic, and it is here because 024's network omitted the core entirely and this is what notices
C-036-7 | f_si_volume < 0.05            | under a twentieth of the core is silicon. Asserted because it is the surprising fact about this part and a reader who has not internalised it will size something wrongly
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
