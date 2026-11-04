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
