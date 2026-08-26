# 021 — The working fluid

```meta
phase  | 3
issues | 302
```

## A word first, because it has caused confusion

**Coolant is a role, not a substance.** It is whatever is pumped through the
corners. Water is a coolant. A fluorocarbon is a coolant. The question this
blueprint answers is not *water or coolant* — it is **water, or a liquid that
does not conduct electricity**, and the only reason anybody would choose the
worse thermal performer is that this machine has its fluid a hundred and fifty
microns from silicon at three quarters of a volt.

## The two candidates

**Water.** Nothing liquid in this temperature range is close: four times the heat
capacity of a fluorocarbon and ten times the conductivity. It is also an
electrolyte, and `017` counts a hundred and sixty-six joints between it and the
electronics.

**A perfluorinated liquid.** Dielectric. A leak is a mess rather than a death.
Costs roughly a factor of ten on the convection coefficient, which turns out to
be affordable and is the finding of this blueprint.

## How the choice is carried

The fluid is a **parameter**, not an assumption. A single switch selects between
the two property sets, and every downstream number — the convection coefficient
in `022`, the pressure drop in `024`, the junction temperature in `025` — reads
the selected values rather than water's.

The mechanism is a blend rather than a branch, because the notation has no
conditionals and does not need one: with the switch at one the water properties
survive and the fluorocarbon's vanish, and at zero the reverse. Setting it to a
half would produce nonsense, and `C-021-1` refuses that.

## What the substitution costs

Every number moves and the blueprint publishes the whole set rather than a
headline. The important one is that **the design survives it**: junction
temperature rises by about eleven kelvin against sixty of margin, and the
pumping power goes from a rounding error to something visible in the budget.

That finding is only available because there is margin. A tighter design would
not have the choice, and the fact that this one does is worth more than either
answer.

So the decision is **not thermal**. It is a judgement about what happens when a
seal in `017` fails, and it belongs to whoever owns the failure consequences
rather than to whoever owns the temperatures.

## What else the fluid has to be

Compatible with silicon, copper-molybdenum, stainless and the elastomer in `017`,
over a hundred thousand thermal cycles. **Non-fouling at a hundred and fifty
microns** — the channel is narrow enough that ordinary tap-water scaling would
close it, so water here means treated water with a specified conductivity and
particle count, and that specification is `027`'s.

Freezing decided something. A cube shipped in winter with water in it is a cube
with a cracked channel plate, and the constraint below says so plainly: water
against a transit minimum of minus twenty degrees fails outright.

The options were an antifreeze additive, which costs about fifteen per cent of
the thermal performance and changes every property in `011`, or **shipping the
cube empty**. It ships empty. That puts a filling and purging step into `082` and
into `085`'s bring-up, and it means a cube that arrives is not a cube that can be
switched on — which is worth knowing before somebody plans an installation.

## Symbols

