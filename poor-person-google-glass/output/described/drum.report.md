<!-- made by describe (src/016-describe.lua) on 2026-10-10 23:39 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/input/descriptions/drum.txt, so the numbers behind the model can be read without opening it -->
# drum

Measured in units (1 = a default part's width). Triangles: 2016.

## The description

```
# drum.txt - a lidded drum with a handle and a knob. Written by Claude
# (Opus 5.5), 2026-10-10, as the first example for ./describe (issue 007e).
The drum is a blue cylinder.
The lid is a red disc. The lid is slightly wider than the drum.
The lid sits on top of the drum.
The handle is a silver rod. The handle is as long as the drum is wide.
The handle lies left to right. The handle sits on top of the lid.
The knob is a black ball. The knob is a quarter the size of the drum.
The knob is at the end of the handle.
```

## The parts

| part | kind | colour | axis | middle (x, y, z) | along | across | deep |
|---|---|---|---|---|---|---|---|
| drum | cylinder | blue | upright | 0, 0, 0 | 1 | 1 | 1 |
| lid | disc | red | upright | 0, 0.625, 0 | 0.25 | 1.25 | 1.25 |
| handle | rod | silver | left to right | 0, 0.825, 0 | 1 | 0.15 | 0.15 |
| knob | sphere | black | upright | 0.625, 0.825, 0 | 0.25 | 0.25 | 0.25 |

## Assumed (not said in the description)

- drum: no size given: a cylinder's own proportions (along 1, across 1, deep 1)

The middle of everything is the drum (the first part named that no sentence places).
