# 014-one-ball-survives

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 16 to 110 (every second one)
cropped to 360x700+262+200, shrunk to 60%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:01:13
- commit: 76483586d physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 110 --from 16 --to 110 --crop 360x700+262+200 --scale 60
- the scene, which lived only in RAM:

```
# a full-health ball and a weakened one meeting head-on: only the weak one breaks
board empty
ball player    300 150 0  260 200
ball adversary 300 600 0 -260 20
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:01:09
mode: scene
scene: /dev/shm/physics-sim/scenes/one-survives.scene
frames drawn: 110
seconds run: 19.68
frames recorded: 110
balls active at the end: 1
```
## What it shows

The same meeting with one ball at full health (200) and one at 20. The
strong green ball bounces back the way it came and survives; the magenta one
breaks, and all of its wedges spray downward, away from the hit. One ball
left at the end.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
