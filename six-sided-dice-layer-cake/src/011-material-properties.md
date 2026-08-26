# 011 — Material properties

```meta
phase  | 1
issues | 102
```

Every material property this project uses, in one file, because a project with
copper's conductivity written down in four places has three chances to be out of
date and the one that is wrong will be the one somebody builds from.

Every entry is `measured`, and every meaning field names where it came from and
**at what temperature**, because a property without a temperature is not a
property.

## What is made of what

| material | where it appears |
|---|---|
| silicon | compute dies, memory tiers, interposer cores, the face cold plates |
| copper | power planes, bonds, interposer wiring |
| copper–molybdenum | the thirty-two cooling laminae inside the core |
| tungsten | through-silicon vias |
| glass | the face interposer core |
| water | the working fluid, selected in `021` |
| a fluorocarbon | the dielectric alternative, carried because `009` entry B2 is open |
| stainless steel | edge rails, corner blocks, the mount frame, the wetted loop |
| an elastomer | the compression seals in `017` |

## The three coppers

Copper is not one number. Bulk annealed copper conducts at nearly four hundred
watts per metre per kelvin; copper electroplated into a via is nearer three
hundred and fifty because its grains are smaller; a thin film is worse again
because the grain size approaches the distance an electron travels between
collisions. Three entries, and each place that uses one must say which.

## Silicon at temperature

Silicon's thermal conductivity falls by about a third between room temperature
and a hundred degrees. The hot spot calculation in `025` happens at the hot end,
so the value carried here is the one at the operating temperature and not the
textbook figure, which would be about twelve per cent optimistic exactly where
the design has least margin.

## The pair that shapes the machine

Silicon expands at about two and a half parts per million per kelvin and copper
at about sixteen and a half. That ratio, across a fifty-two millimetre part and a
sixty kelvin swing, is forty microns of differential motion at a bond ten
microns thick — which is why the face cold plates are silicon (`014`) and the
core's laminae are a molybdenum composite (`036`). **These two numbers are the
most consequential in the table** and everything in `018` is downstream of them.

## Symbols

```symbols
# --- silicon -------------------------------------------------------------
k_si          | W/(m*K)   | measured | 110      | thermal conductivity of silicon at 350 K, a third below the room-temperature figure
rho_si        | kg/m^3    | measured | 2329     | density of silicon at 300 K
cp_si         | J/(kg*K)  | measured | 705      | specific heat capacity of silicon at 300 K
cte_si        | ppm/K     | measured | 2.6      | linear thermal expansion of silicon, 300 K to 400 K
E_si          | GPa       | measured | 130      | Young's modulus of silicon, averaged over orientation
sigma_si_frac | MPa       | measured | 150      | fracture stress of thinned silicon with an ordinary sawn or laser-diced edge, where microcracks from the cut are what fail
sigma_si_plas | MPa       | measured | 350      | the same for a plasma-diced edge, which etches rather than cuts and leaves no crack population; 018 requires this and it is a process requirement rather than a preference
T_si_max      | K         | measured | 378      | highest junction temperature the silicon is qualified to, 105 degrees

# --- copper, in its three forms ------------------------------------------
k_cu_bulk     | W/(m*K)   | measured | 398      | thermal conductivity of bulk annealed copper at 350 K
k_cu_plated   | W/(m*K)   | measured | 350      | the same for electroplated copper in a via, where the grains are smaller
k_cu_film     | W/(m*K)   | measured | 260      | the same for a thin film, where grain size approaches the electron mean free path
rho_cu        | kg/m^3    | measured | 8960     | density of copper
cp_cu         | J/(kg*K)  | measured | 385      | specific heat capacity of copper
cte_cu        | ppm/K     | measured | 16.5     | linear thermal expansion of copper, 300 K to 400 K
E_cu          | GPa       | measured | 117      | Young's modulus of copper
res_cu        | ohm*m     | measured | 1.9e-8   | electrical resistivity of copper at 350 K
j_em_cu       | mA/um^2   | measured | 1.0      | electromigration current density limit for copper at 350 K over a ten year life

# --- copper-molybdenum, the core's cooling laminae -----------------------
k_cumo        | W/(m*K)   | measured | 190      | thermal conductivity of a fifteen per cent copper, eighty-five per cent molybdenum composite
rho_cumo      | kg/m^3    | measured | 10000    | density of the same
cp_cumo       | J/(kg*K)  | measured | 250      | specific heat capacity of the same
cte_cumo      | ppm/K     | measured | 7.0      | linear thermal expansion of the same; chosen for this number and no other
E_cumo        | GPa       | measured | 280      | Young's modulus of the same

# --- the rest of the solid parts -----------------------------------------
k_w           | W/(m*K)   | measured | 174      | thermal conductivity of tungsten, for the through-silicon vias
res_w         | ohm*m     | measured | 5.6e-8   | electrical resistivity of tungsten at 350 K
cte_glass     | ppm/K     | measured | 3.2      | linear thermal expansion of the interposer's glass core, chosen to sit near silicon
k_glass       | W/(m*K)   | measured | 1.1      | thermal conductivity of the same, which is poor and does not matter because heat leaves the other way
rho_ss        | kg/m^3    | measured | 7900     | density of stainless steel
k_ss          | W/(m*K)   | measured | 16       | thermal conductivity of stainless steel
cte_ss        | ppm/K     | measured | 17.3     | linear thermal expansion of stainless steel
E_ss          | GPa       | measured | 193      | Young's modulus of stainless steel
sigma_ss_y    | MPa       | measured | 290      | yield stress of annealed stainless steel

# --- water, at the temperature it actually runs at ------------------------
rho_water     | kg/m^3    | measured | 989      | density of water at 320 K, the mean coolant temperature
cp_water      | J/(kg*K)  | measured | 4180     | specific heat capacity of water at 320 K
k_water       | W/(m*K)   | measured | 0.63     | thermal conductivity of water at 320 K
mu_water      | Pa*s      | measured | 5.77e-4  | dynamic viscosity of water at 320 K, a third below its value at 293 K
T_water_frz   | K         | measured | 273      | freezing point of untreated water, which is why 1202 says how a cube travels

# --- the dielectric alternative, carried while B2 is open -----------------
rho_fluoro    | kg/m^3    | measured | 1600     | density of a perfluorinated coolant at 320 K
cp_fluoro     | J/(kg*K)  | measured | 1100     | specific heat capacity of the same
k_fluoro      | W/(m*K)   | measured | 0.065    | thermal conductivity of the same, a tenth of water's
mu_fluoro     | Pa*s      | measured | 1.20e-3  | dynamic viscosity of the same
T_fluoro_frz  | K         | measured | 195      | freezing point of the same, which is the one property where it beats water

# --- a bound, so that a transcription error has something to fail against -
eps_0         | F/m       | measured | 8.854e-12 | permittivity of free space. It is here rather than written into a derivation because every literal in this notation is dimensionless, so a physical constant has to be a symbol like any other quantity
eps_ox        | 1         | measured | 3.9      | relative permittivity of the oxide liner around a through-silicon via
k_diamond     | W/(m*K)   | measured | 2000     | thermal conductivity of diamond; nothing here is made of it, and it is the ceiling any other conductivity must sit under

# --- derived cross-checks -------------------------------------------------
Pr_water      | 1         | derived  | mu_water * cp_water / k_water   | Prandtl number of water at 320 K, computed from the three properties above
Pr_fluoro     | 1         | derived  | mu_fluoro * cp_fluoro / k_fluoro | Prandtl number of the fluorocarbon at 320 K
cte_ratio     | 1         | derived  | cte_cu / cte_si                 | how much faster copper expands than silicon; the number 018 exists because of
cte_ratio_mo  | 1         | derived  | cte_cumo / cte_si               | the same for the molybdenum composite, which is why the core uses it
```

