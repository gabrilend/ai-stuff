# 115 - Scene Mode: the game stages a moment and films it

## Status: completed

## Depends on

None.

## Blocks

- 114 (the lodge's gifs come from scenes)
- 114c (the rooms hang the films)

## Current Behavior

Built as described below.

- `src/064-scene.h`, `src/065-scene.c`: the options, the scene reader (a
  dispatch table of line kinds, `board` and `ball`), and the goodbye writer.
- `src/001-main.c`: reads the options before anything else; applies the
  scene after the world is set up (empty boards, opponent paused, panels
  hidden, balls placed in slots 0..n-1 and given the scene's exact velocity
  and health, overriding the random sideways nudge a placed ball normally
  gets); skips all keyboard and mouse handling in a scene; saves each drawn
  frame with `LoadImageFromScreen` / `ExportImage`; stops after the frame
  limit; writes `output/goodbye` on every clean exit.
- `scripts/film-a-scene SCENE NAME [--frames --from --to --crop --scale
  --step]`: runs a scene into `tmp/shared-memory/frames/NAME/`, checks the
  goodbye is fresh, and makes a cropped, shrunk, looping gif from every
  STEP-th frame, filed in `development-history/` with notes holding the
  scene itself and the goodbye.
- `scripts/test-scene-mode`: six refusals checked (unknown line, unknown
  owner, no balls, unknown board word, unknown option, a zero frame count),
  all passing. The running case is checked by film-a-scene.

Learned while building it:

- **A scene steps a fixed 1/60 s per frame.** Saving a frame takes about a
  sixth of a second; stepping by the real time between frames moved balls
  ten times too far, and the first two test balls passed through each other
  instead of colliding.
- **The first frame or two are blank**, before the window has drawn; films
  start at frame 3.
- **A tiling window manager resizes the window after it opens** (800 wide
  became 885 here), which shifts the table right; the game's own resize
  handling moves the scene's balls with it, so crops are taken in the
  resized window's pixels.
- Scenes and frames stay in RAM (`/dev/shm/physics-sim`); only the gifs and
  their notes are kept.

Before this, the game could only be watched while it played itself, pictures
were taken from outside its window while hoping nobody typed, and it left no
record of a run.

## Intended Behavior

Three command-line options, all optional; without them the game behaves
exactly as before.

- `--scene FILE` — set up the moment described in FILE instead of a normal
  game: optionally clear the boards, place the listed balls with exact
  positions, velocities and health, stop both sides from dropping balls of
  their own, hide the score and controls panels, and ignore the keyboard
  and mouse entirely.
- `--record DIR` — after every frame is drawn, save it as
  `DIR/frame-NNNN.png`.
- `--frames N` — quit cleanly after N frames.

A scene file is plain text, one instruction per line, `#` starting a
comment:

```
board empty            # or: board keep
ball player    X Y VX VY [HEALTH]
ball adversary X Y VX VY [HEALTH]
```

X and Y are pixels from the top-left corner of the player's table; VX and VY
are pixels per second. A player ball falls down, an adversary ball falls up.
A line the reader does not understand stops the game with the file and line
number; a scene is never half-loaded.

Every clean exit, scene or not, writes `output/goodbye`: when it ended, the
mode, the scene file, frames drawn, seconds run, frames recorded, and balls
still active. A crash writes nothing, so a missing or stale goodbye is the
error report.

Scene files and recorded frames are scaffolding and live in RAM
(`tmp/` and `tmp/shared-memory/`); only the finished gifs are kept, in
`development-history/`.

## Suggested Implementation Steps

1. `src/064-scene.h`, `src/065-scene.c`: the options and the scene reader
   (arguments in, a list of balls and a board choice out; errors name file
   and line).
2. In the main program: read the options first; after the world is set up,
   apply the scene (clear pegs, lines and closed shapes on both boards when
   asked; pause the opponent; place the balls); skip all input handling in a
   scene; after each frame, save it when recording; stop after N frames.
3. Write the goodbye on the way out.
4. Add the scene source to the game's build list.
5. A script, `scripts/film-a-scene SCENE NAME`, that runs a scene into RAM,
   turns the frames into a small cropped gif, and files it in
   `development-history/` with notes.
