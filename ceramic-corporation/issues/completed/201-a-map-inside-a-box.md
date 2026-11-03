# 201 — A map inside a box

| | |
| --- | --- |
| Phase | 2 — Maps of maps, and history |
| Blocked by | 102 |
| Blocks | — |
| Reads | [the org map, M14](../../docs/002-the-org-map.md), [open questions, Q6](../../docs/005-open-questions.md#q6--scale) |

## Current behavior

`inside PATH` is checked only for pointing at a directory with an `org.map`.

## Intended behavior

An inner map's doors line up with the ports of the box that holds it: each
`in` port of the box is a door in on the inner map from an outside named after
the parent box's source, and each `out` port a door out. The board can then
descend: a blocked box with an inside shows which inner box is the cause.
How the outer map's rules bind the inner one stays open (Q6).

## What Happened

Built as `src/017-inside.lua`, run by `./validate-org` and `./blocked-board`.
The workshop's making box now holds a map of cutting and joining, added by an
applied proposal (change 3) so the workshop's history still explains its map.
Decisions, each written into documents 002 and 005:

- **The inner map's outsides are named after the box's ports** — not after the
  parent box's sources, as this issue first said. The port name is what the
  box itself owns; a source's name belongs to another box, and renaming that
  box would break a map it knows nothing about.
- **N5: an inner map has no other outside.** It reaches the world only through
  its box, so a door cannot be hidden one level down, where the outer map's
  doors rule (an outside eye and a week) never sees it.
- **N2: a box with an inside cannot reuse a port name for in and out**, since
  from inside they would be one outside.
- **Checked all the way down; a map inside itself is refused by real path.**
- **The board looks inside sources, not blocked boxes.** A blocked box is
  blocked by its inputs, which the board already ranks; a source that owes
  something is the box whose inside explains the delay. One line per level,
  following each inner board's top row.
- **State stays per map** (new open question Q10): deriving an inner door's
  fed-ness from the box's port would let a line in one directory change the
  meaning of another, and is worth deciding with a real nested org in view.
- **Each module's run-as-a-program guard now runs only once per process.**
  With 017 loaded from the validator and the board, a module loaded as a
  library while another runs could otherwise start its own `main` again.
