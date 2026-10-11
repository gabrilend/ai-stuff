# 602 — A foe per direction, with an outpost at each tier

**Phase:** 6 — Foes in every direction
**Blocked by:** 601, 105

**Blocks**: 603, 605, 607
**Related documents:** docs/core-terms.md (direction, tier, front),
docs/game-design.md (Center to outer)

## Current Behavior

The only enemy is phase 3's scripted foe.

## Intended Behavior

- One foe per quadrant direction (by default; see open question). A foe has
  an outpost in each tier band of its direction, growing stronger outward,
  and its own treasury, factories and stands, using the same rules as a seat.
- A front is the pairing of a seat's direction and the foe's current tier.
- The snapshot lists each front: direction, current tier, both sides'
  strength.

## Suggested Implementation Steps

1. Foe table in the world (shares the seat machinery: treasury, factories,
   stands).
2. Outpost placement per band, strength by tier.
3. Front list derived each tick.

## Open questions

- How many foes, and are they teams? (Open question 6.)
