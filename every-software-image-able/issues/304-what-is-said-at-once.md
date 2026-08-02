# 304 — What is said at once, and what is fetched

## Current behavior

The instruction, the patterns and the device descriptions together are far larger
than anything the machine can hold in one thought. Nothing decides which part it
wakes up holding.

## Intended behavior

A small thing said at the start, and everything else reachable when it becomes
relevant.

## Suggested implementation steps

1. **Carry the payload as atoms** rather than as one block of text. The
   instruction, each pattern, each device description — one atom each, grouped by
   topic, so the machine can carry and drop them individually (`docs/013`).
2. Write the default initialising context: the file naming which atoms are
   resident when the machine boots. The candidates for that set are the ordering
   that cannot be rearranged, the two prohibitions, and how to ask for anything
   else. Everything beyond that competes with the machine's actual work for room.
3. **The file is mutable**, which means the machine can change what it wakes up
   believing — including the prohibitions, which are atoms like everything else.
   That follows from everything about the machine being mutable, and it should be
   implemented rather than quietly prevented. It is named in `docs/013` as
   something nobody has decided is correct.
4. Complete the disk half of the atom operations that `105` had to leave as a
   seam: writing an atom out and recalling it. Phase 1 has no storage; by here
   there is.
5. Build the index over the whole payload rather than expecting the model to
   remember what exists. It should be able to ask what it is carrying.
6. Make every atom say where it came from — carried on the chip, written by the
   machine, or arrived on a channel. That distinction matters the first time a
   carried description turns out to be wrong.

## Blocks

Phase 6.

## Blocked by

`105`, `301`, `302`, `303`.

## Related documents

`docs/005-datapath-the-four-rungs.md` — cognition space, and the index searchable
by task.
