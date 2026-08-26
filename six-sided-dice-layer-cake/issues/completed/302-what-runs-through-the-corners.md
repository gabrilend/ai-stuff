# 302 — What runs through the corners

Produces `src/021-working-fluid.md`.

## Current behavior

**Done.** `src/021-working-fluid.md` exists and opens by fixing the word:
coolant is a role, not a substance, and the question is water against a liquid
that does not conduct rather than water against coolant.

**The fluid is a parameter.** A switch selects between the two property sets and
every downstream number reads the selection. The mechanism is a linear blend
rather than a branch, because the notation has no conditionals and does not need
one -- and a constraint refuses any value between zero and one, since a half
would produce a blend of two fluids that describes nothing.

The finding is that **the design survives the substitution**: junction
temperature rises about eleven kelvin against forty of margin, and pumping power
goes from a rounding error to something visible. That is only available because
there is margin, and it means the choice is a reliability judgement rather than a
thermal one.

**Water freezing decided something.** A cube may see minus twenty in transit and
water freezes at zero, so the constraint failed outright. The cube ships dry,
which puts a fill and purge into `082` and `085`.

## Intended behavior

**The fluid selection, written so the fluid is a parameter rather than an
assumption.** Two candidates carried in full, with every downstream number derived
from whichever is selected, so that changing the choice is one edit and a rerun
rather than a redesign.

### The two

**Water.** Specific heat four thousand one hundred and eighty joules per kilogram
per kelvin, conductivity six tenths of a watt per metre per kelvin. Nothing liquid
in this temperature range is close. It is also an electrolyte, and the
microchannels run a hundred and fifty microns from silicon at three quarters of a
volt through walls a hundred and fifty microns thick.

**A fluorocarbon.** Roughly a quarter the heat capacity, a tenth the conductivity,
about twice the density and four times the viscosity. Dielectric: a leak is a mess
rather than a short.

### What the substitution costs

Every thermal number in the project moves, and the blueprint should present the
whole set rather than a headline:

| | water | fluorocarbon |
|---|---|---|
| flow for the same temperature rise | 3.5 L/min | ~13 L/min |
| convection coefficient | ~11,900 W/m²K | ~2,000 W/m²K |
| convection temperature rise | 1.8 K | ~11 K |
| pumping power | ~8 W | ~90 W |
| junction temperature | ~46 °C | ~57 °C |

**The design survives the substitution.** Junction temperature goes from
forty-six to about fifty-seven against a limit of a hundred and five, and the
pumping power goes from a rounding error to something visible in the budget. That
is the useful finding, and it is only available because there is sixty kelvin of
margin — a tighter design would not have the choice.

So the decision is not thermal. It is a reliability judgement about what happens
when a seal in `205` fails, and it belongs to whoever owns the failure
consequences rather than to whoever owns the temperatures. The blueprint should
say that in those words.

### What else the fluid has to be

Compatible with silicon, copper-molybdenum, stainless and the elastomer in `205`,
over a hundred thousand thermal cycles. Non-fouling at a hundred and fifty
microns — the channel is narrow enough that ordinary tap-water scaling would close
it, so water means treated water with a specified conductivity and a specified
particle count, and that specification belongs in `308` rather than being assumed.

Freezing matters: a cube shipped in winter with water in it is a cube with a
cracked channel plate. Either it ships dry, or the fluid has an additive, and
either way it is a line in `1202`.

## Symbols this must publish

Every fluid property at the operating temperature, for both candidates, as
`measured` with sources: density, specific heat, conductivity, viscosity, Prandtl
number, freezing point, and electrical conductivity. A selection switch that the
rest of the project reads.

## Constraints this must assert

- The Prandtl number computed from the three published properties matches the
  published Prandtl number. Three numbers checked against a fourth catches a
  transcription error in any of them.
- The selected fluid's freezing point is below the shipping temperature in `1202`,
  or the shipping procedure says the cube travels dry.
- Channel width from `012` exceeds the maximum particle size the filtration in
  `308` permits, by a stated factor.

## Suggested implementation steps

1. Enter both fluids' properties at the operating temperature.
2. Add the Prandtl cross-check.
3. Build the comparison table by deriving each row from the properties, not by
   quoting the numbers above.
4. Write the paragraph that hands the decision to the reliability owner.
5. Make the selection a symbol so `022`, `024` and `025` read it rather than
   assuming water.

## Blocks

`303`, `305`, `306`, `308`.

## Blocked by

`102`, `301`.

## Related documents

`005`. `009` entry B2, which this ticket is the answer to and does not close —
closing it requires a person.
