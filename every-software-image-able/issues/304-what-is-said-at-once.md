# 304 — What is said at once, and what is fetched

## Current behavior

The instruction, the patterns and the device descriptions together are far larger
than anything the machine can hold in one thought. Nothing decides which part it
wakes up holding.

## Intended behavior

A small thing said at the start, and everything else reachable when it becomes
relevant.

## Suggested implementation steps

1. Decide what has to be in the first thought. The candidates are the ordering
   that cannot be rearranged, the two prohibitions, and how to ask for anything
   else. Everything beyond that competes with the machine's actual work for room.
2. Provide retrieval as a hand: ask for the pattern about X, ask for the
   description covering this device class, ask what is known about this part. This
   is the seed's version of what `docs/005` calls cognition space — not a memory
   limit but a retrieval problem, and the answer to it is an index searchable by
   task rather than browsable by name.
3. Build the index over the payload rather than expecting the model to remember
   what exists. It should be able to ask what it is carrying.
4. Solve this together with the context question in `105`. They are the same
   problem seen from two sides: what to drop when the thinking is full, and what
   to load when something becomes relevant. Answering them separately produces two
   mechanisms that disagree.
5. Make the retrieved thing say where it came from, so the machine can tell what
   it was told by people from what it worked out itself. That distinction matters
   the first time a carried description turns out to be wrong.

## Blocks

Phase 6.

## Blocked by

`105`, `301`, `302`, `303`.

## Related documents

`docs/005-datapath-the-four-rungs.md` — cognition space, and the index searchable
by task.
