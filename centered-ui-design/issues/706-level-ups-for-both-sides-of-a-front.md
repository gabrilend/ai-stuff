# 706 — Level-ups for both sides of a front

**Phase:** 7 — Growing outward
**Blocked by:** 705, 605, 603

**Blocks**: 707, 708
**Related documents:** docs/game-design.md (Center to outer)

## Current Behavior

Fronts are decided and a level-up event is logged (605), but nothing
happens.

## Intended Behavior

- When a front is decided, the seat whose direction it is and that
  direction's foe both level up: each gains resources (aether included) and
  receives a parity-matched offer.
- The foe's AI picks from its offer by its personality; the seat picks
  through the console (or its helper AI).
- The next tier's outpost is the same foe, levelled differently.
- The other seats see the level-up on their dashboards (so nobody is unaware).

## Suggested Implementation Steps

1. Level-up handler: resources, offer, pick window.
2. AI pick rules by personality weights.
3. Test: same seed, different picks → different tier-2 foes.
