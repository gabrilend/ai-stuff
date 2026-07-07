# 602 — The party-capability model: per-stat estimate and the level yardstick

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** Phase 5 (per-stat NCP levels). Independent of 601.
**Blocks:** 604 (re-estimation updates this), 606 (tuning reads this).

## Current Behavior

None of this exists yet. The Dungeon Master has no memory of what a party can do
and no way to express "they are that potentialed." There is nowhere to record
the demonstrated ceiling of a party, and — crucially — nowhere to hold the DM's
**conception of what a level means**, which the vision says the DM keeps
changing as parties conquer lairs.

## Intended Behavior

Two related structures the rest of the phase reads and writes:

- **Party-capability estimate.** Keyed **per stat** (the stat set is Phase 5's —
  ask the statistics utility for the names/count; do not hardcode). For each
  stat it holds: an estimated level, a confidence/uncertainty, and the highest
  performance actually demonstrated so far. It is built by reading Phase-5
  per-stat levels and blending in what the party has already shown. Designed
  **per-stat from the start** even though multi-character parties are a sequel
  feature — a lone NCP is simply a party of one, so no rework is needed later.

- **The level yardstick (the DM's "conception of a level").** A mapping from
  *raw demonstrated performance* to a *level number*. This is deliberately a
  separate thing from the capability estimate: the capability estimate says "how
  good is this party," the yardstick says "what does level N even demand." Issue
  604 stretches the yardstick; this issue only defines it and its initial shape.

Keeping the two apart lets the "remember" half (capability) and the "re-estimate
the meaning" half (yardstick) be reasoned about — and tested — independently.
That separation is the strategem
["Remember the demonstrated, re-estimate the meaning"](../strategems/README)
made concrete.

## Suggested Implementation Steps

1. Define the **per-stat capability estimate** structure: one entry per stat,
   each with estimated level, confidence, and demonstrated ceiling.
2. Write the **read-from-Phase-5** function that seeds the estimate from a
   character's (or party's) per-stat levels.
3. Define the **level yardstick** structure and a sensible **initial yardstick**
   (before any lair has been conquered).
4. Provide an **estimate-the-party** function combining seeded levels with any
   demonstrated ceiling into the current estimate (stage A of the datapath).
5. Provide small **accessors** — "how good at stat X," "what does the yardstick
   call level N" — so later issues never poke the structures directly.
6. Companion `*.info.md` describing the two structures and their accessors.
7. Tests: seeding from Phase-5 levels reproduces them; a party of one and a
   party of many share the same code path; the initial yardstick is well-formed;
   confidence starts appropriately low before any evidence.

## Meta

- **Per-stat now, parties later:** the per-stat shape is the whole point — it is
  what lets issue 606 tune a puzzle to the exact stat a party is weak in.
- **No nil stats:** every stat in the Phase-5 set gets an entry; a missing stat
  is an error to trace, not a nil to tolerate.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — "Data
  structures" (capability estimate, level yardstick).
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(Phase 5)* —
  the per-stat levels this reads.
- [strategems/README](../strategems/README) — the remember/re-estimate pattern.
