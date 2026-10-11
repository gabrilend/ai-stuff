<!-- made by src/021-the-tolerance-report.lua on 2026-10-10 23:26 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/eye-position-fit.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# eye-position-fit

**On how wide a range of eye spacings does one frame keep each pupil behind its middle tile?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| offset_per_eye (mm) | 0 | -4.65 to 5.65 | -4.502 to 5.502 | none | no limit | no limit |
| offset_in_tiles (ratio) | 0 | -0.3591 to 0.4363 | -0.3463 to 0.4232 | -0.5 to 0.5 | pass | pass |

## What to tighten first (parts)

- **offset_per_eye**: nothing above 0.5%
- **offset_in_tiles**: nothing above 0.5%

## What the design must absorb (conditions)

- **offset_per_eye**: wearer_eye_distance 100%
- **offset_in_tiles**: wearer_eye_distance 100%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| frame_eye_distance | part | 63 | −0.3 | +0.3 | mm | docs/sizes.md: typical 63; frame made to +/-0.3 |
| wearer_eye_distance | condition | 63 | −9 | +11 | mm | docs/sizes.md: adults 54-74 |
| lens_width | part | 52 | −0.2 | +0.2 | mm | docs/sizes.md: typical lens width |
| tiles_across | part | 4 | −0 | +0 | count | issue 304 open question 2: guess 4 by 4 |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
