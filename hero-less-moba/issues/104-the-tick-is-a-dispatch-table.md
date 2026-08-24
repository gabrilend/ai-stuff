# 104 — The Tick Is a Dispatch Table

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 103 |
| Blocks | 106, 107, 108, 203, 205, 601 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md) |
| Open questions | none |

## Current behavior

Nothing advances. There is a world and no time.

## Intended behavior

The world advances in **fixed steps**. The step length is a constant, never a
measured frame time, and every duration in the game is a whole number of ticks —
an attack cooldown is "twenty-two ticks," not "0.7 seconds." This deletes the
family of bugs where two machines running the same match drift apart because one
of them had a longer frame.

The tick itself is an **ordered array of system functions**, each taking the
world. Not a hand-written sequence of calls. Adding a system is adding a row;
reordering is moving a row; and the order of the simulation becomes a piece of
readable data rather than something buried in a function body.

The order, and the reason each position is where it is:

| | System | Why here |
| --- | --- | --- |
| 1 | Apply commands | The only moment player intent can change anything. |
| 2 | Spawn | Everything that adds a body does it before anything looks for one. |
| 3 | Retarget | Every soldier without a living target finds one. |
| 4 | Move | Advance along lanes; resolve junctions. |
| 5 | Attack | Write into the pending-damage buffer. Never into health. |
| 6 | Resolve damage | Apply the buffer. Mark the dead. |
| 7 | Reap | Turn deaths into payouts, counters, and events. |
| 8 | Phase | Advance the match clock; start and end surges and challenges. |
| 9 | Snapshot | Stamp state for the viewer; append to the replay if recording. |

Steps 5 and 6 are split for a specific reason that is not an optimisation: two
soldiers on their last sliver of health, both off cooldown on the same tick,
should **both die**. Applying damage immediately means whichever the loop reached
first wins — and which one that is depends on slot ordering, which depends on
who died four minutes ago and freed a slot. That is real, reproducible,
completely unexplainable unfairness.

## Suggested implementation steps

1. Write the system array with all nine entries as stubs that do nothing, and a
   `step(world)` that walks it. Everything in phases 2 through 6 fills a stub in.
2. Add `world.tick`, incremented once per step.
3. Write a duration helper so no source file ever writes a raw tick count next to
   a magic number without a name.
4. Write a test that steps an empty world ten thousand times and asserts nothing
   allocated, nothing errored, and `tick` is ten thousand.
5. Leave a comment above the system array explaining what moving any row would
   break. The order is load-bearing and the next person to touch it will not know
   that unless it says so.

## Related documents and tools

- [The simulation tick](../docs/003-the-simulation-tick.md)

## Settled

Positions, health, and damage stay as **doubles**. The project is not lockstep and
machines are not required to agree bit for bit, so there is no fixed-point
rewrite — see [the simulation tick](../docs/003-the-simulation-tick.md).

**Time stays integer regardless.** Every duration is a whole number of ticks,
because that is about two machines agreeing on *when*, which they must, rather
than on *where*, which they need not.

Same-machine reproducibility is still the project's best regression test. It no
longer underwrites the network, and the comment beside the test should say so.

