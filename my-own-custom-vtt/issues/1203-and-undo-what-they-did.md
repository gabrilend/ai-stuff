# 1203 -- And undo what they did

**Phase:** 12, the table as it is actually played
**Blocked by:** [1202](1202-the-host-can-remove-somebody.md)
**Blocks:** [1206](1206-the-phase-twelve-demo.md)
**Documents:** [the turn is a transaction](../docs/019-the-turn-is-a-transaction.md)

## Current behaviour

A rollback restores the world to the head of a turn and either discards
everything declared since or replays it forward.

Both are **all or nothing**. There is no way to undo one person's actions and
keep everybody else's.

## Intended behaviour

The other half of "we do not need to check who anybody is".

A host who has just removed somebody wants the table to be where it would have
been if that person had never touched it — and **not** to lose the four other
people's evening in the process.

### It is a retcon with a filter

The machinery is already there and this is one condition inside it:

| Existing | This |
| --- | --- |
| restore the head of a turn | the same |
| replay every command in the log forward | replay every command **except that seat's** |
| the world ends up where it was | the world ends up where it would have been |

The command log already records **who** issued every entry, because a viewer
index is written into every one. Nothing needed to be added to make this
possible, which is a sign the log was recorded at the right grain.

### It is honest about what it cannot undo

**It cannot undo what people saw.** Fog only grows, and a rollback restores the
fog bitmap — but the people at the table still remember the corridor. That was
already true of every rollback and it is written down in
[the turn is a transaction](../docs/019-the-turn-is-a-transaction.md).

**It cannot undo further back than the ring.** A troublemaker who was quiet for
an hour and then acted cannot be unwound to before the hour. The ring is finite
and says so.

**It cannot undo a turn whose sheets could not be copied.** Same rule as every
other rollback, same sentence.

### The refusals must name the seat

"Could not undo that" is not usable. "Seat 3's earliest command is in turn 41,
which has fallen out of the ring" is.

## Suggested implementation steps

1. `session_expunge(s, viewer, turn)` -- restore the head of that turn and replay
   forward, skipping entries from that viewer.
2. The expunged entries stay in the log, marked, because a log that quietly omits
   the parts somebody regretted is not a log.
3. Find the earliest turn that viewer touched, so a caller can ask "how far back
   do I have to go".
4. Refuse by name when that turn is not reachable.
5. Test: two people act, one is expunged, the other's actions survive exactly;
   and the world hash matches a run where the expunged person never issued
   anything.
