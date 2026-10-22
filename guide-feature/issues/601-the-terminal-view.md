# 601 — The terminal view

phase 6, viewers for the desk and the browser

## Current behavior

The page can be read with `cat tmp/shared-memory/page/current`.

## Intended behavior

A LuaJIT program that draws the display box in a terminal, in the plain
style of st: a thin border, each voice in its own colour, fading thoughts in
three or four brightness steps of that colour (standard terminal colour
codes, chosen by relevance band from a table), redrawn when `page/current`
changes. A voice marked `over-box` gets a marker on its first row. If the
terminal is smaller than the box, it shows an error saying so.

Reads `input/terminal-view` (101). Writes a goodbye receipt (pages drawn,
seconds run).

"Limited display features": no animation, no partial transparency.

## Suggested implementation steps

1. Read pages with the page reader (202).
2. Draw with plain escape codes, no curses library needed.
3. A test that feeds a recorded page and compares the drawn output with a
   reference file.

## Related documents

- `docs/datapath-viewers.md`

## Blocked by

101, 202, 203.

## Blocks

604.
