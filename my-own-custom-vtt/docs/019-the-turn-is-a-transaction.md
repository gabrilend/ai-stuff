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

**Fog does not un-see.** This is the one that has no clean answer.

If a player walked down a corridor during a turn that is now being undone, their
fog memory recorded it. Roll the fog back with the world and the program is
consistent -- but the person still remembers the corridor, because they looked at
it. Leave the fog alone and the program is honest about what they know -- but now
their map shows a place they reached in a turn that never happened, which will
contradict the world the moment somebody walks there again.

The design has to pick one and **be honest that neither is right**, because the
real situation is that you cannot un-see something, and a rollback at a tabletop
has always been a social agreement rather than a memory wipe. The program can
restore state. It cannot restore ignorance. Which way this goes is
[open question 3.3](016-open-questions.md).

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
