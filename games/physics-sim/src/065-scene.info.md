# src/065-scene.c (with 064-scene.h)

## Purpose
Scene mode: the game sets up one exact moment instead of a normal game,
optionally saves every frame, and quits after a set number of frames; and
the goodbye receipt written on every clean exit. Used by
`scripts/film-a-scene` to film single mechanics.

## Command line (read by the game before anything else)

| option | meaning |
|--------|---------|
| `--scene FILE` | play the scene in FILE; input is ignored for the whole run |
| `--record DIR` | save every drawn frame as `DIR/frame-NNNN.png` (DIR must exist) |
| `--frames N` | quit cleanly after N frames (N > 0) |

With no options the game is unchanged. In a scene each frame steps a fixed
1/60 s, because saving frames is slow and real-time steps would change the
physics.

## Scene file

Plain text, one line each, `#` starts a comment:

```
board empty | board keep
ball player|adversary X Y VX VY [HEALTH]
```

X, Y: pixels (float) from the top-left of the player's table. VX, VY:
pixels per second (float). HEALTH: float, default full. Up to 64 balls. A
line not understood, or a scene with no balls, stops the game with file and
line.

## External functions

### scene_parse_arguments
```c
int scene_parse_arguments(int argc, char* argv[], SceneOptions* options)
```
Fills `options` from the command line and the scene file. Returns 1 on
success, 0 after printing the problem.

### scene_write_goodbye
```c
void scene_write_goodbye(const SceneOptions* options, int frames_drawn,
                         double seconds_run, int frames_recorded,
                         int balls_active)
```
Writes `output/goodbye` (relative to the working directory): ended time,
mode, scene file, frames drawn, seconds run, frames recorded, balls active.

## Structures

`SceneBall`: `owner` (int, OWNER_PLAYER or OWNER_ADVERSARY), `x`, `y`,
`vx`, `vy`, `health` (floats).

`SceneOptions`: `active` (int), `scene_path` (char[512]), `clear_board`
(int), `balls` (SceneBall[64]), `ball_count` (int), `recording` (int),
`record_dir` (char[512]), `frame_limit` (int, 0 = none).

## Tests
`scripts/test-scene-mode` (refusals, no screen needed);
`scripts/film-a-scene` fails unless the game writes a fresh goodbye.
