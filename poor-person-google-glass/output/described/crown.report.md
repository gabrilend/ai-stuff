<!-- made by describe (src/016-describe.lua) on 2026-10-10 22:00 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/input/descriptions/crown.txt, so the numbers behind the model can be read without opening it -->
# crown

Measured in units (1 = a default part's width). Triangles: 2136.

## The description

```
# crown.txt - the crown, described in words. Written by Claude (Opus 5.5),
# 2026-10-10, for issue 007e, from docs/core-terms.md and the owner's sixth
# round (notes/vision): the panel arm runs along the side arm of the
# wearer's glasses, reaching forward, smooth and metallic like a fine pen.
# A sketch in proportions, not a design: the band's size is the unit.
The band is a brown ring.
The emitter is a red box. The emitter is a tenth the size of the band.
The emitter is behind the band.
The light pipe is a teal rod. The light pipe lies front to back.
The light pipe is as long as the band is wide.
The light pipe is a tenth as wide as the band.
The light pipe sits on top of the band.
The glasses arm is a black rod. The glasses arm lies front to back.
The glasses arm is as long as the band is wide.
The glasses arm is half as wide as the light pipe.
The glasses arm is to the right of the band.
The panel arm is a metallic rod. The panel arm lies front to back.
The panel arm is half as long as the band is wide.
The panel arm is as wide as the glasses arm.
The panel arm is aligned with the axis of the glasses arm.
The panel arm is at the end of the glasses arm.
The panel is a white plate. The panel faces forward.
The panel is a quarter as wide as the band.
The panel is in front of the panel arm.
```

## The parts

| part | kind | colour | axis | middle (x, y, z) | along | across | deep |
|---|---|---|---|---|---|---|---|
| band | ring | brown | upright | 0, 0, 0 | 0.15 | 1 | 1 |
| emitter | box | red | upright | 0, 0, -0.55 | 0.1 | 0.1 | 0.1 |
| light pipe | rod | teal | front to back | 0, 0.125, 0 | 1 | 0.1 | 0.1 |
| glasses arm | rod | black | front to back | 0.525, 0, 0 | 1 | 0.05 | 0.05 |
| panel arm | rod | metallic | front to back | 0.525, 0, 0.75 | 0.5 | 0.05 | 0.05 |
| panel | plate | white | front to back | 0.525, 0, 1.01 | 0.025 | 0.25 | 0.25 |

## Assumed (not said in the description)

- band: no size given: a ring's own proportions (along 0.15, across 1, deep 1)

The middle of everything is the band (the first part named that no sentence places).
