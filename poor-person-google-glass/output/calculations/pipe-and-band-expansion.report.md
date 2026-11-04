<!-- made by src/021-the-tolerance-report.lua on 2026-10-10 23:26 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/pipe-and-band-expansion.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# pipe-and-band-expansion

**How much do the glass light pipe and the nylon band holding it change length differently?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| length_difference (mm) | 0.1934 | -0.1643 to 0.6339 | -0.102 to 0.4888 | -0.1 to 0.1 | fail | fail |
| strain_if_glued (ratio) | 0.000967 | -0.0008176 to 0.003154 | -0.0005099 to 0.002444 | -0.0005 to 0.0005 | fail | fail |

## What to tighten first (parts)

- **length_difference**: band_expansion 2%
- **strain_if_glued**: band_expansion 2%

## What the design must absorb (conditions)

- **length_difference**: temperature 96%, assembly_temperature 2%
- **strain_if_glued**: temperature 96%, assembly_temperature 2%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| pipe_length | part | 200 | −1 | +1 | mm | issue 105 model: 90 mm radius x 2.25 radians |
| glass_expansion | part | 3.3e-06 | −1e-07 | +1e-07 | per-C | docs/sizes.md: borosilicate |
| band_expansion | part | 0.0001 | −2e-05 | +2e-05 | per-C | docs/sizes.md: nylon PA12 |
| temperature | condition | 30 | −15 | +15 | C | docs/sizes.md: wearing temperature 15-45 |
| assembly_temperature | condition | 20 | −2 | +2 | C | guess: a room |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
