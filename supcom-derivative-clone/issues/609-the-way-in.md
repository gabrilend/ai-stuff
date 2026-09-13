# 609 — The way in

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 110, 601 |
| Blocks | 708, 904 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing runs the game. `./compile` parses every Lua file and packages the
computer build into a single archive the LOVE engine opens — but only when a
doorway file named `main.lua` exists at the project root, and it does not, so the
script says so and refuses. The headless runner (issue 110) is designed to play
a match with no window from a plain interpreter, and the viewer (issue 601) to
draw one, and nothing yet chooses between them.

## Intended behavior

One front door at the project root, `./run-prototype`, and behind it the two
files the engine insists on.

**The doorway.** The engine requires a file called `main.lua` at the root of the
game directory, so it is the one unnumbered source file in the project. It is
a doorway and not a room: it works out where the project root is, reads
`input/` first — the seed, the field's shape, the players, the catalogues, the
transport — decides which room to open from one environment variable, loads
the viewer, forwards every engine callback to it, and does nothing else. The
moment the doorway starts making decisions of its own, the project has a piece
of program sitting outside its reading order. Beside it, `conf.lua` holds the
window's shape and which engine modules start, and no logic.

**The rooms.** The variable names one of a small table of starts, and each is a
row: a match on a fresh field with nobody on the other side, a match with a
bot behind the other side once issue 901 exists, a replay from a file (issue
109), a scene held at a tick for looking at. A start that names a room this
build does not have is an error naming the room and the issue that builds it —
not a menu entry greyed out, and not a fallback to the first room.

**The front door script.** `./run-prototype` takes a word and runs the matching
program, from a table:

| Word | Runs |
| --- | --- |
| `window` (the default) | the engine on the project directory, with the doorway choosing the room |
| `headless [ticks]` | the headless runner under the plain interpreter, printing its report |
| `terminal` | the terminal viewer (issue 111) stepping a match in the terminal |
| `replay <file>` | the window, playing a recorded match |
| `archive` | the packaged build from `./compile`, run from the RAM tier |

It reads the seed from `input/seed` and honours the environment override the
tests use, makes sure the RAM tiers exist before anything writes a log, and
writes `output/goodbye` last with which match ended, how long it took, who held
the most ground, the final hash, and where the replay was written — enough that
somebody reading only that file knows what happened and can go and watch it.

**The packaged build runs the same doorway.** `./compile` already zips
`main.lua`, `conf.lua`, `src/`, `assets/`, `libs/` and `input/` into an archive;
with the doorway present it produces one, and `./run-prototype archive` opens
it, so that what is handed to somebody is the thing that was tested.

## Suggested implementation steps

1. Write `conf.lua`: title, size, resizable, antialiasing, and every module not
   needed turned off — audio, physics, joystick, video, touch — so nothing can
   be quietly depended on.
2. Write `main.lua`: find the root through the engine's source path, read
   `input/` through one numbered module that returns a record of the match's
   opening decisions and refuses an absent or malformed file by name, choose the
   room from the environment variable through a table, load the viewer, and
   forward the callbacks.
3. Write the `input/` reader as a numbered source file with a companion — the
   first thing any program in this project does — used by the doorway, the
   headless runner, and the terminal viewer alike, so that a match is described
   once.
4. Write `./run-prototype` at the root: the hard-coded root, the override, the
   table of words, the RAM tiers, the seed, and the goodbye. The seed file's
   word `random` draws a fresh one and appends it to the notebook in the RAM
   tier, as the seed file already says it will.
5. Run `./compile` and confirm the archive is produced and opens.
6. The test: the `input/` reader refuses a missing seed file by name; the room
   table refuses an unknown room by name; `./run-prototype headless` under the
   test seed prints the same hash the headless runner's test expects.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the window on a computer, and the
  doorway that opens it.
- [The shape of the code](../docs/013-the-shape-of-the-code.md) — scripts read
  `input/` first and write goodbye last.
- `compile`, at the root — the archive it packages once the doorway exists.
- Issue 110 (the headless runner), issue 111 (the terminal viewer), issue 109
  (replays), issue 601 (the viewer), issue 901 (the bot behind the other side),
  issue 708 and issue 904 (the capstones that walk in through this door).
- `input/what-to-start-with`, `input/seed`, `output/goodbye`.
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether the first screen should be a menu at all, or the game should open
  straight into a match with the menu one key away. The handheld's system has
  no launcher and boots into what was last open; a game that does the same on a
  computer would feel like the same game on both. The working choice is a
  match, with the rooms reachable by key.
