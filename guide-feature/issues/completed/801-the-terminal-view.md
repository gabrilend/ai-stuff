# 801 — The terminal view

phase 8, viewers for the desk and the browser

## Current behavior

The canvas can be read with `cat tmp/shared-memory/canvas/current`.

## Intended behavior

A LuaJIT program that draws the canvas in a terminal, in st's plain style: a
thin border at the canvas size, unmarked cells in the default colour, marked
cells in their voice's colour, with `word` marks bright and `sentence` marks
dim, both stepping down in brightness with age (a table from age band to
colour code). It redraws when `canvas/current` changes. A terminal smaller
than the canvas shows an error naming both sizes.

Reads `input/terminal-view` (101). Writes a goodbye receipt (versions drawn,
seconds run).

"Limited display features": no animation, no partial transparency.

## Suggested implementation steps

1. Read versions with the viewer-side reader (202).
2. Draw with plain escape codes, no curses library.
3. A test that draws a recorded version and compares with a reference file.

## Related documents

- `docs/datapath-viewers.md`

## Blocked by

101, 202, 203.

## Blocks

804.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The age table is a list of steps per mark kind** in
   `input/terminal-view`: `word-steps = "bright bright normal normal dim"`,
   `sentence-steps = "normal dim"`, the first for age 0, the last for every
   older age. A step is `bright` (the colour's bright code, bold), `normal`
   or `dim` (faint). Three steps are what standard codes give without
   256-colour support.
2. **Voice colours are standard codes 30 to 37** in the order of the
   `voices:` header (31 red, 32 green, 34 blue by default), and kuvalu's
   marks (601) have their own (35, magenta). A fourth voice takes the
   colours round again.
3. **Orphan marks are drawn as sentence marks**: a fading fragment, not a
   fresh word.
4. **"Redraws when canvas/current changes" by looking every 0.25 s**
   (`check-every`): there is no inotify binding in this project (the
   blitter says the same). It also redraws when the terminal is resized.
5. **The too-small check counts the border**: a canvas of 60x20 needs a
   62x22 terminal, and the error says so beside the terminal's size.
6. **The whole screen is cleared and drawn again** for each version, with
   no cursor tricks, as st's plain style suggests; a canvas is small, so
   it is quick.
7. **A clean stop is a stop file** that `scripts/terminal-view` drops on
   Ctrl-C or TERM, as `scripts/run-blitter` does, since LuaJIT cannot catch
   a signal.
8. **`--replay FOLDER`, `--once`, `--size`, `--for` and `--plain`** let a
   test or a demo drive it without a person (the phase 8 demo uses
   `--replay`).

## What was built (2026-11-05)

- `src/070-terminal-view.lua`, `scripts/terminal-view`,
  `input/terminal-view`.
- `src/071-test-terminal-view.lua`: 30 checks; reference screens in
  `assets/test-terminal/`.
- `docs/datapath-viewers.md`; the phase 8 progress file.

## Needs the owner's machine

- A look in st on kuvalu at the real canvas, and the colours and steps
  tuned to that terminal's palette.
