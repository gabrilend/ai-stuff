<!-- made by src/021-the-tolerance-report.lua on 2026-10-10 23:19 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/hydraulic-reach-drift.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# hydraulic-reach-drift

**How far does the hydraulic arm creep, or how hard does it push if locked, as it warms?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| reach_creep (mm) | 0.1428 | -0.2149 to 0.5588 | -0.1309 to 0.4165 | -0.5 to 0.5 | fail | pass |
| pressure_if_locked (MPa) | 7.572 | -13.72 to 35.67 | -7.911 to 25.07 | -10 to 10 | fail | fail |

## What to tighten first (parts)

- **reach_creep**: nothing above 0.5%
- **pressure_if_locked**: oil_stiffness 1%

## What the design must absorb (conditions)

- **reach_creep**: temperature 96%, filled_at 4%
- **pressure_if_locked**: temperature 95%, filled_at 4%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| piston_bore | part | 3 | −0.01 | +0.01 | mm | guess: smallest practical piston |
| oil_volume | part | 200 | −20 | +20 | mm3 | guess: cylinder and line, 0.2 millilitres |
| oil_expansion | part | 0.0007 | −5e-05 | +5e-05 | per-C | docs/sizes.md: hydraulic mineral oil (volume) |
| housing_expansion | part | 6.9e-05 | −5e-06 | +5e-06 | per-C | aluminium: 3 x 23e-6 (volume from length) |
| oil_stiffness | part | 1.5 | −0.1 | +0.5 | GPa | docs/sizes.md: bulk modulus 1.4-2.0 |
| temperature | condition | 30 | −15 | +15 | C | docs/sizes.md: wearing temperature 15-45 |
| filled_at | condition | 22 | −3 | +3 | C | guess: filled in a room |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
