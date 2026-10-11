<!-- made by src/021-the-tolerance-report.lua on 2026-10-10 23:26 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/output/calculations/index-match-drift.results.lua, so the numbers can be read without the calculation; format in docs/tolerances.md -->
# index-match-drift

**How much light is lost and how far is the picture shifted as the filling's index drifts with temperature?**

## Answers

| answer | nominal | worst case | usual spread | limit | worst case | spread |
|---|---|---|---|---|---|---|
| index_difference (ratio) | -0.00136 | -0.00876 to 0.00573 | -0.00699 to 0.00427 | none | no limit | no limit |
| light_lost (percent) | 0.0002412 | 0.0002412 to 0.01 | -0.005806 to 0.006288 | at most 1 | pass | pass |
| shift_through_a_tab (mm) | -0.0002946 | -0.05941 to 0.03887 | -0.008872 to 0.008283 | -0.05 to 0.05 | fail | pass |

## What to tighten first (parts)

- **index_difference**: colour_mismatch 1%, glass_index 1%
- **light_lost**: nothing above 0.5%
- **shift_through_a_tab**: tab_face_angle 98%

## What the design must absorb (conditions)

- **index_difference**: temperature 98%
- **light_lost**: temperature 100%
- **shift_through_a_tab**: temperature 2%


## Inputs

| input | kind | nominal | below | above | unit | from |
|---|---|---|---|---|---|---|
| glass_index | part | 1.517 | −0.0005 | +0.0005 | ratio | docs/sizes.md: N-BK7 at 587.6 nm; catalogue tolerance |
| liquid_index | part | 1.517 | −0.0002 | +0.0002 | ratio | guess: matching liquid's labelled tolerance |
| liquid_index_per_C | part | -0.00037 | −3e-05 | +3e-05 | per-C | docs/sizes.md: matching liquids |
| glass_index_per_C | part | 2e-06 | −1e-06 | +1e-06 | per-C | docs/sizes.md: N-BK7 |
| colour_mismatch | part | 0.0005 | −0.0005 | +0.0005 | ratio | guess: liquid and glass disperse differently at red and green |
| temperature | condition | 30 | −15 | +15 | C | docs/sizes.md: wearing temperature 15-45 |
| matched_at | condition | 25 | −0 | +0 | C | datasheets quote indices at 25 C |
| boundaries | part | 12 | −0 | +0 | count | issue 105 model: 6 tabs, 2 faces each |
| tab_face_angle | part | 40 | −40 | +40 | deg | issue 105 model: tabs swing 0-80 degrees |
| tab_thickness | part | 0.3 | −0.015 | +0.015 | mm | as in tab-channel-clearance |

Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, as if the errors were independent. See docs/tolerances.md.
