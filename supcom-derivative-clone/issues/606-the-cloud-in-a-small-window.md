# 606 — The cloud in a small window

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 401, 603 |
| Blocks | — |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. The cloud is designed in [the cloud](../docs/007-the-cloud.md) as a
list of planes with a mission each and no positions that matter, and issue 401
builds it. No viewer draws it, and the lens list (issue 603) has no row for it.

## Intended behavior

The vision's television inside the television: a small window the player opens
on the cloud, that shows the swarm and reads as a **mood** — crowded or thin,
one colour or two, calm or churning — rather than as numbers.

**It is a lens.** The cloud is one row in the layer table, and the window is a
lens whose layer is that row, small, sitting over a corner of a field lens
because a later lens draws over an earlier one. It can be moved, resized, and
closed like any lens. On the handheld it is the obvious tenant of the second
screen (issue 802), and nothing about it changes there.

**The planes in it have no positions, so the window invents some — and says
so.** A plane in the cloud is a row with a mission and a team and nothing else
the simulation cares about. The window gives each one a drawn position from a
stable scatter — a function of the plane's identifier, so that a plane does not
jump between frames — drifting slowly on a per-frame angle so that the swarm
churns. That drift is decoration, it is computed in the viewer, it is written
nowhere, and the code says in a comment at the scatter that a drawn position in
this window is not data and must never be read back as one.

Planes are drawn as marks in their team's colour. The mood is carried by what
the swarm honestly is: two sides in the cloud draw as two colours mixed; one
side gone defensive leaves a single colour; a round resolving this tick — the
round counter's increment moved — flashes the marks of the pair that fought.
Planes on missions elsewhere — defensive, intercepting, bombing, returning —
are **not in the window**, because they are on the field with real positions
and the units layer draws them there. The window shows the cloud and only the
cloud.

On a field lens, the cloud itself is drawn as one soft mark above the field's
centre, so that a player knows where it is without opening the window.

## Suggested implementation steps

1. Add the cloud row to the layer table (issue 603): a draw function taking a
   lens and the snapshot pair, walking the snapshot's plane rows whose mission
   is in-cloud.
2. Write the scatter: identifier to a point inside the lens rectangle, plus a
   drift from the wall clock. Fold it, and put the comment about decoration on
   the fold.
3. Draw the marks by team, and the round flash by comparing the cloud's round
   increment in the newer snapshot against the older.
4. Add the cloud's mark to the dunes row's draw at the field's centre, read
   from the snapshot's cloud position so that answering the open question about
   where the cloud is moves the mark without touching the viewer.
5. Give the viewer a key that opens the cloud window if none is open and closes
   it if one is, placing it in the corner of the largest field lens.
6. The test: the cloud row's draw takes only a lens and snapshots; the scatter
   returns the same point for the same identifier twice; a plane whose mission
   is not in-cloud is not drawn by this row.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the cloud as a lens.
- [The cloud](../docs/007-the-cloud.md) — the missions and the rounds the window
  is showing.
- Issue 401 (the cloud and its rows), issue 403 (rounds on a counter), issue 603
  (the lens and the layer table), issue 802 (the second screen).
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether the window should show the two sides' air strength as two bars. It is
  a fact from the snapshot, and it would answer the question the mood only
  hints at — which is either the point of the window or the thing it was
  designed not to do. The vision asks for a cloud, not a scoreboard; the
  working choice is no bars.
