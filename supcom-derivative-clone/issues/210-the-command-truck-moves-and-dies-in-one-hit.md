# 210 — The command truck moves and dies in one hit

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 108, 201 |
| Blocks | 406, 607 |
| Reads | [the command truck and its plane](../docs/008-the-command-truck-and-its-plane.md) |
| Open questions | A1, A2, A8 |

## Current behavior

Nothing. The command door (issue 108) and the unit row (issue 201) do not
exist. The test program `tests/020-things-that-roll-fly-and-sail.lua` names this
issue, looks for the stem `command-truck`, and asserts that the truck moves on
command and that the catalogue makes it die in one tank shell.

## Intended behavior

**The command truck is a unit like any other, with two commands nothing else
has.** It is a row in the unit arrays with the land domain and the catalogue's
one-shell health. What sets it apart is entirely in the command door: it is the
one unit a `move` command may name, and the one unit a `launch` command may
name.

**It moves on command.** A `move` command carries a truck's row and a
destination; the door validates that the row is a live truck of the commanding
team and that the destination is a land cell (issue 203), refuses either by
name, and otherwise gives the truck a **one-leg pattern** from where it stands
to the destination. That is the whole mechanism: the truck walks a pattern like
everything else (issue 204), and "moving" is being handed a fresh one. Nothing
in the move pass knows the truck is special. A second `move` replaces the
pattern; the vision's "few things can be moved, like command trucks" is this
door and no other.

**It launches a plane on a compass wheel.** A `launch` command carries the truck's
row and a heading. The door validates the truck and that the truck's launch
counter — the pair of integers, issue 106 — has advanced enough since the last
launch, refuses by name otherwise, and spawns the truck's plane: a unit row in
the air domain with the plane's kind, at the truck's position, with its mission
set to *heading* and the heading stored. What the plane then does is issue 406's
business; this issue puts it in the air and rewrites the truck's `launch_at`.

**It dies in one hit.** That is a catalogue relation (issue 202), not code here:
the truck's health cap is one tank shell. What its death *means* is A2, and the
working ruling is the parent game's — a team whose last truck dies has lost —
which is built in the tick's ending rule (issue 110's match report), not here.
This issue exposes `trucks_alive(world, team)` for that rule to read.

The truck is the natural centre of a team: engineers on energy duty (issue 303)
raise their buildings nearest to it, and the roster is imagined around it. It
holds no special columns; its `launch_at` lives in a small per-team array
because there is one truck per player and the unit row should not grow a column
that every tank carries as zero.

## Suggested implementation steps

1. Claim `src/NNN-command-truck.lua` with `./new-source-file command-truck`.
2. Add the `move` and `launch` verbs to the command door's dispatch table (issue
   108), each a function that validates and either refuses by name or applies.
3. Write `move(world, id, x, y)`: the validations above, then a one-leg pattern
   written into the pattern store (issue 204) and the truck's `pattern` and `leg`
   rewritten.
4. Write `launch(world, id, heading)`: the validations above, the launch counter
   check through issue 106's `read`, a `spawn` of the plane kind with mission
   *heading* and the heading stored in the plane's row, and `launch_at`
   rewritten.
5. Write `trucks_alive(world, team)` as a range walk over live rows of the truck
   kind.
6. Write the refusal texts the viewer will show: not your truck, not a land
   cell, still reloading, with the tick the next launch is allowed.

## Related documents and tools

- [the command truck and its plane](../docs/008-the-command-truck-and-its-plane.md)
- [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) — the command door and the queue invariant
- [the cloud](../docs/007-the-cloud.md) — what the plane's report does
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **A1.** Whether the vision's command tank and command truck are one unit; the
  working ruling is one, and this issue builds one.
- **A2.** What losing the truck means; the working ruling is that the team has
  lost, built in the match's ending rule rather than here.
- **A8.** Whether the truck's plane is one plane that scouts and shoots or a free
  scout and a costly hunter; the working ruling is one, and `launch` spawns one
  kind.