## Constraints

The Prandtl checks are the valuable ones and it is worth saying why. Viscosity,
heat capacity and conductivity are three numbers transcribed from three places.
The Prandtl number is a fourth quantity that relates them, and it is well known
for both fluids. Computing it from the three and comparing against the fourth
catches a transcription error in **any** of them, which no amount of care while
typing does.

```constraints
C-011-1 | Pr_water >= 3.0        | water's Prandtl number at this temperature is near four; a value outside three to seven means one of the three properties it is computed from was transcribed wrongly
C-011-2 | Pr_water <= 7.0        | the same bound from above
C-011-3 | Pr_fluoro >= 10.0      | the fluorocarbon's Prandtl number is near twenty; the same three-into-one check for the alternative fluid
C-011-4 | Pr_fluoro <= 40.0      | the same bound from above
C-011-5 | cte_si < cte_cu        | silicon expands less than copper, which is the fact the whole of 018 is about
C-011-6 | cte_cumo < cte_cu      | the molybdenum composite expands less than copper, which is the only reason to use it
C-011-7 | cte_cumo > cte_si      | and more than silicon, so the mismatch is reduced rather than reversed
C-011-8 | k_cu_bulk < k_diamond  | a sanity ceiling; a conductivity above diamond's is a units slip
C-011-9 | k_si < k_diamond       | the same
C-011-10 | k_cu_plated < k_cu_bulk | plated copper conducts worse than bulk, not better
C-011-11 | k_cu_film < k_cu_plated | and a thin film worse again
C-011-12 | k_fluoro < k_water    | the dielectric alternative is the worse conductor, which is the whole of the trade in 021
C-011-13 | sigma_si_plas > sigma_si_frac | a plasma-diced edge is stronger than a sawn one, by the factor 018's margin depends on
```

## What is still open

**Nothing here has a tolerance.** Every entry is a point value and a materials
engineer will ask for the spread on at least half of them. `009` entry X2 carries
it as a change to the notation rather than to this file, because a tolerance
column that nothing propagates would be decoration.

**The edge finish stopped being an open question and became a requirement.**
Both figures are here, and `018` found that the ordinary one leaves a margin of
one point four against a fracture that scraps the whole cube — so plasma dicing
is now something `1201` must specify rather than something somebody might choose.
Two entries remain because the weaker one is what the constraint is measured
against.
