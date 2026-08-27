# 1203 -- And undo what they did

**Phase:** 12, the table as it is actually played
**Blocked by:** [1202](1202-the-host-can-remove-somebody.md)
**Blocks:** [1206](1206-the-phase-twelve-demo.md)
**Documents:** [the turn is a transaction](../../docs/019-the-turn-is-a-transaction.md)

## Current behaviour

**Done.** `session_expunge(session, seat, turn)` restores the head of that turn
and replays every command forward except that seat's.

**Nothing had to be added to the log to make it possible**, because the log
already recorded who issued every entry. That is a sign it was recorded at the
right grain — the feature was one condition inside a loop that already existed.

The expunged entries stay in the log, marked refused, because a log that quietly
omits the parts somebody regretted is not a log.

`session_earliest_turn_touched_by` answers *how far back do I have to go*, so a
refusal can say which turn rather than just failing.

### The test compares against a world where they never spoke

Two identical worlds, two identical sessions, the same seed. In one a guest gives
orders and is then expunged; in the other they never say anything. The two are
compared **by world hash**, because "it looks about right" is not a comparison —
and they diverge first, so that the comparison at the end means something.

It refuses for the same reasons any rollback refuses: the turn fell out of the
ring, or its sheets could not be copied. Same paths, same sentences.

### Unwind first, then remove

The order matters and it is not obvious. **Who holds a scope is world state**, so
a rollback that reaches back past a removal undoes the removal — and the person
is back at the table.

Nothing is wrong with either piece. The order is a fact about how the two
compose, and it was not written down anywhere until the phase twelve demo tried
them the other way round and reported a checksum mismatch that belonged to
itself.

The general shape: **two correct operations can have an order, and the order is
not a property of either of them.** It lives in whatever uses both, which means
nothing local will ever tell you about it.

### What it cannot undo, unchanged

The people at the table still remember the corridor. Fog is restored and memory
is not, which was already true of every rollback and is written down in
[the turn is a transaction](../../docs/019-the-turn-is-a-transaction.md).

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
[the turn is a transaction](../../docs/019-the-turn-is-a-transaction.md).

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
