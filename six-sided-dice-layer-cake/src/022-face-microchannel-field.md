# 022 — The field that does the work

```meta
phase  | 3
issues | 303
```

The microchannel field etched into the back of each face's silicon cold plate.
Everything the corners do is manifolding; **this is the heat exchanger**.

## The mechanism, so a materials engineer can check it rather than trust it

Heat crosses from a solid into a moving fluid at a rate set by the convection
coefficient, and in a duct that coefficient is

    h  =  Nu * k_fluid / D_h

where `Nu` is a dimensionless number that depends on the duct's shape and on
whether the wall is at constant temperature or constant heat flux, and `D_h` is
the hydraulic diameter.

**In laminar flow `Nu` does not depend on velocity at all.** So the only lever on
the coefficient is the hydraulic diameter, and it is a reciprocal: a channel ten
times narrower is ten times better.

That single fact is the whole argument for microchannels, and it is why the
four-millimetre corner ducts in `005` fail by two orders of magnitude while a
hundred-and-fifty-micron channel succeeds. It is also why *enlarging* the corner
ducts would have made them worse per unit area.

```drawing
three channels of the field, in section, with the die above

        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      the die, [t_die]
        ════════════════════════════════════      hybrid bond, [t_bond]
        ┌────────────────────────────────┐        plate base
        │    ┌───┐    ┌───┐    ┌───┐     │  ─┬─
        │    │   │    │   │    │   │     │   │  [h_uchan]
        │    │   │    │   │    │   │     │   │
        │    └───┘    └───┘    └───┘     │  ─┴─
        └────────────────────────────────┘        cover
             ├───┤├──┤
        [w_uchan] [w_ufin]                        pitch is [p_uchan]

        heat arrives through the base and both fin walls: three sides
```

## The three things that must be derived rather than chosen

**The Nusselt number for this actual duct.** Not five, not a textbook round
number — a polynomial in the aspect ratio, evaluated at the shape `012` specifies,
with a correction for heat arriving on three sides rather than four. It comes out
near five and a quarter, and writing it out means that changing the channel shape
changes the coefficient rather than leaving a stale constant behind.

**Fin efficiency.** The silicon between two channels is a fin, and a fin only
carries heat to its tip if it is short and conductive enough. Silicon at a
hundred and ten watts per metre per kelvin, a hundred and fifty microns thick,
one millimetre tall, comes out near sixty-eight per cent. **This term is the
entire cost of choosing silicon over copper in `014`** and it must be visible.

**The aspect ratio limit.** Deeper channels are more surface for the same
footprint — until the fin stops reaching its own tip and the extra depth is
material that does nothing. That limit is what set `h_uchan` at one millimetre,
and it is published here as a symbol so `012`'s constraint has something to check
against.

## Symbols

