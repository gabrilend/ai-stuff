# 1003 — Tracing Is Clicking Corners

| | |
| --- | --- |
| Phase | 10 — The Tracing Table |
| Blocked by | 1001, 1002 |
| Blocks | — |
| Reads | `src/079-the-client.info.md` |
| Open questions | two, at the bottom |

## Current behavior

There is no way to describe a world that already exists as a picture. Everything
that makes a world makes it out of numbers somebody typed, and the reference
painting is not going to be typed.

## Intended behavior

A front end that shows the picture and lets a person draw the world onto it.

**Nothing on the screen but the picture, the lattice, the vertices and the lines
between them.** No buttons, no panels, no menus. Every action is a click, a drag,
a wheel or a key, and the thing being edited is the only thing drawn.

| Doing | Means |
| --- | --- |
| left click on empty ground | put down a vertex, joined to the last |
| left click on the first vertex of the shape being drawn | close it into a structure |
| left click on an existing vertex | pick it up |
| drag | move whatever was picked up |
| left click on a line | put a vertex into it |
| right click on a vertex | take it out, and rejoin its neighbours |
| right click inside a structure | take the structure away |
| wheel | zoom, at the pointer |
| middle drag | pan |

Elevation is a property of the shape being drawn and of the lattice at once, so
raising it before drawing puts the next structure a layer higher and moves the
lattice to match. That is the whole of the third dimension: **there is no way to
draw a vertex whose height is unknown**, because the height was chosen before the
click.

**What has not been traced yet is drawn.** Cells no structure covers are the work
remaining, so they are shaded — the picture with the finished parts clear and the
unfinished parts marked is the only progress there is.

Saving writes the plan and the scene beside each other, so the result can be
walked straight into the client and looked at.

## Suggested implementation steps

1. The picture and the lattice first, with nothing editable, and get the
   calibration right before anything is drawn on top of it. A structure traced
   against a lattice that does not fit is a structure that has to be traced again.
2. Then one structure, and save, and load it back. A tool that cannot reopen its
   own work is a tool somebody uses once.
3. Then the editing — moving, inserting, deleting — which is what makes it
   possible to be wrong the first time.
4. Snap to the lattice, and a modifier to place freely. Which of the two is right
   depends on whether the painting is on a consistent lattice, and that is open
   question one of [1002](1002-the-lattice-is-the-measurement.md).

## Related documents and tools

- [1001](completed/1001-a-plan-is-polygons-at-elevations.md) — what it writes
- [1002](1002-the-lattice-is-the-measurement.md) — the lattice it draws over

## Open questions

**One. How does a tag get chosen with no buttons?** A key that cycles through the
words is the obvious answer and it needs the words to be known in advance, which
open question one of [1001](completed/1001-a-plan-is-polygons-at-elevations.md) says they
are not. Typing one is the alternative and means the tool has a text field, which
is a panel by another name.

**Two. What happens when two structures at the same elevation overlap?** Higher
wins settles every other case and says nothing about this one. Drawing order would
settle it and is exactly the order-dependence the format was built to avoid. Not
answered; today the later one wins and that is an accident rather than a decision.
