# 503 — Thirty-two layers, and what is between them

Produces `src/036-core-tier-and-stack.md`.

## Current behavior

Nothing. The core has been described as thirty-two tiers laminated with copper
plates and the lamination has never been drawn.

## Intended behavior

**One tier in section, the repeating unit of the stack, and the vertical
connectivity that lets any face reach any tier.** This is the layer cake the
project is named after.

### The repeating unit

| element | mm | material |
|---|---|---|
| memory tier, thinned | 0.050 | silicon |
| bond | included | copper–copper hybrid |
| cooling lamina | 1.200 | copper–molybdenum, channels etched |
| | **1.250** | one pitch; thirty-two of them make forty millimetres |

**Two per cent silicon by volume.** The core is a heat exchanger with memory in it,
and the ratio is not a compromise — it is what makes a solid block of static memory
at the centre of a sealed cube survivable at all.

### Why the lamina is copper-molybdenum

Same argument as `202`'s cold plate, one axis further in. Copper against silicon
across forty millimetres over a sixty kelvin swing is thirty-three microns of
differential motion, at thirty-two interfaces. A composite at eighty-five per cent
molybdenum sits at seven parts per million per kelvin instead of sixteen and a
half, cutting the differential to about eleven microns, and costs conductivity —
a hundred and ninety watts per metre per kelvin against four hundred.

The core's heat load is a tenth of the faces', so it can afford the loss where the
faces could not. That asymmetry is why the two use different materials and the
blueprint should say so, or somebody will unify them.

### Vertical connectivity, which is the hard part

Every face must reach every tier. Four faces look at the stack's sides, where every
tier's edge is exposed; two look at its ends, where only the outermost tier is.

So the stack is threaded by **through-stack vias** running the full forty
millimetres, and the blueprint must work out what that costs. A via forty
millimetres long is not a via, it is a transmission line: it has real capacitance,
real resistance, and a delay that is not negligible at one point two gigahertz.
Whether the end faces reach deep tiers through this path or through a redistribution
route around the outside of the stack is the decision this ticket exists to make,
and the two have very different costs in area and in power.

**Whichever is chosen, `504` must still be able to give any face the whole
bandwidth**, so the answer cannot be one that privileges the four side faces.

### Cooling the stack

Each lamina carries its own microchannels, fed from the cage's plenum. A hundred
and ninety watts across thirty-two plates is six watts each and the geometry is
generous, so this is the easy part — but the flow has to get in and out through the
cage, and `305`'s network does not currently include the core. It must.

## Symbols this must publish

Tier and lamina thicknesses and the pitch. Tier count and stack height. Silicon
volume fraction. Lamina channel geometry, flow and pressure drop. Through-stack via
pitch, count, resistance, capacitance and delay. Per-tier heat and temperature
rise. Differential expansion per interface.

## Constraints this must assert

- Tier count times pitch equals `L_core` from `012`. The two-chain check.
- Through-stack via delay stays inside the core's cycle time from `501`.
- Lamina flow plus the six face fields equals the total in `305`. The core was
  missing from that network and this constraint is what notices.
- Differential expansion per interface stays inside `206`'s allowance.
- Silicon volume fraction times the cube volume gives a silicon area consistent
  with `1203`'s yield model.

## Suggested implementation steps

1. Draw the repeating unit and the whole stack.
2. Make the material choice and derive both the expansion and the conductivity
   consequences.
3. Decide the deep-tier access route for the end faces and price both options.
4. Add the core to `305`'s flow network, which currently omits it.
5. Close the tier-count-times-pitch equality.

## Blocks

`504`, `507`, `1202`, `1203`.

## Blocked by

`103`, `206`, `501`, `502`.

## Related documents

`000`. `005` for the thermal argument.
