# 016-a-gentle-bump

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 1 to 90 (every second one)
cropped to 200x240+342+400, shrunk to 100%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:03:13
- commit: fa0244c21 physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 90 --from 1 --to 90 --crop 200x240+342+400 --scale 100
- the scene, which lived only in RAM:

```
# two weakened balls starting almost touching, each pulled toward the other by
# its own side's gravity: a slow push that never reaches the damage threshold
board empty
ball player    300 400 0 0 20
ball adversary 304 418 0 0 20
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:03:11
mode: scene
scene: /dev/shm/physics-sim/scenes/gentle-bump.scene
frames drawn: 90
seconds run: 15.95
frames recorded: 90
balls active at the end: 2
```
## What it shows

The restaged bump: the two weakened balls start almost touching. They lean
on each other, a tiny splash shows the contact, and they slide past and part,
both intact, because their closing speed never reaches the damage threshold.
The first frame is blank (the window has not drawn yet), which makes the
loop flicker; see 017.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