```symbols
fluid_is_water | 1 | given | 1.0 | the selection switch: one for water, zero for the dielectric. Nothing between the two means anything

# the selected fluid's properties, as a blend that is a choice because the switch
# is only ever one or zero
rho_fluid  | kg/m^3   | derived | fluid_is_water * rho_water + (1 - fluid_is_water) * rho_fluoro | density of whichever fluid is selected
cp_fluid   | J/(kg*K) | derived | fluid_is_water * cp_water  + (1 - fluid_is_water) * cp_fluoro  | specific heat capacity of the same
k_fluid    | W/(m*K)  | derived | fluid_is_water * k_water   + (1 - fluid_is_water) * k_fluoro   | thermal conductivity of the same
mu_fluid   | Pa*s     | derived | fluid_is_water * mu_water  + (1 - fluid_is_water) * mu_fluoro  | dynamic viscosity of the same
T_frz_fluid| K        | derived | fluid_is_water * T_water_frz + (1 - fluid_is_water) * T_fluoro_frz | freezing point of the same
T_fluid_min| K        | derived | ships_dry * T_serv_min + (1 - ships_dry) * T_ship_min | the coldest the fluid itself ever gets: the service minimum if the cube travels empty, and the transit minimum if it does not
Pr_fluid   | 1        | derived | mu_fluid * cp_fluid / k_fluid | Prandtl number of the selected fluid

dT_rise      | K   | given | 7.8   | design temperature rise of the coolant across the cube; a choice, and the one that sets the flow
T_coolant_in | K   | given | 298.0 | temperature the coolant enters at. This is the parameter that decides whether the loop in 027 needs a refrigeration plant or a radiator and a fan
v_erosion_max| m/s | measured | 4.0 | velocity above which flow erosion of the wetted materials shortens the life in 086
T_ship_min   | K   | given | 253.0 | lowest temperature a cube may see in transit
T_serv_min   | K   | given | 288.0 | lowest temperature a cube sees once installed and filled
ships_dry    | 1   | given | 1.0   | whether a cube travels with its coolant removed. One means it does, and 082 has to say so in the procedure

# what the choice costs, both ways, so the comparison is derived rather than quoted
mdot_water  | kg/s | derived | P_heat / (cp_water * dT_rise)   | mass flow water would need for this heat at this rise
mdot_fluoro | kg/s | derived | P_heat / (cp_fluoro * dT_rise)  | and what the dielectric would need
Q_water     | m^3/s| derived | mdot_water / rho_water          | volumetric flow of water
Q_fluoro    | m^3/s| derived | mdot_fluoro / rho_fluoro        | and of the dielectric
flow_penalty| 1    | derived | Q_fluoro / Q_water              | how much more of the dielectric has to be moved, which is the headline cost of the substitution
k_penalty   | 1    | derived | k_water / k_fluoro              | how much worse its conduction is, which sets the convection coefficient in 022
mdot_design | kg/s | derived | P_heat / (cp_fluid * dT_rise)   | mass flow the selected fluid actually needs
```

## Constraints

```constraints
C-021-1 | fluid_is_water * (1 - fluid_is_water) == 0 | the switch must be exactly one or exactly zero. Any value between produces a blend of two fluids' properties that describes nothing that exists, and this is the constraint that stops somebody setting it to a half and getting an answer
C-021-2 | Pr_fluid > 1.0                    | any liquid coolant worth using carries momentum out further than it carries heat. A Prandtl number below one would mean the properties selected are a gas
C-021-3 | T_frz_fluid < T_fluid_min         | the selected fluid must not freeze anywhere it ever finds itself. Water against a transit minimum of minus twenty fails outright, which is why the cube ships dry -- and expressing it this way means that setting ships_dry to zero fails the check rather than silently cracking a channel plate
C-021-7 | ships_dry * (1 - ships_dry) == 0  | a cube either travels with fluid in it or without; there is no half
C-021-4 | flow_penalty > 1.0                | the dielectric needs more flow than water, which is the whole shape of the trade and is asserted so that a properties edit that reversed it would be caught
C-021-5 | dT_rise > 0                       | the coolant leaves warmer than it arrives
C-021-6 | dT_rise < T_si_max - T_coolant_in | the coolant's own rise must be a small part of the budget between the inlet and what the silicon tolerates, or nothing is left for the convection and spreading terms in 025
```

## What is still open

**The decision itself.** `009` entry B2. This blueprint makes it cheap to change
and does not make it. Water is selected because it is better and the design has
the margin to be wrong about it; whether that is the right call depends on what
a leak costs in the deployment, which is not a thermal question.

**Erosion velocity is a single number for four wetted materials.** Stainless,
copper-molybdenum, silicon and an elastomer do not erode at the same rate, and
four metres a second is a figure for the metal. The silicon microchannels run at
under half a metre a second so it does not bind there, but the rails run at over
two and it is the rails that are steel.

**Nothing has been said about what happens to water at a hundred and fifty
microns over ten years.** Fouling, corrosion products and biological growth all
have length scales comparable to the channel. `027` specifies a filter and a
conductivity; neither is derived from a fouling model, because there is none.
