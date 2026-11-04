<!-- made by src/028-joints.lua on 2026-10-10 23:29 from input/joints/crown-sketch.lua and output/joints/crown-sketch.results.lua, so each joint's answer can be read without the viewer -->
# Joints of crown-sketch

7 joints: 2 with an equation, 5 still empty.

## band / light pipes: fail

**Does the gap between these two parts stay open from cold to warm?** (joint-gap-under-heat)

| answer | nominal | worst case | usual spread | verdict |
|---|---|---|---|---|
| gap_when_warm (mm) | -0.1033 | -0.3547 to 0.1076 | -0.2631 to 0.05654 | fail |

- gap = 0.0006527 mm (−0.02, +0.02): stand-in; bind to structure.gap. Tolerance a guess: +/-0.02 mm
- reach_a = 201.3 mm (−0.05, +0.05): stand-in; bind to structure.reach_a
- reach_b = 197.6 mm (−0.05, +0.05): stand-in; bind to structure.reach_b
- expansion_a = 0.0001 per-C (−2e-05, +2e-05): nylon-pa12.expansion (input/materials.lua): docs/sizes.md
- expansion_b = 3.3e-06 per-C (−1e-07, +1e-07): borosilicate.expansion (input/materials.lua): docs/sizes.md
- temperature = 30 C (−15, +15): docs/sizes.md: wearing temperature 15-45
- assembly_temperature = 20 C (−2, +2): guess: a room

## panel arm / panel: pass

**Does the gap between these two parts stay open from cold to warm?** (joint-gap-under-heat)

| answer | nominal | worst case | usual spread | verdict |
|---|---|---|---|---|
| gap_when_warm (mm) | 0.04861 | 0.01814 to 0.07882 | 0.02668 to 0.07054 | pass |

- gap = 0.05456 mm (−0.02, +0.02): stand-in; bind to structure.gap. Tolerance a guess: +/-0.02 mm
- reach_a = 48.2 mm (−0.05, +0.05): stand-in; bind to structure.reach_a
- reach_b = 7.389 mm (−0.05, +0.05): stand-in; bind to structure.reach_b
- expansion_a = 2.36e-05 per-C (−5e-07, +5e-07): aluminium-6061.expansion (input/materials.lua): datasheet
- expansion_b = 7.1e-06 per-C (−1e-07, +1e-07): n-bk7.expansion (input/materials.lua): docs/sizes.md
- temperature = 30 C (−15, +15): docs/sizes.md: wearing temperature 15-45
- assembly_temperature = 20 C (−2, +2): guess: a room

