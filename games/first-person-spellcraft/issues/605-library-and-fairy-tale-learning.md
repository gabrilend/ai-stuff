# 605 — The library / fairy-tale learning mechanic (parent)

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** 602 (capability model); Phase 5 (NCP memory to write into).
**Blocks:** 606 (tuning discounts difficulty by what was learned), 608 (loop).
**Sub-issues:** [605a](605a-fairy-tale-corpus-and-library-visits.md),
[605b](605b-learned-context-in-difficulty.md).

## Current Behavior

None of this exists yet. NCPs never get smarter between lairs. The vision's
central softening mechanic — "for each visit to the library, they remember more
and more context ... then, the puzzles might be easier" — has no representation:
no fairy-tales, no accumulated learning, and nothing telling the DM that a party
now understands three-dimensional rotation or Newton's laws.

## Intended Behavior

A **side loop** that runs parallel to the main generate-attempt-re-estimate
loop. Each **library visit** absorbs one **fairy-tale** — a story that teaches
exactly one real mechanic ("mechanics of existence like three-dimensional
rotations (quaternions) or newtons laws of bio-impedence, and other such
magical-histories"). Absorbing a tale adds to a per-character **accumulated
learning ledger** that lives in **Phase-5 NCP memory**, and the **DM accounts
for it** by easing difficulty on the puzzle families that mechanic unlocks.

Because this is genuinely two concerns — *building and accumulating the corpus*
versus *the DM reacting to it* — it is split:

- **605a — the corpus and the accumulation loop.** The fairy-tale data table,
  the library-visit function, and the write-through into Phase-5 NCP memory.
- **605b — learned-context accounting.** The read side: how the ledger becomes a
  difficulty discount that issue 606 (tuning) applies.

Keeping data-generation (605a) apart from data-consumption (605b) follows the
project's "generate here, view there" separation, so a bug in one cannot corrupt
the other.

## Suggested Implementation Steps

See the sub-issues. This parent exists to frame the mechanic and to hold the
cross-links; do the work in 605a then 605b.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — the "side
  loop" in the loop diagram and the fairy-tale / learning-ledger structures.
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(Phase 5)* —
  the NCP memory the ledger is written into.
