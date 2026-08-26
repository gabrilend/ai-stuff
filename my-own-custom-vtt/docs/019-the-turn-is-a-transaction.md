# The turn is a transaction

Turns are **simultaneous**, and they **can be rolled back**.

Everyone declares inside a window. When the window closes, everything resolves at
once. And if it resolved wrongly -- somebody misunderstood, a rule was misapplied,
a connection dropped mid-declaration, the GM changed their mind -- the turn can be
taken back and run again.

The server understands a turn as a **transaction**: a window with a snapshot at
its head, resolution at its close, and an undo. It does not understand initiative,
rounds, actions per turn, or whether acting twice is legal. Those are the
ruleset's. A ruleset that wants continuous play sets the window to one tick and
never rolls anything back, and the machinery below simply never fires.

## Simultaneous

Inside the window, commands accumulate. Nothing moves because somebody typed
first. When the window closes, every declared intention is resolved together.

This needed no new mechanism, because
[buffer-then-resolve](004-the-world-and-its-tick.md) was already the rule for
every pass in the tick: intentions are written into an array, and a second pass
settles them. Two bodies reaching for the same doorway both write, and the resolve
decides. Simultaneity at the scale of a turn is the same idea at a larger scale.

**Declarations are not revealed before resolution.** A viewer is not sent what
other viewers have declared. That is a filtering rule and it lives with all the
others in
[what a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md).

People will of course talk to each other while they declare. That is a tabletop
and talking is the point. The server's job is not to prevent it -- only to avoid
being the thing that leaks.

## Rollback

Undo is a snapshot at the head of the turn, plus a deterministic replay forward.

Both halves already existed and neither was built for this:

- **A snapshot is a write.** The world is flat arrays with no pointers, so
  capturing it is copying blocks of bytes -- no graph walk, no serialiser that
  knows every type. That was decided in
  [the world and its tick](004-the-world-and-its-tick.md) to make saving cheap.
- **A replay reproduces exactly.** The tick is deterministic, because the
  arithmetic is integer and every pass buffers before resolving. That was decided
  so a recorded session could be watched again.

Point those two at each other and you have undo. **Rollback did not need a
mechanism. It needed two existing mechanisms to be aimed at each other**, which is
the third time in this project that a decision made for one reason has turned out
to be the entire answer to a different question.

### How far back, and what it costs

A ring of snapshots, one per turn, depth from configuration.

The cost is the snapshot size times the ring depth, and the snapshot size is the
world -- a few hundred kilobytes for a dungeon. Twenty turns of history is a few
megabytes, which is nothing.

The alternative is one snapshot every so many turns plus replaying forward from
it, which trades memory for time and makes a deep rollback slow in a way a person
would feel. Given how small a world is, **keep the ring and pay the memory**. If a
world ever grows large enough for that to hurt, the hybrid is there.

### Two different things people mean by undo

| | What happens | What it is for |
| --- | --- | --- |
| **Re-declare** | Restore the head snapshot. Discard the declarations. Reopen the window. | Somebody's connection dropped. Somebody misread the situation. Everybody gets another go. |
| **Retcon** | Restore the head snapshot. Keep the declarations, change one, replay forward. | The GM ruled wrongly and wants the turn to have gone differently, with everything downstream following from the correction. |

The second is the interesting one and it is only possible because the command log
is a canonical, editable record of what everybody asked for. It is also the more
dangerous one, because it changes what somebody did without asking them.

## The hard part is not undoing the world

Undoing the world is a memcpy. The hard part is **everyone already watched it
happen.**

**What was sent must be recalled.** Viewers received state during the turn now
being undone. They have to be told, explicitly, that the last stretch did not
happen and here is the world again. Silently sending a contradictory state and
hoping the client sorts it out produces a client that flickers and a person who
does not trust the screen.

**Predictions are invalidated.** The client draws your own body ahead of the
server's confirmation, which is what makes the controls feel alive -- see
[the dynamic picture](012-the-dynamic-picture.md). A rollback throws all of that
away at once, and the correction will be large and visible rather than the usual
imperceptible nudge.

**Fog rolls back with the world.** A rollback is a full state restore: whatever
the world was at the head of the turn, every viewer's memory was too, and both go
back together.

Mechanically this is easy -- a fog record is a flat block of bits and restores the
way everything else does -- and it means nothing anywhere has to reason about a
memory that disagrees with its world.

**The cost is real and is not pretended away.** The person still remembers the
corridor. They looked at it. The screen now knows less than they do, and their own
map closes over a room they can describe out loud.

The reason it is still the right trade: the alternative is worse in a way that
never goes away. A fog that is not rolled back holds a place reached in a turn
that never happened, and it contradicts the world every time anybody walks there
again -- a permanent inconsistency, spreading, bought with one moment of honesty
about one person's memory.

What stays true underneath: **you cannot restore ignorance.** A rollback at a
tabletop has always been a social agreement, and the program's job is to make the
state consistent so that the people can do the rest. It is not pretending to wipe
a memory. It is putting the board back.

**And the numbers roll back with the geometry**, which for four phases they did
not. A ruleset's sheets are Lua tables rather than flat bytes, so an undone fight
used to put everybody back where they had been standing and leave them bleeding.

They are deep-copied at the head of every turn now. Anything that cannot be
copied — a function, a coroutine, a table that points back at itself — stops the
snapshot with a sentence naming where it was found, and **that turn is not
rollbackable rather than half-rollbackable.** The refusal happens before anything
is restored, so the world is left exactly where it was.

The full argument, including why the option that was rejected for "breaking
quietly" was rejected for a property of one implementation rather than of the
idea, is in [the rules layer](011-the-rules-layer.md) and in open question 14.1.

## What the record remembers

A rolled-back turn is still in the command log -- the log records what was decoded,
including what was later refused or undone, because a record that quietly omits
the parts somebody regretted is not a record.

Whether it reaches [the engraving](018-the-record-log-is-an-engraving.md) is a
different question, and the interesting answer is that **the number of rollbacks
might be the best statistic on the carving.** A session with eleven of them was a
session about something.

## Read next

- [The world and its tick](004-the-world-and-its-tick.md) -- the passes a turn is
  built out of.
- [Commands enter through one door](010-commands-enter-through-one-door.md) -- the
  log that makes a retcon possible.
- [Open questions](016-open-questions.md), section 3.
