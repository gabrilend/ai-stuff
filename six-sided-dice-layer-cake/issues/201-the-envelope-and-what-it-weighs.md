# 201 — The envelope, and what it weighs

Produces `src/013-cube-envelope.md`.

## Current behavior

Nothing. The cube is described as sixty millimetres on a side and no drawing of it
exists.

## Intended behavior

The finished object as a mechanical part: six orthogonal views, an isometric, the
tolerance stack, the mass, and the six things that stick out of it.

**What is on the outside.** Six port fields, one per face, all identical. Eight
corner manifold blocks, four of them with a coolant inlet fitting and four with an
outlet. Twelve edge rails, which are internal to the envelope but define it. Four
mounting features, on the four corners of one chosen face.

**The tolerance stack** is the real work. A face plate has to sit flat enough that
its seal compresses evenly along all four edges, and there are six of them, so the
stack closes around a loop rather than along a line. The binding number is face
plate flatness, and `017` cannot be written until it exists.

**The mass** is worth deriving rather than guessing, because it decides the
mounting and because a two hundred and sixteen cubic centimetre object that
weighs one and a half kilograms is a surprising thing to hand somebody.

| contributor | derivation |
|---|---|
| core laminae | thirty-two plates of copper-molybdenum, 40 × 40 × 1.2 mm |
| core tiers | thirty-two of silicon, 40 × 40 × 0.05 mm |
| face cold plates | six of silicon, 52 × 52 × 2 mm |
| face interposers | six, glass-core |
| edge rails and corner blocks | stainless, twelve and eight |
| coolant | channel volume times the fluid's density |
| everything else | connectors, regulators, the cage |

Nearly all of it is the core laminae, which is what you would expect of an object
whose middle is by volume mostly metal.

## Symbols this must publish

`L_cube` is already `012`'s. What belongs here is the derived envelope: the
tolerance band on each master dimension, the flatness requirement, the total mass
and its contributors, the wetted volume, and the exterior surface area.

Every mass term must be derived — a volume from `012`'s lengths times a density
from `011` — never entered. The moment somebody writes down a mass in grams the
number stops tracking the geometry.

## Constraints this must assert

- The tolerance stack around a closed loop of four face plates does not exceed the
  seal's compression range in `017`. This is the one that will fail first.
- Mass derived from geometry agrees within one part in a thousand with mass
  derived from mean density times volume. Two routes to the same number.
- The exterior surface area equals six times the face area plus the edge and
  corner contributions, which is a check that the chamfers were accounted for once
  rather than twice or not at all.

## Suggested implementation steps

1. Draw the six views and the isometric, dimensioned with symbol names in
   brackets. `107` will check every name.
2. Write the tolerance band for each of the eleven given lengths in `012`, and say
   which manufacturing process produces it.
3. Close the loop: sum the four-plate stack around one great circle of the cube and
   compare against the seal range.
4. Derive the mass table.
5. Add the two-route mass check.

## Blocks

`202`, `203`, `204`, `205`, `207`, and `1301`.

## Blocked by

`103`.

## Related documents

`000` has the cutaway. `090` is where these drawings end up.
