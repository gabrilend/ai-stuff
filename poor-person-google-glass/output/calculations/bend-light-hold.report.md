<!-- made by src/021-the-tolerance-report.lua on 2026-10-11 00:18 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/bend-light-hold.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# bend-light-hold

**Around the bend of the band, does total internal reflection alone keep the light in, and how much is left to the mirror coating?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| trapping_margin (ratio) | 0.007608 | -0.007455 to 0.02116 | -0.001845 to 0.01706 | at least 0 | fail | fail |
| share_left_to_the_mirror (percent) | 0 | 0 to 12.07 | 0 to 0 | none | no limit | no limit |
| acceptance_half_angle (deg) | 31.05 | 29 to 33.02 | 29.19 to 32.92 | none | no limit | no limit |
| tightest_bend_trapped (mm) | 78.59 | 68.58 to 91.33 | 68.54 to 88.63 | none | no limit | no limit |

## What to tighten first (parts)

- **trapping_margin**: cladding_index 50%, pipe_width 1%
- **share_left_to_the_mirror**: nothing above 0.5%
- **acceptance_half_angle**: cladding_index 99%, core_index 1%
- **tightest_bend_trapped**: cladding_index 97%, pipe_width 2%, core_index 1%

## What the design must absorb (conditions)

- **trapping_margin**: bend_radius 48%
- **share_left_to_the_mirror**: nothing above 0.5%
- **acceptance_half_angle**: nothing above 0.5%
- **tightest_bend_trapped**: nothing above 0.5%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| pipe_width | part | 5 | −0.1 | +0.1 | mm | the owner: as wide as a thick glasses arm (5-6 mm) |
| bend_radius | condition | 90 | −10 | +10 | mm | issue 105 model; heads differ (docs/sizes.md: 520-620 mm around) |
| core_index | part | 1.492 | −0.001 | +0.001 | ratio | datasheet: PMMA, the usual core of side-emitting fibre |
| cladding_index | part | 1.4 | −0.01 | +0.01 | ratio | datasheet: fluorinated polymer cladding of plastic fibre |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
