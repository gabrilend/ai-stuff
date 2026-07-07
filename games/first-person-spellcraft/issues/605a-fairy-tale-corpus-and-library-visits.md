# 605a — The fairy-tale corpus and the library-visit accumulation loop

**Phase:** 6 (AI Dungeon Master & Learning)
**Parent:** [605](605-library-and-fairy-tale-learning.md)
**Depends on:** 602 (capability model); Phase 5 (NCP memory).
**Blocks:** 605b.

## Current Behavior

None of this exists yet. There is no library, no fairy-tales, and no per-
character record of what has been learned. NCP memory (Phase 5) holds companion
speech but has no slot for absorbed mechanics.

## Intended Behavior

The **data-generation** half of the library mechanic (the reacting half is
605b). Three pieces:

- **The fairy-tale corpus** — a data table, one row per tale. Each row: a title,
  the single **real mechanic** it teaches (three-dimensional rotation /
  quaternions, Newton's laws, bio-impedance, and more), the **puzzle families**
  that mechanic unlocks, and the **stats** it bolsters. It is data, not code, so
  tales can be added freely; the count comes from the statistics utility, never
  hardcoded.

- **The accumulated learning ledger** — a per-character structure (persisted in
  Phase-5 NCP memory) listing which tales have been absorbed, and therefore
  which mechanics the character now "knows."

- **The library-visit function** — given a character and a tale (or a policy for
  which tale to draw next), it **absorbs** the tale: appends to the ledger and
  **writes through into Phase-5 NCP memory** so the learning persists between
  lairs exactly like companion speech does. Absorbing the same tale twice is
  idempotent (knowing quaternions twice is still knowing quaternions), and this
  is asserted, not silently tolerated.

## Suggested Implementation Steps

1. Define the **fairy-tale** row structure and seed the **corpus table** with
   the vision's named mechanics (quaternion rotation, Newton's laws,
   bio-impedance) plus room for more.
2. Define the **learning ledger** structure and its accessors ("does this
   character know mechanic M," "which puzzle families are eased").
3. Write the **library-visit / absorb** function that appends to the ledger and
   writes through to Phase-5 NCP memory; make re-absorption idempotent.
4. Provide a **draw-next-tale** policy (which tale to teach next) kept swappable
   — e.g. teach toward the party's weakest puzzle family.
5. Companion `*.info.md` describing the corpus, the ledger, and the visit
   function.
6. Tests: absorbing a tale appears in the ledger and survives a round-trip
   through NCP memory; re-absorbing is idempotent; an unknown tale errors; the
   corpus count matches the statistics utility.

## Meta

- **Data, not code:** the corpus grows by adding rows; nothing in the loop
  changes when a new fairy-tale is written.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — the
  fairy-tale and learning-ledger structures.
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(Phase 5)* —
  NCP memory persistence.
