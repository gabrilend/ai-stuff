# 015-a-gentle-bump-first-try

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 1 to 150 (every second one)
cropped to 240x320+322+360, shrunk to 75%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:02:55
- commit: fa0244c21 physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 150 --from 1 --to 150 --crop 240x320+322+360 --scale 75
- the scene, which lived only in RAM:

```
# two weakened balls drifting into each other slowly: below the damage threshold, nobody breaks
board empty
ball player    300 330 0  20 20
ball adversary 312 420 0 -20 20
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:02:51
mode: scene
scene: /dev/shm/physics-sim/scenes/gentle-bump-first-try.scene
frames drawn: 150
seconds run: 26.79
frames recorded: 150
balls active at the end: 2
```
## What it shows

A first attempt at a gentle bump, kept as a mistake on the record: the two
balls start too far apart, their opposite gravities pull them together fast,
they glance off each other and leave the frame within half a second, so most
of the loop is an empty frame. Re-filmed here after the original was deleted
by mistake before being kept; the scene and the physics steps are the same
as the deleted one.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
