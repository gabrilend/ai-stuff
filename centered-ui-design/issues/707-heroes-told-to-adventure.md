# 707 — Heroes told to adventure

**Phase:** 7 — Growing outward
**Blocked by:** 706, 301
**Blocks**: 708
**Related documents:** docs/core-terms.md (hero), docs/game-design.md
(Center to outer, and below), /mnt/mtwo/notes/symbeline-aspects (lanes
"scaled not just laterally, but linearly ... deepening level zones")

## Current Behavior

There are no heroes.

## Intended Behavior

- Heroes are special single-unit stands bought from the heroes budget, with
  gear from the choice catalog.
- A hero is told to adventure like any order: map click on the hero, then
  the adventure button. Assumed: each adventure order sends the hero one
  tier deeper past the current front than its last adventure (open question
  3). It fights generated encounters scaled to the depth and returns with
  aether and occasionally a held choice.
- Deeper is riskier and richer. A hero lost far out is gone.
- A dial shows each hero's current depth; the player never turns it.

## Suggested Implementation Steps

1. Hero stands; adventure verb; encounter resolver (data side, seeded).
2. Depth dial (view side), read from the snapshot.
3. Tests: reward and risk both rise with depth across many seeded runs.

## Open questions

- How is depth chosen without a dial the player turns? (Open question 3.)
