# 102 — What it is made of

Produces `src/011-material-properties.md`.

## Current behavior

**Done.** `src/011-material-properties.md` exists with forty-five entries across
eleven materials, every one `measured` and every meaning field naming a
temperature.

Copper is split three ways -- bulk, plated and thin film -- with a note about
where each applies. Silicon's conductivity is carried at 350 K rather than at
room temperature, which is about twelve per cent lower and is the value the hot
spot calculation actually needs.

Twelve constraints, all holding. The valuable four are the Prandtl checks: three
transcribed properties of each fluid are combined into a fourth quantity that is
independently known, so a typing error in any of the three fails rather than
propagating. Water comes out at 3.83, which is where it should be.

**Two things the ticket asked for are not there.** There is no blank-value
mechanism, because no property turned out to be inapplicable in a way that
mattered; a material that lacks a property simply has no entry. And nothing here
has a tolerance -- carried as `009` entry X2, which is a change to the notation
rather than to this file.

## Intended behavior

**One table, one file, every material property the project uses.** Eleven
materials, seven properties, each entry a `measured` symbol whose meaning field
names the source it came from.

The reason this is a blueprint of its own rather than a paragraph in each place
the numbers are needed: a project with copper's conductivity written down in four
places has three chances to be out of date, and the one that is wrong will be the
one somebody builds from.

## The materials

| material | where it appears |
|---|---|
| silicon | compute dies, memory tiers, interposers |
| copper | cooling laminae, microchannel plates, power planes, bonds |
| tungsten | through-silicon vias |
| the interposer dielectric | between the planes of a face interposer |
| die-attach bond | copper-to-copper hybrid bond at the tier interfaces |
| solder, the port field alloy | outward connectors |
| the seal polymer | edge seals between face assemblies |
| water | the working fluid, as selected in `021` |
| the alternate fluid | a fluorocarbon, carried because of open question B2 |
| aluminium nitride | the structural posts in the cavity |
| stainless steel | the mount frame and the external loop wetted parts |

## The properties

Thermal conductivity, density, specific heat capacity, coefficient of thermal
expansion, Young's modulus, electrical resistivity, relative permittivity. Not
every material needs every one; a blank is written as such rather than as zero,
and `095` must treat a referenced blank as an error rather than as a number.

## What makes this hard to get right

**Silicon's conductivity is not one number.** It falls by about a third between
room temperature and a hundred degrees, and the hot spot calculation in `025`
happens at the hot end. The table must carry the value at the operating
temperature, and say so, rather than the textbook room-temperature figure that is
twelve per cent optimistic.

**Copper's conductivity depends on how it was made.** Bulk annealed copper is four
hundred watts per metre per kelvin. Electroplated copper in a via is nearer three
hundred and fifty, and thin films worse again because the grain size approaches
the electron mean free path. Three entries, not one, and the blueprint must say
which is used where.

**Thermal expansion is the whole of `018`.** Silicon expands at about two and a
half parts per million per kelvin and copper at about seventeen. That factor of
seven, across a fifty kelvin swing and a fifty-two millimetre part, is forty
microns of differential motion, and the bonds have to survive it a hundred
thousand times. These two numbers are the most consequential in the table.

## Symbols this must publish

One per material per applicable property, named by the convention in `002`:
`k_si`, `k_cu_bulk`, `k_cu_plated`, `rho_si`, `cte_si`, `cte_cu`, `E_si`, `E_cu`,
`cp_water`, `k_water`, `mu_water`, `rho_water`, and so on. Roughly sixty symbols.

Water's properties must be at the operating temperature, not at twenty degrees.
Viscosity in particular falls by a third between twenty-five and forty-five, which
moves both the Reynolds number and the pressure drop in `024`.

## Constraints this must assert

Very few, because a material property table mostly states rather than checks. The
ones worth having are sanity bounds that catch a typo or a units slip:

- Every conductivity is positive and below that of diamond.
- Water's Prandtl number, computed from the three properties given, lands between
  three and seven at the stated temperature. This is the valuable one: it is three
  independent measured numbers checked against a fourth relationship, so a
  transcription error in any of them is caught.
- Silicon's expansion coefficient is smaller than copper's, which is the fact
  `018` exists because of.

## Suggested implementation steps

1. List the eleven materials and where each appears, so nothing is in the table
   that nothing uses and nothing is used that is not in the table.
2. Enter the properties, each with its source and its temperature in the meaning
   field. A property without a temperature is not a property.
3. Split copper three ways and say where each applies.
4. Add the Prandtl cross-check.
5. Run `095` and confirm that no blueprint references a blank.

## Blocks

`103`, and every thermal, mechanical and electrical calculation in the project.

## Blocked by

`101` for the notation to be exercised; `1401` for the units engine, since this
file is the first real test of whether the dimension checking works.

## Related documents

`005` uses most of the thermal entries. `018` uses the expansion pair. `021` is
where the fluid choice is argued and is the reason two fluids appear here.
