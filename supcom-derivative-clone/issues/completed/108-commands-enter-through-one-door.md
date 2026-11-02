# 108 — Commands enter through one door

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 105 |
| Blocks | 210, 302, 307, 701 |
| Reads | [factories and patterns in the sand](../../docs/006-factories-and-patterns-in-the-sand.md) |
| Open questions | A6 |

## Current behavior

Built. `src/035-commands.lua` is the door: `queue` takes a command or refuses it
by name into the world's refusal ring, and `apply_due`, wired as the tick's
first row, applies every command stamped for the tick in the order queued. The
queue and the ring are groups in the world's layout. The phase 1 program's door
suite holds, and a new one covers every refusal, the ring and a full queue.

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

## What happened

- **`queue` returns nothing when it takes a command**, not a ticket. The tests
  and the contract table both say "nothing or a refusal string"; a ticket would
  be a second thing for the caller to hold that nothing reads.
- **`VERBS` is keyed by name**, as the test asks (`VERBS["set-energy-level"]`),
  and each verb's number in the world's arrays is its place in the sorted list
  of names. Logs and refusals carry names, so a new verb renumbering the others
  breaks nothing recorded.
- **`set-energy-level` is a row now, not only `noop`.** The phase 1 test queues
  it and the hash test applies it. It holds only the rule that the menu has
  four buttons -- a fifth is refused at apply time, into the ring -- and writes
  the team's `energy_level`; what each button does is issue 302's.
- **Arguments are named per verb** (`ARGUMENTS`) and stored in four double
  slots in the record's order, so a verb's apply receives the command back as a
  table with its arguments under their names (`unpack`).
- **Applied commands leave the queue at once.** The issue says they stay until
  the replay recorder has written them; issue 109 has the recorder write each
  command as the door accepts it, so by the time a command is due it is
  already in the log and nothing needs it kept.
- **A queued command for a tick already past is an error, not a skip.** It can
  only happen when the tick count was moved without the door running, and a
  command that silently never happens is the worst desync there is.
- **Refusal reasons are text.** The ring needs sentences a viewer can show, so
  the world's layout gained a `text` type: a Lua array of strings, empty where
  there is nothing, folded into the hash by its bytes.

## Related documents and tools

- [Factories and patterns in the sand](../../docs/006-factories-and-patterns-in-the-sand.md)
- [Other players](../../docs/011-other-players.md), which adds one rule at this door
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)

## Still open

- A6: how many players and teams. The working ruling is two teams with any
  number of players each, one truck per player; the command carries both a
  team and a player so that either reading fits the record.
