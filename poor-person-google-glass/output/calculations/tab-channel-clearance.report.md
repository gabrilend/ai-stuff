<!-- made by src/021-the-tolerance-report.lua on 2026-10-10 23:19 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/tab-channel-clearance.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# tab-channel-clearance

**Does a tab still swing freely in its channel, from cold to warm?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| clearance_per_side (mm) | 0.03498 | 0.009441 to 0.05951 | 0.02079 to 0.04817 | at least 0.01 | fail | pass |

## What to tighten first (parts)

- **clearance_per_side**: channel_width 53%, tab_thickness 30%, hinge_play 13%

## What the design must absorb (conditions)

- **clearance_per_side**: nothing above 0.5%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| channel_width | part | 0.4 | −0.02 | +0.02 | mm | guess: channel etched in glass, +/-5% |
| tab_thickness | part | 0.3 | −0.015 | +0.015 | mm | guess: photo-etched stainless sheet, +/-5% |
| coating_per_face | part | 0.005 | −0.002 | +0.003 | mm | guess: dark absorbing coat on each face |
| hinge_play | part | 0.02 | −0.01 | +0.01 | mm | guess: side-to-side wobble at the hinge |
| temperature | condition | 30 | −15 | +15 | C | docs/sizes.md: wearing temperature 15-45 |
| assembly_temperature | condition | 20 | −2 | +2 | C | guess: a room |
| tab_expansion | part | 1.73e-05 | −5e-07 | +5e-07 | per-C | docs/sizes.md: stainless 304 |
| glass_expansion | part | 3.3e-06 | −1e-07 | +1e-07 | per-C | docs/sizes.md: borosilicate |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
