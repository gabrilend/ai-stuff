# 309 -- Taking a turn back

**Phase:** 3, the world ticks
**Blocked by:** [307](307-the-world-hashes-itself.md),
[308](308-the-turn-is-a-window.md)
**Blocks:** [310](310-the-phase-three-demo.md)
**Documents:** [the turn is a transaction](../docs/019-the-turn-is-a-transaction.md)
**Open questions:** [3.3](../docs/016-open-questions.md) is unanswered and this
issue **cannot be completed without it**.

## Current behaviour

Turns open, close, and resolve. Nothing can be undone.

## Intended behaviour

Restore the world to a turn's head and run that turn again.

Neither half is new work. A snapshot is a block copy, because the world is flat
arrays with no pointers. A replay lands in the same place every time, because the
tick is deterministic. **Undo did not need a mechanism -- it needed two mechanisms
built for other reasons to be aimed at each other.**

### Two things people mean by undo, and both are built

| | What happens | For |
| --- | --- | --- |
| **Re-declare** | Restore the head. Discard the declarations. Reopen the window. | A dropped connection. A misread situation. Everybody gets another go. |
| **Retcon** | Restore the head. Keep the declarations, change one, replay forward. | A GM ruled wrongly and wants everything downstream to follow the correction. |

The second is only possible because [306](306-the-command-log-is-the-replay.md) is
an editable, indexed record rather than an opaque stream. It is also the dangerous
one, because it changes what somebody did without asking them.

### The ring

One snapshot per turn head, depth from configuration. The cost is snapshot size
times depth -- a few hundred kilobytes times twenty is nothing.

The alternative, one snapshot every few turns plus replaying forward, trades memory
for a delay a person would feel on a deep rollback. **Keep the ring and pay the
memory.** If a world ever grows large enough to hurt, the hybrid is there.

What must be in a snapshot: the world blocks, the fog bitmaps, and the random
stream positions. Omitting the last makes a retcon draw different dice for reasons
nobody can see, which is the worst kind of wrong because it looks like the retcon
worked.

### Undoing the world is easy. Everyone already watched it happen.

**Viewers must be told, explicitly.** They received state during the turn being
undone. Silently sending a contradictory state and hoping the client sorts it out
produces a screen that flickers and a person who stops trusting it. There is a
message that says: the last stretch did not happen, here is the world again.

**Predictions die.** The client draws your own body ahead of confirmation, which is
what makes controls feel alive. A rollback throws all of it away at once and the
correction is large and visible rather than the usual imperceptible nudge.

**Fog does not un-see, and this is the blocker.** If a player walked down a
corridor in the turn being undone, their fog recorded it. Roll it back and the
program is consistent while the person still remembers the corridor. Leave it and
their map shows a place reached in a turn that never happened.

There is no right answer. **You cannot restore ignorance.** A rollback at a
tabletop has always been a social agreement rather than a memory wipe, and whichever
way this goes has to be chosen knowing that. [3.3](../docs/016-open-questions.md).

## Suggested implementation steps

1. Build the ring of snapshots, allocated once at startup from the configured
   depth.
2. Include fog and stream positions. Test that they are included by rolling back
   and asserting a subsequent draw matches the original run.
3. Implement re-declare first -- it is the simpler one and the one that will
   actually be used most.
4. Implement retcon on top of the log's edit-and-replay.
5. Write the recall message and make the client honour it. Do not skip this
   because the demo works without it; a client that is never told is a client that
   silently disagrees with the server.
6. Decide 3.3, implement it, and **comment the decision at the point where fog is
   or is not restored**, because whichever way it went, the other way will look
   like a bug to the next reader.
7. Write the companion `.info.md`.
8. Test: roll back and replay identically, asserting the hash matches at every
   tick. Roll back, change one instruction, and assert divergence begins exactly
   there.
