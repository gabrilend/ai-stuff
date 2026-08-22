# 304 — What is said at once, and what is fetched

## Current behavior

**Reopened on 2026-08-08. The machine can choose what it thinks with, and has
no policy for choosing.**

Everything below this paragraph holds and is tested. What it lacks is the part
that decides *when* to use any of it. `docs/013` has always said that running low
is a condition the machine can see and act on rather than a wall it hits, and the
only code behind that sentence is `052`'s `make_room`, which drops oldest-first
with no judgement when a request for room cannot be met. Its own comment calls
that a fallback -- "what happens when the machine did not choose in time" -- and
nothing anywhere defined "in time."

**The policy, decided 2026-08-08.** At **80% of the manageable budget** the
machine sweeps its own resident set and compacts to **60%**, or as low as **40%**
when the candidates are good enough. Full mechanism in `docs/013`, thresholds and
their reasoning in `docs/balance-updates.md`, and the four points that shape the
work:

**The system atoms are outside the arithmetic.** Percentages are taken over what
may be dropped, which makes the floor always reachable. The cost is that a machine
growing its own instruction shrinks its working budget where nobody is looking, so
**room-left has to report two numbers** -- manageable, and furniture.

**The workspace is the top 20% of the same context.** No second context and no
second cache; the cache is the largest allocation in the machine and a scratch one
would need a second. Because atoms join with nothing between them, the ranking
pass attends to the atoms it is ranking as its own prefix, with nothing copied.
Cleared when the sweep ends, which is free -- see the costing below.

**Every atom is ranked on two independent axes**, relevance to current work and
worth keeping at all, and disposed accordingly: keep, summarise, merge with
another, split in two, write out, or drop. **Drop leaves nothing** -- no content,
no index entry, no record.

**The sweep is a fixpoint, not a pass.** Rank, split whatever comes out mixed,
return both halves to the pool, rank again, dispose. Bounded by the workspace's
room, because a machine that can tidy forever will.

**Two operations are new.** *Split and rephrase* takes one atom to two, and the
rule is **first part and the rest** rather than n ways at once -- one boundary is
a question the machine answers well, where many boundaries at once means
committing to every cut simultaneously and one bad cut spoiling the rest. Each
part is rewritten to stand alone, because a fragment may open with a word
referring to the half it just lost. *Merge* exists already and gains a
requirement: two atoms become one **summarised as they join**, not concatenated.

**What the costing changes about the implementation.** The cache is valid only as
a prefix -- `061` keeps the longest common prefix and re-runs the engine from the
first divergence -- so touching an atom at position N costs *(final length − N)*
forward passes regardless of what else is touched at or after N. **Order the sweep
by position, not by badness.** Removing one stale early atom costs the same replay
as clearing half the context, so removals batch into one sweep; and once the
earliest hole is paid for, going deeper is free and in fact cheaper. The expensive
half is generation, which scales with how many atoms get rewritten.

**Stopping survives, demoted.** When a sweep ends still above the wall, the machine
says so and stops, as it did before. This answers `docs/008` question 26, and it is
the last thing `107a` was holding open.

---

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

### Added by the reopening, 2026-08-08

7. **Split the budget in two.** Room-left reports what is manageable and what is
   furniture, and every percentage in this policy is taken over the first. Do
   this before anything else; every other step is arithmetic over it.
8. **Add the two new operations**, split-and-rephrase and summarising merge,
   with the numbering rule that follows from the existing ones: split retires the
   parent's number and issues two, recording the parent, exactly as merge retires
   two and issues one.
9. **Write the ranking as two questions, not one.** Relevance and worth-keeping
   are separate verdicts and an atom needs both. A single "how good is this"
   score cannot distinguish the probe result that is precious and irrelevant from
   the scratch calculation that is relevant and worthless.
10. **Build the sweep as a fixpoint over the pool**, bounded by the workspace, and
    make the bound visible when it is hit rather than silently stopping early.
11. **Order disposal by position.** The replay cost is set by the earliest atom
    touched. A sweep that walks worst-first will pay the full bill and then pay it
    again next time; a sweep that batches from the earliest hole pays once.
12. **Test that a sweep leaves the machine thinking the same thing.** The point of
    compaction is that what survives still answers the same question — so the
    check worth having is a conversation continued across a sweep, not merely a
    count of bytes reclaimed.
13. **Test the unreachable floor.** Make the furniture large enough that 40% is
    impossible, and require the machine to report where it actually landed and
    stop, rather than believing it made room.

## Blocks

Phase 6.

## Blocked by

`105`, `301`, `302`, `303`.

## Related documents

`docs/005-datapath-the-four-rungs.md` — cognition space, and the index searchable
by task.
