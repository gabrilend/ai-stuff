# 020-one-ball-falls-to-a-gate

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 3 to 470 (every 4th)
cropped to 620x1020+133+140, shrunk to 40%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:09:15
- commit: fa0244c21 physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 470 --from 3 --to 470 --crop 620x1020+133+140 --scale 40 --step 4
- the scene, which lived only in RAM:

```
# a single ball dropped onto the real board, falling through the pegs to the gates
board keep
ball player 303 20 0 0
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:09:04
mode: scene
scene: /dev/shm/physics-sim/scenes/one-ball-falls.scene
frames drawn: 470
seconds run: 79.05
frames recorded: 470
balls active at the end: 1
```
## What it shows

The same fall trimmed to end just after the gate. Used in the lodge.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
