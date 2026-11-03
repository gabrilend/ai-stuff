# 013-both-balls-break

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 16 to 100 (every second one)
cropped to 360x620+262+230, shrunk to 60%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:00:32
- commit: 76483586d physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 100 --from 16 --to 100 --crop 360x620+262+230 --scale 60
- the scene, which lived only in RAM:

```
# two weakened balls, one from each side, meeting head-on on an empty board
board empty
ball player    300 150 0  260 20
ball adversary 300 600 0 -260 20
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:00:29
mode: scene
scene: /dev/shm/physics-sim/scenes/both-explode.scene
frames drawn: 100
seconds run: 17.52
frames recorded: 100
balls active at the end: 0
```
## What it shows

Two weakened balls (20 health each), one from each side, on an empty board,
meeting head-on at 260 pixels a second each. Both break at the same moment:
one ball's wedges fan upward in green and yellow, the other's fan downward in
red and purple, each spray thrown away from the side it was hit on. Both
balls gone at the end.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
