# 107 — Snapshots and Replays

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 104, 105, 106 |
| Blocks | 109, 701, 801, 804 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md), [the simulation tick](../docs/003-the-simulation-tick.md) |
| Open questions | none |

## Current behavior

Snapshots are built: two frames, indexed by soldier id so that matching a body
across them is reading the same index twice, with the viewer's blend clamped so it can
be behind and never ahead.

**The replay log is not built.** Under a rotating authority a replay has to record the
accepted snapshots as well as the commands, and nothing records either yet.

## Intended behavior

Two outputs, from the same place in the tick, serving two different readers.

### A snapshot

A flat read-only copy of everything a viewer needs, stamped at the end of each
tick. Not the whole world — a viewer has no use for cooldown timers, target
generations, or the pending-damage buffer. It carries positions, health
fractions, team and flavour, structure health, the chest and its slot
assignments, lock and objection state, push depths, per-player resource, the phase,
every player's cursor, and the events raised this tick.

The viewer keeps the two most recent snapshots and interpolates between them. It
is allowed to be behind. It is **never** allowed to be ahead — a viewer that
extrapolates shows things that did not happen, and in a game where a player judges
a lane by looking at where the frontline is, showing a frontline that is not
really there is a lie that changes decisions.

### A replay

**A replay is the seed, the command list, and the accepted state snapshots.**

The first two would be enough under lockstep, where nothing outside the
simulation ever writes into it. This project is not lockstep. Machines reconcile
continuous state on a cycle with the authority rotating between players, so the
world is periodically overwritten from outside — and replaying commands against a
seed reproduces *a* match rather than *the* match. See
[players, teams, and commands](../docs/016-players-teams-and-commands.md).

So a replay records three streams:

| Stream | Rate | Size |
| --- | --- | --- |
| The seed and header | once | tiny |
| Commands | a few per second across six players | 16 bytes each |
| Accepted authority snapshots | about one per second | the large one |

The snapshots are what makes a replay heavy, and they are also what makes it
honest. Delta-encoding each against the previous is the obvious first move.

## Determinism is still worth testing

It buys less than it would under lockstep, and it is still the most valuable
regression test in the project:

> Same machine, same binary, same seed, same commands, same result — tick for
> tick.

That fails the day someone introduces a global random call, an iteration over a
hash table whose order is not stable, or a dependence on wall-clock time. It
fails immediately rather than three weeks later. What it no longer does is
underwrite the network, and this issue should say so in a comment beside the test
so nobody mistakes a passing determinism test for cross-machine agreement.

## Suggested implementation steps

1. Write the snapshot record as preallocated flat arrays, double-buffered. Never
   allocate during a tick.
2. Write the snapshot system as the ninth entry in the tick's dispatch table.
3. Write the replay header: match seed, rules-version stamp, map parameters,
   player count, and each player's commander.
4. Write the replay as three interleaved streams, with the snapshot stream
   delta-encoded against the previously accepted snapshot.
5. Write the same-machine determinism test and put it in the build, with the
   comment above.
6. Write a world-hash function — one integer summarising the whole world — so
   that the test can report *which tick* diverged, not merely that one did. The
   same hash is useful in the network layer as a cheap "how far apart are we"
   measurement, even though it is not used to halt anything.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- [The simulation tick](../docs/003-the-simulation-tick.md)
- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)
- The determinism test and world-hash function (this issue creates both)

## Still open

A replay is now large rather than tiny, which changes E5 from a filing question
into a storage one: where they live, how long they are kept, whether the snapshot
stream can be thinned on write, and whether an old replay should be refused
loudly or migrated.