```symbols
alpha_uchan   | 1 | derived | w_uchan / h_uchan | aspect ratio of a channel, short side over long, which is what the Nusselt polynomial is in
Nu_4side      | 1 | derived | 8.235 * (1 - 2.0421*alpha_uchan + 3.0853*alpha_uchan^2 - 2.4765*alpha_uchan^3 + 1.0578*alpha_uchan^4 - 0.1861*alpha_uchan^5) | Nusselt number for fully developed laminar flow in a rectangular duct at constant heat flux with all four walls heated
f_3side       | 1 | given   | 0.85 | correction for heat arriving on three sides rather than four, the cover being unheated
Nu_uchan      | 1 | derived | Nu_4side * f_3side | the Nusselt number this field actually runs at
D_uchan       | mm | derived | 2 * w_uchan * h_uchan / (w_uchan + h_uchan) | hydraulic diameter of one channel
h_conv        | W/(m^2*K) | derived | Nu_uchan * k_fluid / D_uchan | convection coefficient at the channel wall

# fin efficiency, from the standard straight-fin result
m_fin         | 1/m | derived | sqrt(2 * h_conv / (k_si * w_ufin))     | fin parameter for a silicon wall of this thickness at this coefficient
mL_fin        | 1   | derived | m_fin * h_uchan                        | the dimensionless group the efficiency is a function of
eta_fin       | 1   | derived | (exp(2*mL_fin) - 1) / (mL_fin * (exp(2*mL_fin) + 1)) | efficiency of one fin, written as the hyperbolic tangent expanded, since the notation has no tanh
f_fin_area    | 1   | derived | 2 * h_uchan / (2 * h_uchan + w_uchan)  | share of the heated perimeter that is fin rather than base
eta_surface   | 1   | derived | 1 - f_fin_area * (1 - eta_fin)         | overall surface efficiency, base and fins together
ar_uchan_max  | 1   | given   | 8.0                                    | aspect ratio past which fin efficiency falls below what is worth the extra silicon; this is what set h_uchan in 012

# area, and what the via islands take out of it
per_uchan     | mm   | derived | 2 * h_uchan + w_uchan                  | heated perimeter of one channel
A_wet_chan    | mm^2 | derived | per_uchan * L_plate                    | heated area of one channel over its length
A_wet_face    | mm^2 | derived | n_uchan * A_wet_chan                   | heated area of one face's field before deration
f_island_wet  | 1    | derived | n_island * L_island * (L_island / p_uchan) * per_uchan / A_wet_face | share of the heated area the sixteen via islands interrupt
A_wet_total   | mm^2 | derived | n_face * A_wet_face * (1 - f_island_wet) | heated area of all six fields, derated
UA_face       | W/K  | derived | h_conv * A_wet_total * eta_surface / n_face | conductance of one face's field
UA_total      | W/K  | derived | h_conv * A_wet_total * eta_surface     | conductance of all six together
dT_conv       | K    | derived | P_heat / UA_total                      | the temperature the coolant sits below the channel walls

# what the corners alone would have managed, kept as the comparison that justifies all of this
A_wet_rails   | mm^2 | derived | n_edge * 2 * (w_rail_chan + h_rail_chan) * L_rail | heated area the rail channels present, if they were the cooling
h_conv_rail   | W/(m^2*K) | derived | 3.61 * k_fluid / D_rail          | convection coefficient in a rail, at the laminar Nusselt number for a duct this shape
UA_rails      | W/K  | derived | h_conv_rail * A_wet_rails              | what the corners and edges alone would remove per kelvin
gain_field    | 1    | derived | UA_total / UA_rails                    | how much better the fields are than the plumbing that feeds them
```

## Constraints

```constraints
C-022-1 | dT_conv < dT_conv_max        | the temperature drop across the channel wall must stay inside what 025's chain allots to it
C-022-2 | ar_uchan <= ar_uchan_max     | the aspect ratio limit, which is what set the channel depth in the first place
C-022-3 | eta_fin > 0.5                | a fin delivering less than half its heat to its own tip is silicon doing nothing, and the depth should come down
C-022-4 | f_island_wet < 0.10          | the feedthroughs must not interrupt a tenth of the heated area
C-022-5 | w_uchan > d_filter * 3       | a channel must be several times the largest particle the filtration in 027 lets through, or one particle closes it
C-022-6 | gain_field > 100             | the fields must be two orders of magnitude better than the bare plumbing. This is the number that justifies the whole of 014's cold plate, and asserting it means the justification is checked rather than remembered
C-022-7 | Re_uchan < 2300              | the flow must stay laminar, because every correlation above assumes it and a turbulent field would have a different coefficient and a far worse pressure drop
```

## What is still open

**The three-sided correction is a `given`.** Eighty-five per cent is the right
order and it is not derived from anything. The exact figure depends on how much
heat spreads into the cover through the fluid, which is a two-dimensional problem
this blueprint does not solve, and the whole conductance is proportional to it.

**Flow around a via island is bounded rather than computed.** The area lost is
easy arithmetic. What happens to the flow in the ten channels an island
interrupts, and in their neighbours which now see a lower resistance path, is
not — and a channel that loses flow keeps its heat.

**Nobody has asked how many channels can block.** A hundred and seventy-three
channels at a hundred and fifty microns, in a loop with a pump and a radiator.
One particle stops one channel and its neighbours take the load. `009` entry T2,
and the filter specification in `027` is currently a requirement written in the
imperative mood rather than one derived from this.
