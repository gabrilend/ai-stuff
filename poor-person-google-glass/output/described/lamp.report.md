<!-- made by describe (src/016-describe.lua) on 2026-10-11 00:24 from /mnt/mtwo/programming/ai-stuff/poor-person-google-glass/input/descriptions/lamp.txt, so the numbers behind the model can be read without opening it -->
# lamp

Measured in units (1 = a default part's width). Triangles: 2112.

## The description

```
# lamp.txt - a desk lamp, using the owner's own example phrasings ("twice as
# large as", "proportionally scaled to", "aligned with the rotational axis
# of the cylinder shaped thing"). Written by Claude (Opus 5.5), 2026-10-10,
# for issue 007e.
The base is a grey disc.
The weight is a black cylinder. The weight is half as wide as the base.
The weight is twice as tall as the base. The weight sits under the base.
The pole is a silver rod. The pole is three times as long as the base is wide.
The pole is aligned with the rotational axis of the cylinder shaped thing.
The pole sits on top of the base.
The shade is a yellow cone. The shade is proportionally scaled to the base.
The shade is at the end of the pole.
The bulb is a white ball. The bulb is a quarter the size of the shade.
The bulb is at the other end of the shade.
```

## The parts

| part | kind | colour | axis | middle (x, y, z) | along | across | deep |
|---|---|---|---|---|---|---|---|
| base | disc | grey | upright | 0, 0, 0 | 0.2 | 1 | 1 |
| weight | cylinder | black | upright | 0, -0.3, 0 | 0.4 | 0.5 | 0.5 |
| pole | rod | silver | upright | 0, 1.6, 0 | 3 | 0.45 | 0.45 |
| shade | cone | yellow | upright | 0, 3.6, 0 | 1 | 1 | 1 |
| bulb | sphere | white | upright | 0, 2.98, 0 | 0.25 | 0.25 | 0.25 |

## Assumed (not said in the description)

- base: no size given: a disc's own proportions (along 0.2, across 1, deep 1)

The middle of everything is the base (the first part named that no sentence places).
