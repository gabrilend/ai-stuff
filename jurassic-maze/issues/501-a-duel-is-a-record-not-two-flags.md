# 501 — A Duel Is A Record, Not Two Flags

| | |
| --- | --- |
| Phase | 5 — The Fencing |
| Blocked by | 301, 405 |
| Blocks | 502, 503, 504 |
| Reads | [fencing](../docs/017-fencing.md) |
| Open questions | none |

## Current behavior

Fencers meet and walk past each other.

## Intended behavior

When two fencers of opposing teams meet, a **duel** is created: a record holding
two body ids, their generations, a clock, and whose turn it is. Both bodies point
at it.

A record rather than fields on each body for one reason: **a duel has to end, and
ending it has to be one action.** Two bodies each holding "I am fighting that one"
can disagree — one dies and the other is left swinging at nothing — and every fix
for that is a check performed in two places that must stay in step. One record
with two references into it cannot get out of step with itself.

Both fencers stand still while it runs, facing each other; their locomotion does
not advance, because the duel owns them. This is the simplest thing that reads as
fencing from an isometric camera two hundred cells away. Real footwork, lunges
and retreats would be a great deal of machinery for detail a handful of pixels
tall.

The duel is the same shape as [a game](../docs/020-games-that-creatures-play.md)
and as the vine's entangle — a record referencing participants by id and
generation, holding a clock and a state. Building it that way now means the game
table in phase six is a generalisation rather than a rewrite.

## Suggested implementation steps

1. Write the duel store as its own flat arrays with a free list, exactly like the
   body store. Duels are objects with lifetimes; making them a second store
   rather than a table of tables keeps the memory story uniform.
2. Add the fencer-to-fencer entry to the meet table, opposing teams only.
3. Point both bodies at the duel and suspend their locomotion.
4. Write the generation check into the duel's own tick, dissolving it and
   releasing the survivor when a participant fails.
5. Test: a duel created and immediately having one participant killed dissolves
   the same tick and the survivor's locomotion resumes.

## Related documents and tools

- [Fencing](../docs/017-fencing.md)
- [Two bodies meeting](../docs/016-two-bodies-meeting.md)
