<!-- made by src/021-the-tolerance-report.lua on 2026-10-10 23:19 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/two-eye-vertical-alignment.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# two-eye-vertical-alignment

**How far apart vertically do the two eyes' pictures land, if the tile mirrors tilt by their tolerances?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| vertical_mismatch (mrad) | 0 | -8.727 to 8.727 | -3.508 to 3.508 | -1 to 1 | fail | fail |

## What to tighten first (parts)

- **vertical_mismatch**: hinge_angle_left 25%, hinge_angle_right 25%, mount_tilt_left 9%

## What the design must absorb (conditions)

- **vertical_mismatch**: frame_twist 25%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| hinge_angle_left | part | 0 | −0.05 | +0.05 | deg | guess: arm hinge angle error |
| hinge_angle_right | part | 0 | −0.05 | +0.05 | deg | guess: arm hinge angle error |
| mount_tilt_left | part | 0 | −0.03 | +0.03 | deg | guess: tile glued to its sub-arm |
| mount_tilt_right | part | 0 | −0.03 | +0.03 | deg | guess: tile glued to its sub-arm |
| sag_left | part | 0.02 | −0.02 | +0.02 | deg | guess: arm droop under the tile's weight |
| sag_right | part | 0.02 | −0.02 | +0.02 | deg | guess: arm droop under the tile's weight |
| frame_twist | condition | 0 | −0.05 | +0.05 | deg | guess: frame twisted between the eyes when worn |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
