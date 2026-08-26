# 306 -- The command log is the replay

**Phase:** 3, the world ticks
**Blocked by:** [108](108-a-world-writes-itself-down.md),
[301](301-the-tick-is-a-dispatch-table.md)
**Blocks:** [309](309-taking-a-turn-back.md) -- a retcon is an edit to this log.
**Documents:** [commands enter through one door](../docs/010-commands-enter-through-one-door.md),
[the turn is a transaction](../docs/019-the-turn-is-a-transaction.md)

## Current behaviour

Nothing exists.

## Intended behaviour

Every decoded instruction, written down with the tick it arrived on. A snapshot
plus the log that follows it reproduces the session exactly.

### What goes in, including the parts somebody regretted

**Every instruction that decoded**, whether or not it was then accepted.

A refused command is still a record of what somebody tried, and a log of attempts
is the most direct evidence available about where the interface confuses people.
Refusals are marked, not omitted -- a log that quietly drops them is a log that
cannot answer "why did nothing happen when I pressed that".

**And rolled-back turns stay in it.** A record that omits what somebody took back
is not a record. See [3.6](../docs/016-open-questions.md) for whether that reaches
the engraving; it reaches the log regardless.

### It has to be editable, which most logs do not

A **retcon** in [309](309-taking-a-turn-back.md) is: restore the snapshot at the
turn's head, change one instruction in the log, replay forward. That means this is
not an append-only stream of opaque bytes. It is a structure that can be indexed by
turn, read back, altered, and replayed.

That requirement shapes the format. Instructions are stored decoded rather than raw
-- as the register-file values they became, not the bytes they arrived as -- so that
changing one does not mean re-encoding a packet. The canonical encoding from
[commands](../docs/010-commands-enter-through-one-door.md) means the decoded form
and the wire form correspond exactly, so nothing is lost by storing the decoded one.

### Turn boundaries are in the log

The log records where each turn began. That is what lets a rollback find the head
to restore, and what lets a replay be described as "up to turn 40" rather than "up
to tick 5,392".

## Suggested implementation steps

1. Define the entry: tick, turn, viewer, opcode, the register-file values, and
   whether it was accepted or refused with which reason.
2. Write it during intake, at decode time, before the gauntlet runs -- so a refusal
   is recorded with its reason rather than being absent.
3. Index by turn, so finding a turn's head is a lookup and not a scan.
4. Write the replay: load a snapshot, feed instructions in order, tick between
   them, stop where asked.
5. Write it to disk in the RAM tier during a session and to a durable file at the
   end. A session is hours long and the log is not small --
   [12.3](../docs/016-open-questions.md) asks whether it is capped or rotated, and
   that is not answered.
6. Write the companion `.info.md`.
7. Test the round trip: run a scripted session, replay from the log, compare the
   world hash at every tick. Then edit one instruction, replay, and assert the
   worlds diverge from exactly that tick and not before.
