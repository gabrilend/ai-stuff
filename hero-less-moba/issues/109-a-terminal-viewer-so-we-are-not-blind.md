# 109 — A Terminal Viewer, So We Are Not Blind

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 107, 108 |
| Blocks | 701 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) |
| Open questions | none |

## Current behavior

The terminal viewer draws the field as text — the three lanes, the connectors
marked apart, stone, rubble, and the bodies — plus the lane-pressure bars and one
team's chest. `./run-prototype terminal` redraws it in place.

It is kept rather than discarded: it is faster to debug in, works where nothing
graphical does, pipes to a file and diffs, and keeps the viewing layer honest by being
a second consumer of the same snapshots.

## Intended behavior

A viewer that draws the match as text: three lanes as three rows of characters,
one character per few paces, with each team's soldiers as different glyphs, the
towers as marks along the row, and a header line carrying the phase, the tick,
and each team's push depths.

It reads snapshots and nothing else. It writes commands and nothing else. It has
no state the simulation needs, decides nothing the simulation could decide, and
cannot write into the world under any circumstances. Everything the real viewer
in phase 7 will have to obey, this one obeys first, while it is small enough that
obeying is easy.

It is **not** the shipping product and is not meant to become one. It is the
thing that means nobody develops phases 2 through 6 blind. It can be built in an
afternoon, it runs anywhere, it needs no libraries, and it can be piped to a file
and diffed.

A frontline oscillating in the middle of a row of text is exactly as informative
as a frontline oscillating in a rendered window, and it is the picture the
phase-2 demo needs: the stalemate the vision describes, rendered, as the problem
statement.

## Suggested implementation steps

1. Write a lane-to-row projection: map a soldier's `progress` along its lane's
   path to a column, so the three rows are directly comparable.
2. Draw the two teams' soldiers with distinct glyphs and stack overlapping bodies
   as a count rather than overdrawing.
3. Mark towers along the row, and dim them as their health falls.
4. Write a header: tick, phase, push depths, chest contents per team.
5. Add a step mode — advance one tick per keypress — and a run mode with a
   throttle, so a suspicious moment can be walked through.
6. Add a replay mode that plays a recorded command list, so a match that went
   strangely can be watched again.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- The headless runner from issue 108, which this wraps

## Still open

Which drawing library does the real viewer use — LÖVE, an FFI binding to
something lower level, or something else? The decision does not have to be made
until phase 7, but making it late means phase 7 is larger than it looks, and this
terminal viewer is exactly the thing that makes it comfortable to postpone.
