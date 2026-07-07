# 607 — The lair generator (parent)

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** 601 (inference seam), 603 (modality), 606 (difficulty target),
Phase 4 (the puzzle/mechanism/trap primitives it composes).
**Blocks:** 608 (the loop / demo).
**Sub-issues:** [607a](607a-lair-spec-and-fixed-ratio.md),
[607b](607b-fresh-puzzle-instantiation.md).

## Current Behavior

None of this exists yet. There is no way to turn a difficulty target and a
modality into an actual lair. Phase 4's primitives sit unused, and the vision's
"the AI monsters make lairs; inside the lairs there are three-ish puzzles and
four combats exact" is not realized.

## Intended Behavior

The phase's centerpiece capability: **compose Phase-4 primitives into a lair**
that holds **~3 puzzles and exactly 4 combats** — the one ratio the vision fixes
as law — tuned to the difficulty target from issue 606 and built "through" the
modality from issue 603. Every lair is generated **fresh each visit** ("newly
created each time a group of adventurers wanders on"): never cached, never reused.

Split into two concerns:

- **607a — the lair spec and the fixed ratio.** The structured output shape and
  the composition that guarantees ~3 puzzles + exactly 4 combats, driven through
  the inference seam, validated so a bad generation errors rather than shipping a
  malformed lair.
- **607b — fresh puzzle instantiation.** Turning each puzzle spec into live
  Phase-4 mechanisms, triggers (including equal-seeming red-herrings), solutions,
  and the trap that fires on failure — freshly, for this visit only.

Splitting "decide the lair's shape" (607a) from "make its puzzles real" (607b)
keeps the fixed-ratio law and the Phase-4 wiring independently testable.

## Suggested Implementation Steps

See the sub-issues. This parent frames the centerpiece and holds the cross-links.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — stage C and
  the lair-spec / puzzle-spec / combat-spec structures.
- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md)
  *(Phase 4)* — the primitives composed here.
