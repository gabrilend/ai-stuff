# 605 — Fronts decided, and advancing outward

**Phase:** 6 — Foes in every direction
**Blocked by:** 602

**Blocks**: 607, 706
**Related documents:** docs/game-design.md (Center to outer)

## Current Behavior

Outposts can be destroyed but nothing follows.

## Intended Behavior

- When a foe's outpost at the current tier falls, the front is decided for
  the seat: the front moves to the next tier out, that band's income joins
  the treasury, and a level-up event is raised for both sides (phase 7 acts
  on it; until then it is logged).
- When a seat's forward base in that direction falls (or the foe reaches
  the band inside), the front is decided for the foe: it moves one tier in.
- If the foe reaches the hub, the game is lost.

## Suggested Implementation Steps

1. Front decision rules in the simulation.
2. Level-up event in the snapshot.
3. Tests: destroying a tier-1 outpost moves that direction to tier 2 and no
   other direction.

## Open questions

- What ends a game? (Open question 7.)
