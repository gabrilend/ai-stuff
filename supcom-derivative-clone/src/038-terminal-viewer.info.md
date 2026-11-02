# 038-terminal-viewer

Draws a snapshot as text.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The first viewer: a snapshot as text, so nobody works blind from the first tick
and a failing test can print what it saw. It runs over a wire, in a log, in a
failure message.

**The viewer rule is enforced here first.** It reads a snapshot and nothing
else: no reference to the live world, no simulation module loaded, no
simulation function called, no command issued. Everything it shows it works out
from the snapshot's own arrays.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `draw(snapshot, options)` | a snapshot (from `snapshot.copy`); optionally `{colour = true}` | one string, below |
| `GRADES` | | the land's grading, `{from, mark}` rows |
| `WATER` | | the water's mark, `~` |
| `LETTERS` | | a letter per unit kind, by the kind's catalogue number |
| `UNKNOWN` | | the mark for a unit of a kind with no letter, `?` |
| `COLOURS`, `RESET` | | each team's terminal colour code, and the reset |

## Data structures it owns

What `draw` returns: one line per row of the field, top row first, one character
per cell, then three lines of legend.

A cell's character, first match wins:

1. a live unit stands in it: its kind's letter (the last unit in array order, if
   several);
2. below the water line: `~`;
3. land: the mark of the last `GRADES` row whose `from` the cell reaches, where
   the cell's share is its height above the water line over the highest cell's.

| From | Mark |
| --- | --- |
| 0.00 | `.` |
| 0.12 | `:` |
| 0.25 | `-` |
| 0.37 | `=` |
| 0.50 | `+` |
| 0.62 | `*` |
| 0.75 | `#` |
| 0.87 | `@` |

With `options.colour`, an owned land cell is wrapped in its team's colour code
and the reset.

The legend:

- `tick N` -- the snapshot's tick;
- `team T holds P% of the land` for every team -- owned land cells over all land
  cells, counted from the snapshot;
- `U units alive, C commands waiting, R refusals kept`.

`LETTERS` follows the unit catalogue's `index` column: `T` tank, `A` anti-air
gun, `H` helicopter, `F` frigate, `C` command truck, `E` enforcer. A unit of a
kind with no letter draws as `?`, loudly rather than as ground; phase 2's tests
check that every catalogue kind has its own letter.
