# 109 — Snapshots, hashes, and replays

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 105, 107 |
| Blocks | 110, 111, 601, 701, 705, 706, 801 |
| Reads | [the tick and the timers](../docs/003-the-tick-and-the-timers.md) |
| Open questions | F2 |

## Current behavior

Nothing. The tick document says the world is fingerprinted at the end of every
tick and copied out for a viewer, and nothing does either. The phase 1 test
program looks for a source file whose stem is `snapshot` and asserts that two
runs from the same seed and commands produce the same hash at every tick.

## Intended behavior

Three things, all reading the world's layout table and nothing else:

**The hash.** `hash(world)` folds every number in every array of every group,
in layout order, into one thirty-two-bit fingerprint, along with the tick and
every stream's state. Integers fold as they are; doubles fold by their bit
pattern, read through a foreign-function union, so two doubles that print the
same but differ in the last bit hash differently — which is exactly the
disagreement lockstep needs to catch. Two machines compare one number and know
whether they agree.

**The copy.** `copy(world)` returns a snapshot: a whole copy of every array,
plus the tick, in the same layout. A viewer reads snapshots and never the live
world; the copy is the boundary between the simulation and everything that
looks at it. Copying every tick is affordable because the arrays are flat and
the copy is one memory move per array.

**The replay.** `record(world, path)` opens a plain-text log: a header holding
the seed, a stamp of the parameter tree, and the tick rate; then every accepted
command as the door queues it, one per line; and every so many ticks the hash
of that tick. `replay(path)` reads it back into a table. A runner that feeds
the recorded commands to a fresh world and compares hashes at the recorded
ticks has replayed the match, and a mismatch names its tick.

The parameter stamp is computed from the parameter tree rather than written
down, so a replay recorded before a balance change is refused rather than
silently played wrong. The log is text so that two of them can be diffed.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Fingerprints, copies, and records the world." snapshot`.
2. Write the fold: a thirty-two-bit hash step through the `bit` library, and the
   union that reads a double's bits.
3. Write `hash(world)` over the layout table, then the tick, then the streams.
4. Write `copy(world)` over the same table.
5. Write the parameter stamp as a hash over the parameter tree's keys in sorted
   order, so that table iteration order cannot change it.
6. Write `record(world, path)` and the hook the door calls for each accepted
   command, and `replay(path)`.
7. Fill the companion with the log's line formats.

## Related documents and tools

- [The tick and the timers](../docs/003-the-tick-and-the-timers.md)
- [The views](../docs/010-the-views.md)
- [Other players](../docs/011-other-players.md)
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)

## Still open

- F2: whether doubles agree across the two targets. The hash is where the
  disagreement would show, and the test that answers it is one match run on
  both with hashes compared, which waits on the handheld build.
