# 111 — A terminal viewer, so we are not blind

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 102, 109 |
| Blocks | — |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing draws anything. The dune tool's own dump, when it exists, prints
heights; nothing prints a snapshot. The phase 1 test program looks for a source
file whose stem is `terminal-viewer` and asserts that `draw` returns one line
per row of the field.

## Intended behavior

A viewer that draws a snapshot as text, so that from the first tick nobody
works blind and so that a failing test can print what it saw. It runs where a
window cannot: over a wire, in a log, in a failure message, and it stays useful
after the window exists.

`draw(snapshot)` returns one string: one character per cell, one line per row.
The character is graded by the cell's height band; water is its own mark; a
cell with an owner is tinted by a colour code when the caller asks for colour
and left plain when it does not; a cell with a live unit on it shows a letter
for the unit's kind instead of the ground. A short legend follows the field:
the tick, each team's territory as a percentage, and the live counts.

It reads a **snapshot** and nothing else. It holds no reference to the world,
calls no simulation function, and issues no commands. That is the viewer rule,
and this is the first viewer, so it is where the rule is first enforced.

The grading is a small table of thresholds and characters, and the unit letters
are a table indexed by kind, so that a new kind is a row.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Draws a snapshot as text." terminal-viewer`.
2. Write the grading table and the kind-letter table.
3. Write `draw(snapshot)`: the field row by row, then the legend.
4. Give `run-headless` a `--draw` option that prints the final snapshot through
   it, and give the phase 1 demo the dunes and the water line to show.
5. Fill the companion with the legend's meaning.

## Related documents and tools

- [The views](../docs/010-the-views.md)
- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md)
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)

## Still open

Nothing beyond the questions in the table.
