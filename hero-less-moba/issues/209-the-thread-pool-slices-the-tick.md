# 209 — The Thread Pool Slices the Tick

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 103, 202, 204, 205, 206 |
| Blocks | 804 |
| Reads | [the simulation tick](../docs/003-the-simulation-tick.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | none |

## Current behavior

Every pass of the tick runs on one thread, walking thousands of independent
bodies one at a time — which is precisely the thing this project does not do.

## Intended behavior

A **pool over shared memory**. Memory is allocated up front; the work of filling it
is handed out in slices, so a worker that finishes early takes the next slice off
the pile instead of idling behind the slowest one. Slices off a pile, not one
worker per soldier.

This said "a pool of coroutines" and that part is wrong — coroutines in Lua all
run on one operating-system thread and never hold it at the same time. What the
workers actually are is the open question this issue now carries. Everything below
about **which passes may be sliced and why** is unaffected by that answer and is the
larger half of the work.

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

1. Write the pool with a shared work queue of (pass, start, stop) triples, with the
   thing that executes a slice behind one small interface — so that answering H3
   later changes one file rather than the tick.
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
- The world-hash function from issue 107, which is built — step 4's
  parallel-equals-serial test can compare a whole world in one integer

## Still open

**How many bodies are on the map at once — measured.** `./run-prototype headless`
now prints a census: how crowded the field is on average and at worst, broken down
by phase, with the tick the worst moment happened on. Run it rather than quoting a
figure from here; the moment anything about spawning changes, a written number is
a lie and the census is not.

The shape of the answer, which is what this issue needed: it is **hundreds, not
thousands**, and it is very uneven — an ordinary phase is a fraction of a challenge.
The pool has to be worth having at the low figure, not the high one, because that is
where a match spends most of its time.

**Fixed-point is no longer a live question.** It was raised here as a way to make
the parallel-equals-serial test easier to satisfy. It is not needed: two machines
are not required to agree, and the same machine agrees with itself already — see
[the simulation tick](../docs/003-the-simulation-tick.md). The world hash this
issue's step 4 calls for is built, in issue 107, and it compares a whole world in
one integer.

**And the real question, which this issue does not currently ask.** The plan says a
pool of coroutines, and coroutines in Lua all run on one operating-system thread.
They interleave; they do not run at the same time. A pool of them over a
CPU-bound tick is a more complicated way to take exactly as long.

Genuine parallelism here means one of:

1. **Keep the slicing, run it serially, and say so.** The work of cutting each pass
   into independent slices is real and is most of this issue — it forces the
   question of what each pass may touch, and the answer is written down in the table
   above. Executing those slices in parallel then becomes a contained change rather
   than a rewrite. The honest version of this is a pool whose size is a number and
   whose speed at every size is the same, recorded as such.
2. **Separate Lua states, sharing memory through the FFI.** Real threads. The world
   stops being tables of numbers and becomes FFI arrays, because separate states
   cannot share a table. That touches every file that reads a body.
3. **Decide the pool is not worth it at this body count and close the issue,**
   recording the measurement as the reason.

This needs a person, and it is asked in
[open questions](../docs/020-open-questions.md), H3.
