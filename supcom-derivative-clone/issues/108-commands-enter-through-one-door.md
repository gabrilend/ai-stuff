# 108 — Commands enter through one door

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 105 |
| Blocks | 210, 302, 307, 701 |
| Reads | [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) |
| Open questions | A6 |

## Current behavior

Nothing. The vision's invariant — everything can be queued — is stated in the
factories document and enforced by nothing. The phase 1 test program looks for
a source file whose stem is `commands` and asserts that a command for a past
tick is refused and a command for a future tick applies at that tick and not
before.

## Intended behavior

**Every** player action is a command: a record with a verb, a tick stamp, a
team, a player, and a small fixed set of integer and double arguments whose
meaning the verb decides. There is exactly one way in, `queue(world, command)`,
and exactly one way commands take effect, `apply_due(world)`, which is the
first row of the tick. No command takes effect on the instant it is issued;
this is what lets a command arrive from another machine before its tick and be
indistinguishable from one issued here.

`queue` returns an integer ticket, or a **named refusal**: an unknown verb, a
tick at or before the tick already run, a team outside the match. A refused
command is not queued and the refusal is recorded in a small ring in the world
so that a viewer can show it, loudly, where it happened.

`apply_due` walks the queue in insertion order and, for every command whose
tick is now, calls the verb's row in `VERBS` — a dispatch table of name and
apply function, indexed by the verb's integer. A verb's apply may itself refuse
with a name — a pattern with a point in the water, a cell already occupied —
and that refusal goes into the same ring. Refusals are the viewer's business to
show and never the simulation's business to repair.

The queue is a group of flat arrays in the world, sized from the parameters,
and the ring of refusals is another. Commands already applied stay in the
queue until the replay recorder has written them, and are released by it.

In this phase the table holds one row, `noop`, which does nothing and exists
because a machine in lockstep must be able to send a batch with nothing in it.
Every later verb — set the energy level, place a factory with its pattern,
stop a line, move the truck, launch the plane — is a row added by the issue
that builds it.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "The one door every player action comes through." commands`.
2. Write the command record's fields and types, and the queue and refusal-ring
   groups in the world's layout.
3. Write `VERBS` with its `noop` row and the rule for adding rows.
4. Write `queue(world, command)` with the three refusals.
5. Write `apply_due(world)` and add it as the first row of the tick's table.
6. Fill the companion with the record's fields and the list of refusals.

## Related documents and tools

- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
- [Other players](../docs/011-other-players.md), which adds one rule at this door
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)

## Still open

- A6: how many players and teams. The working ruling is two teams with any
  number of players each, one truck per player; the command carries both a
  team and a player so that either reading fits the record.
