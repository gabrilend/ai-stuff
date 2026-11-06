# 111 — A terminal viewer, so we are not blind

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 102, 109 |
| Blocks | — |
| Reads | [the views](../../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Built. `src/038-terminal-viewer.lua` draws a snapshot as text: one character per
cell graded by height above the water, water as `~`, a live unit as its kind's
letter, owned cells tinted when colour is asked for, and a legend of the tick,
each team's share of the land, and the live counts. `./run-headless --draw`
prints the last tick through it.

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

## What happened

- **Grading is relative to the field's own highest cell**, worked out from the
  snapshot, so a low field and a tall one both use every mark.
- **Unit letters wait for the catalogue.** Kinds are numbered by the unit
  catalogue (issue 202), which does not exist yet; `LETTERS` is empty and a unit
  of a kind with no letter is drawn as `?`, loudly, rather than as ground. Issue
  202 adds a row per kind.
- **Colour is a terminal colour code per team**, blue for team one and red for
  team two, only when the caller asks; the plain drawing has no escape codes, so
  it reads in a log or a failure message.
- **The viewer counts territory itself**, from the snapshot's owners and the
  field's heights, because the viewer rule forbids it to call the territory
  module.
- The phase 1 demo, which shows the dunes and the water line through this, is
  built with issue 113, the phase's last.

## Related documents and tools

- [The views](../../docs/010-the-views.md)
- [The dunes and the sightlines](../../docs/002-the-dunes-and-the-sightlines.md)
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)

## Still open

Nothing beyond the questions in the table.
