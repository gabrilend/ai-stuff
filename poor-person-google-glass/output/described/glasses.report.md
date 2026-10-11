<!-- made by describe (src/016-describe.lua) on 2026-10-11 00:24 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/input/descriptions/glasses.txt, so the numbers behind the model can be read without opening it -->
# glasses

Measured in units (1 = a default part's width). Triangles: 1392.

## The description

```
# glasses.txt - a pair of glasses with rectangular lenses, asked for by the
# owner (2026-10-10) as the frame the panel arm runs alongside. Written by
# Claude (Opus 5.5) for issue 007e. The left lens's width is the unit.
The left lens is a teal plate. The left lens faces forward.
The left lens is half as deep as it is wide.
The left lens is a quarter as thick as it is deep.
The bridge is a black rod. The bridge lies left to right.
The bridge is a quarter as long as the left lens is wide.
The bridge is a tenth as wide as the left lens is deep.
The bridge is to the right of the left lens.
The right lens is a teal plate. The right lens is shaped like the left lens.
The right lens faces forward. The right lens is to the right of the bridge.
The left top rim is a black rod. The left top rim lies left to right.
The left top rim is as long as the left lens is wide.
The left top rim is as wide as the bridge. The left top rim is on top of the left lens.
The left bottom rim is a black rod. The left bottom rim is shaped like the left top rim.
The left bottom rim lies left to right. The left bottom rim is under the left lens.
The right top rim is a black rod. The right top rim is shaped like the left top rim.
The right top rim lies left to right. The right top rim is on top of the right lens.
The right bottom rim is a black rod. The right bottom rim is shaped like the left top rim.
The right bottom rim lies left to right. The right bottom rim is under the right lens.
The left hinge is a black box. The left hinge is a tenth the size of the left lens.
The left hinge is to the left of the left lens.
The right hinge is a black box. The right hinge is shaped like the left hinge.
The right hinge is to the right of the right lens.
The left arm is a black rod. The left arm lies front to back.
The left arm is twice as long as the left lens is wide. The left arm is as wide as the bridge.
The left arm is behind the left hinge.
The right arm is a black rod. The right arm is shaped like the left arm.
The right arm lies front to back. The right arm is behind the right hinge.
```

## The parts

| part | kind | colour | axis | middle (x, y, z) | along | across | deep |
|---|---|---|---|---|---|---|---|
| left lens | plate | teal | front to back | 0, 0, 0 | 0.125 | 1 | 0.5 |
| bridge | rod | black | left to right | 0.625, 0, 0 | 0.25 | 0.05 | 0.05 |
| right lens | plate | teal | front to back | 1.25, 0, 0 | 0.125 | 1 | 0.5 |
| left top rim | rod | black | left to right | 0, 0.275, 0 | 1 | 0.05 | 0.05 |
| left bottom rim | rod | black | left to right | 0, -0.275, 0 | 1 | 0.05 | 0.05 |
| right top rim | rod | black | left to right | 1.25, 0.275, 0 | 1 | 0.05 | 0.05 |
| right bottom rim | rod | black | left to right | 1.25, -0.275, 0 | 1 | 0.05 | 0.05 |
| left hinge | box | black | upright | -0.55, 0, 0 | 0.1 | 0.1 | 0.1 |
| right hinge | box | black | upright | 1.8, 0, 0 | 0.1 | 0.1 | 0.1 |
| left arm | rod | black | front to back | -0.55, 0, -1.05 | 2 | 0.05 | 0.05 |
| right arm | rod | black | front to back | 1.8, 0, -1.05 | 2 | 0.05 | 0.05 |

## Assumed (not said in the description)

- left lens: no size given: a plate's own proportions (along 0.1, across 1, deep 1)

The middle of everything is the left lens (the first part named that no sentence places).
