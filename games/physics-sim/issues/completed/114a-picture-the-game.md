# 114a - Picture the game

## Status: completed

## Parent Issue: 114 - The Lodge

## Depends on

None.

## Current Behavior

`scripts/picture-the-game` exists and works as described below, with one
addition: `--editor` photographs the board editor (`bin/board-editor`,
window "Board Editor - Physics Simulator") instead of the game.
`development-history/` holds pictures 001 to 012: three from a first
scratch run (001-003, filed by hand before the script existed), six from the
script's first run (004-009), one of the editor (010), and two of built lodge
rooms taken with headless Firefox (011-012). Every picture has its notes
file, all sections filled.

Learned while building it: the game's window takes the keyboard when it
opens, so keys and scroll-wheel turns meant for another window reach the
game. During the first run automatic dropping was switched on (only the A
key does that) and the view was scrolled off the board (picture 003). The
pictures are trustworthy only while nobody types; the lasting fix is the
game learning to be driven by script (an open question in issue 114).

## Intended Behavior

`scripts/picture-the-game [DIR] [--at SECONDS]... [--name NAME]` runs the game
from the project folder with nobody at the keyboard, captures the window
titled "Physics Simulator - Pachinko" at each requested second (default 5, 20
and 45), stops the game, and files every capture into
`development-history/` under the next free number:

- `NNN-NAME-at-Ss.png` — the picture;
- `NNN-NAME-at-Ss.info.md` — what made it (commit, run options, the moment,
  a fingerprint of `src/` and `boards/`, the game's own first log lines), and
  two sections a person fills in: "What it shows" and "The story so far".

The game's full log goes to `tmp/shared-memory/picture-the-game.log`. A
capture that fails stops the script with the reason; a picture is never
silently missing.

## Suggested Implementation Steps

1. Ensure `tmp/` (→ `/tmp/physics-sim`) and `tmp/shared-memory/`
   (→ `/dev/shm/physics-sim`) exist.
2. Start `bin/physics-sim` with the project as its working directory; note
   its process id.
3. For each moment, wait, then capture the window by title (`import -window`).
4. Number from the highest existing `development-history/NNN-` prefix.
5. Write the notes file beside each picture.
6. Stop the game and wait for it.

Note: `import` captures what is on screen in the window's rectangle, so
another window lying over the game shows up in the picture.
