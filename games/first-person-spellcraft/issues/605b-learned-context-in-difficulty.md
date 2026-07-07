# 605b — Learned-context accounting: turning the ledger into a difficulty discount

**Phase:** 6 (AI Dungeon Master & Learning)
**Parent:** [605](605-library-and-fairy-tale-learning.md)
**Depends on:** 605a (the ledger to read).
**Blocks:** 606 (tuning applies this discount).

## Current Behavior

None of this exists yet. Even once the ledger from 605a records that a character
knows quaternion rotation, nothing makes the relevant puzzles easier — the DM
has no read side for learned context, so the vision's "then, the puzzles might be
easier" does not happen.

## Intended Behavior

The **data-consumption** half of the library mechanic. A read-only function that
takes a character's learning ledger and a puzzle family and returns a
**difficulty discount** — how much the DM should ease a puzzle of that family
because its enabling mechanic has been learned. Kept strictly separate from the
write side (605a) per "generate here, view there": this file never mutates the
ledger, it only reads it.

The discount is graded, not binary: knowing the exact enabling mechanic gives
the full discount; knowing a related mechanic gives a partial one; knowing
nothing relevant gives none. The output is consumed by issue 606 (tuning), which
folds it into the per-stat difficulty target so a well-read party genuinely faces
easier puzzles in the families they have studied — while still meeting fresh
challenge in families they have not.

## Suggested Implementation Steps

1. Define the **difficulty-discount** value and its range (none → partial →
   full).
2. Write **discount-for-family**: given a ledger and a puzzle family, compute the
   discount from which enabling/related mechanics are known.
3. Keep the mapping from **mechanic → puzzle family** shared with 605a's corpus
   (one source of truth) so the write and read sides never disagree.
4. Ensure the function is **pure/read-only** over the ledger; add a comment on
   *why* (the separation prevents a consumption bug from corrupting learning).
5. Companion `*.info.md` describing the discount function.
6. Tests: a known mechanic yields the full discount on its family; a related
   mechanic yields a partial discount; an unstudied family yields none; the
   function never mutates the ledger.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — "account for
  learned context" in the functions list; the side loop feeding stage B.
- Issue 606 (difficulty tuning) is the consumer of this discount.
