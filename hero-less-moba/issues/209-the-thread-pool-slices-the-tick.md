# 209 — The Thread Pool Slices the Tick

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 103, 202, 204, 205, 206 |
| Blocks | 804 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | B1 — the wave size that decides how much slicing is worth doing |

## Current behavior

Every pass of the tick runs on one thread, walking thousands of independent
bodies one at a time — which is precisely the thing this project does not do.

## Intended behavior

A **pool of coroutines over shared memory**. Memory is allocated up front; the
work of filling it is handed out in slices, so a worker that finishes early takes
the next slice off the pile instead of idling behind the slowest one. This is a
distributed resolving of a stack of coroutines, not one thread per soldier.

Which passes are sliced, and why each one is safe:

| Pass | Sliced? | Why |
| --- | --- | --- |
| Apply commands | No | Mutates shared team and player state. Short. |
| Spawn | No | Allocates ids off a shared free list. Short. |
| Retarget | **Yes** | Reads the world; writes only each soldier's own target fields. |
| Move | **Yes, by lane** | See below. |
| Attack | **Yes** | Reads the world; writes only into distinct slots of the pending-damage buffer. |
| Resolve damage | No | Mutates health and the dying list. Short. |
| Reap | No | Frees ids, pays players, decrements wave counters. Short. |
| Phase | No | One team-level decision. |
| Snapshot | **Yes** | Pure copy into a preallocated buffer. |

The move pass has a constraint the others do not, and it comes from issue 206:
the queue only forms correctly if each lane is processed front-to-back, so that
the soldier ahead has already moved before the soldier behind checks the space in
front of it. **Slices must therefore be whole lanes**, not arbitrary index
ranges. Six lanes-worth of work — three lanes, two teams — is still six
independent slices, which is enough to keep a pool busy, and the constraint costs
nothing.

The buffered-damage design from issue 205 is what makes the attack pass sliceable
at all. That is worth stating in a comment beside the pool, because someone will
eventually propose applying damage directly to save an array, and the cost of
that proposal is this entire issue.

## Suggested implementation steps

1. Write the pool over LuaJIT coroutines with a shared work queue of (pass, start,
   stop) triples.
2. Size the pool from the machine's processor count, and make a pool of size one
   a legal configuration — the headless runner in batch mode wants many single-
   threaded matches rather than one many-threaded match.
3. Slice retarget, attack, and snapshot by index range; slice move by lane.
4. Write a test that runs the same match with pool sizes one, two, and eight and
   asserts the world hash is identical at every tick. **A parallel simulation that
   is not bit-identical to the serial one is broken**, and this test is the only
   thing that will notice.
5. Measure. If the pool is not faster than one thread at the target body count,
   say so in the balance ledger rather than keeping a pool that costs more than
   it saves.

## Related documents and tools

- [The simulation tick](../docs/003-the-simulation-tick.md)
- [The shape of the code](../docs/018-the-shape-of-the-code.md)
- The world-hash function from issue 107

## Still open

How many bodies are on the map at once? The pool's value depends entirely on the
answer, and a continuous surge stream could be a few hundred or a few thousand.
Also unresolved: if the simulation moves to fixed-point arithmetic for
determinism, the parallel-equals-serial test becomes much easier to satisfy, and
that decision is still open.
