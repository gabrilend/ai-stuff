# 018-one-ball-falls

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 3 to 300 (every second one)
cropped to 620x1020+133+140, shrunk to 40%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:04:53
- commit: fa0244c21 physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 300 --from 3 --to 300 --crop 620x1020+133+140 --scale 40
- the scene, which lived only in RAM:

```
# a single ball dropped onto the real board, falling through the pegs to the gates
board keep
ball player 303 20 0 0
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:04:39
mode: scene
scene: /dev/shm/physics-sim/scenes/one-ball-falls.scene
frames drawn: 300
seconds run: 48.83
frames recorded: 300
balls active at the end: 1
```
## What it shows

A single ball dropped onto the real board, five seconds of it: the ball is
still threading the middle of the peg diamond when the film ends. Too short;
see 019.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
