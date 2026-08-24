# 105 — Randomness Comes From Named Streams

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 103 |
| Blocks | 107, 204, 303, 403, 605 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md) |
| Open questions | none |

## Current behavior

Nothing is random yet, and the temptation when something first needs to be is to
reach for a global generator seeded from the clock.

## Intended behavior

Randomness is **never** global and **never** taken from the system clock. The
world holds a small set of **named streams**, each a seeded generator that
advances only when its own system asks it to:

| Stream | Advanced by |
| --- | --- |
| `deck` | Building the one shared upgrade sequence, once, at match start. Both teams draw from it in the same order. |
| `surge[1]`, `surge[2]` | The deal order and starting lane when the chest is dealt across a surge spawn. One per team. |
| `boon[1]`, `boon[2]` | Which three boons each player is offered in the calm after a challenge. One per team. |
| `wander` | Where a tower's guards choose to patrol. |
| `tie` | Breaking exact ties in target selection. |

Two of those deserve a note.

**`deck` runs once.** It builds the match's upgrade sequence at start and is never
touched again — both teams read the same array at their own index. There is no
per-team draw stream, because there is no per-team randomness in drawing. See
issue 403.

**`surge` runs hardest.** It advances several times a second for the whole of a
siege-surge, which is far more than every other stream in the game combined.
That is exactly why it cannot be shared: if the deal borrowed anybody else's
stream, changing the surge spawn rate would silently change every boon offer for
the rest of the match.

Splitting them is the entire point. If all randomness came from one stream, a
cosmetic change to how guards wander would silently change which upgrades a team
draws, and no two runs of the "same" match would agree — not because anything
about the draw changed, but because something upstream consumed a different
number of values. With separate streams, the draw sequence for a given seed is
stable no matter what else in the project is edited.

Per-team `surge` and `boon` streams matter for the same reason at a smaller
scale: one team's luck must not perturb the other team's sequence. Drawing needs
no such protection, because both teams read the same deck at their own index and
there is no luck in it to perturb.

The match seed is chosen once at match start and written into the replay header.
Every stream's own seed is derived from it deterministically.

## Suggested implementation steps

1. Write a small generator — an xorshift or PCG variant, not Lua's `math.random`,
   which is neither seedable-per-instance nor guaranteed stable across builds.
2. Give it explicit state so many instances can exist side by side.
3. Write the stream table into the world, seeded by derivation from the match
   seed. Name the streams; never index them by number in calling code.
4. Add a debug mode that counts how many times each stream advanced per tick and
   asserts it against a recorded baseline, so an accidental new consumer of a
   stream is caught the day it appears rather than the day someone notices two
   replays disagree.
5. Write a test: run a match twice from the same seed and assert every stream's
   value sequence is identical.

## Related documents and tools

- [The simulation tick](../docs/003-the-simulation-tick.md)

## Settled

Two streams changed since this issue was first drafted: `draw` became **`deck`**
and stopped being per-team, and **`surge`** was added. Both are in the table
above. The catalogue question this issue used to raise is answered — with
replacement, duplicates stack, one shared sequence for both teams. See issue 403.

## Still open

Nothing. The catalogue question this issue used to raise — with replacement or a
depleting deck — was answered as with replacement, duplicates stack, one shared
sequence for both teams.
