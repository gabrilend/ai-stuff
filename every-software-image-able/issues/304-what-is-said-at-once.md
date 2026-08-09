# 304 — What is said at once, and what is fetched

## Current behavior

**Done, and tested** -- `src/084`, checked by `src/085`, 43 of 43 on
2026-08-02.

The payload is atoms. The instruction is split at its own headings so the
boot set can be chosen finely -- one atom would mean waking holding all of it
or none. Patterns and descriptions are one atom each and none are resident,
because a pattern is relevant when the machine is about to build something of
that shape, which is not at boot. Every atom says where it came from.

The index, the fetching and the room it costs are all hands, so what the
machine is thinking with stays a decision it keeps making.

**The disk half that `105` left as a seam is closed here**: an atom written
out stops taking room and comes back exactly when fetched again.

**The boot set is a mutable file, and the machine can drop the prohibitions
from it.** Nothing prevents that, deliberately, and it is tested so nobody
later builds on the assumption that it is untrue.

One defect worth keeping: being held now and being in the boot set were
briefly one thing. They move independently -- fetching something does not
change what the next start wakes with, and rewriting the boot set does not
disturb the thought in progress. Reading one from the other made the boot set
unchangeable, which quietly turned this design most uncomfortable property
into something the machine could not do.

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
