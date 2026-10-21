# 021-a-crowd

Made by scripts/film-a-scene: the game run in scene mode (issue 115),
every frame saved to RAM, then frames 3 to 360 (every 3th)
cropped to 620x1180+133+140, shrunk to 40%, at 30 frames a second.

## What made it

- made: 2026-10-21 15:10:35
- commit: fa0244c21 physics-sim: a lodge at the front door, and the game's first pictures
- source fingerprint (src/ and boards/): a4f73c0b2105f624
- options: --frames 360 --from 3 --to 360 --crop 620x1180+133+140 --scale 40 --step 3
- the scene, which lived only in RAM:

```
# a crowd: a row of balls from each side, meeting on the real board
board keep
ball player 60 20 0 0
ball player 104 20 0 0
ball player 148 20 0 0
ball player 192 20 0 0
ball player 236 20 0 0
ball player 280 20 0 0
ball player 324 20 0 0
ball player 368 20 0 0
ball player 412 20 0 0
ball player 456 20 0 0
ball player 500 20 0 0
ball player 544 20 0 0
ball adversary 82 1010 0 -350
ball adversary 126 1010 0 -350
ball adversary 170 1010 0 -350
ball adversary 214 1010 0 -350
ball adversary 258 1010 0 -350
ball adversary 302 1010 0 -350
ball adversary 346 1010 0 -350
ball adversary 390 1010 0 -350
ball adversary 434 1010 0 -350
ball adversary 478 1010 0 -350
ball adversary 522 1010 0 -350
ball adversary 566 1010 0 -350
```

- the game's goodbye:

```
goodbye from physics-sim
ended: 2026-10-21 15:10:25
mode: scene
scene: /dev/shm/physics-sim/scenes/a-crowd.scene
frames drawn: 360
seconds run: 59.58
frames recorded: 360
balls active at the end: 24
```
## What it shows

A row of twelve balls from each side on the real board: the purple row drops
in at the top and scatters through the pegs while the green row rises up
through the gate row, ripples blooming on the gates as balls cross them,
until the board is a mixed swarm. All 24 balls survive. Played at 1.5 times
speed. Used at the lodge's front door.

## The story so far

On 21 October 2026 the game learned scene mode (issue 115): it can set
up one exact moment, step time evenly, save every frame and quit by itself.
The lodge's pattern was revised the same day to be a cozy fan site full of
motion, so each of the game's mechanics was filmed on its own, the scenes
and frames kept in RAM and only the gifs kept here.
