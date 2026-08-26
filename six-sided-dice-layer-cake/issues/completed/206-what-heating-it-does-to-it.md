# 206 — What heating it does to it

Produces `src/018-thermomechanical-stress.md`.

## Current behavior

**Done.** `src/018-thermomechanical-stress.md` exists, and it changed two things
outside itself.

**It turned plasma dicing into a requirement.** Tier-to-lamina interfaces carry
about a hundred and nine megapascals once the residual frozen in at bonding is
counted -- and the residual is two thirds of it, which was not expected. Against a
sawn edge at a hundred and fifty megapascals that is a margin of one point four
on a failure that scraps a whole cube. A plasma-diced edge etches rather than
cuts, leaves no crack population, and gives three point two. `1201` now has to
specify it.

**It found the face assembly bows forty-five microns**, three times the flatness
`013` had assumed, and that cascaded into the seal and the plenum. The better
answer -- reordering the stack so it does not bow -- was not attempted and is
recorded.

The copper comparison is now a constraint asserted in the direction of alarm:
copper laminae would leave a margin of one point zero two against the composite's
three point two.

Six constraints, all holding. **Fatigue life is still not computed** -- three
swings are counted and none is turned into cycles to failure, which is what `086`
is relying on.

## Intended behavior

**What differential expansion does to every bonded interface in the machine, over
the temperature swing it will actually see, repeated for the life required.**

### The number the whole ticket turns on

Silicon expands at about two and a half parts per million per kelvin. Copper at
about sixteen and a half. That factor of six and a half, across a part fifty-two
millimetres wide and a swing of sixty kelvin, is **forty-three microns of relative
motion**, and it happens at a bond that is ten microns thick.

If the bond is rigid, the strain goes into the silicon. A hundred megapascals is
enough to break a die with an ordinary edge finish. If the bond is compliant, the
strain goes into the bond, and the bond fatigues.

### The interfaces, in order of how much trouble they are

| interface | span | materials | differential over 60 K |
|---|---|---|---|
| die to cold plate | 52 mm | silicon–silicon | **zero, by choice** (`202`) |
| memory tier to cooling lamina | 40 mm | silicon–CuMo | ~11 µm |
| die to face interposer | 52 mm | silicon–glass | small; glass is chosen for this |
| face plate to edge rail | 60 mm | silicon–stainless | ~40 µm, taken by the compression seal |
| cage to core | 40 mm | silicon–CuMo | ~11 µm |

The first row is what this analysis bought. The second row is what it did not
fully buy: thirty-two tier-to-lamina interfaces, each moving eleven microns, and
copper-molybdenum at seven parts per million per kelvin is the compromise that got
it down from thirty-three. `036` owns that stack.

### The three swings, which are not the same

**Assembly.** From the bonding temperature down to room temperature, once. Largest
single excursion and it is built into the part as residual stress before anything
is ever powered on.

**Power cycling.** Room temperature to operating, a hundred thousand times over
the life in `086`. Smaller amplitude, enormous count. This is what fatigues.

**Load stepping.** A face going from idle to full in microseconds, within a token,
millions of times. Small amplitude, astronomical count, and confined to the die
and its immediate bond. `026` produces the temperature history; this blueprint
turns it into a cycle count.

### Warpage

A stack of dissimilar layers bonded flat at one temperature is not flat at
another; it bows, like a bimetallic strip. The face assembly is eight layers and
some of them are asymmetric about the neutral axis. **Warpage is what breaks the
tolerance stack in `201`**, and it is the mechanism by which a thermal problem
becomes a sealing problem.

## Symbols this must publish

Differential expansion per interface. Peak stress in silicon per interface.
Assembly residual stress. Cycle counts for each of the three swings. Fatigue life
per bond type. Face assembly warpage as a function of temperature. The bow
coefficient. Margin to fracture.

## Constraints this must assert

- Peak silicon stress at every interface stays under the fracture strength from
  `011`, with a stated margin.
- Bond fatigue life exceeds the cycle count from `086`.
- Warpage at the temperature extremes stays inside the flatness allowance in
  `201`, which is the constraint that couples this phase to the sealing one.
- The face cold plate differential is exactly zero. Trivially true, and worth
  asserting so that anybody who changes the material in `011` finds out
  immediately.

## Suggested implementation steps

1. Tabulate every bonded interface with its span and its two materials.
2. Compute differential motion for each over each of the three swings.
3. Convert to stress with the moduli from `011`, treating the bond as rigid first
   because it is the pessimistic case and cheap to compute.
4. Where rigid fails, size the compliance required and check the fatigue life.
5. Do the warpage calculation for the face assembly and hand the result to `201`.
6. Write the copper-versus-silicon comparison into the blueprint properly, since
   `202` cites it.

## Blocks

`202` depends on this argument even though it is numbered earlier; `205`, `503`,
`1202`, `1206`.

## Blocked by

`102` for the expansion coefficients and moduli, `201` for the geometry.

## Related documents

`005` for the temperatures. `026` for the load-step history. `086` for the life.
