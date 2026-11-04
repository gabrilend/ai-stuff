# 606 — Flanking forces, side to side

**Phase:** 6 — Foes in every direction
**Blocked by:** 601, 501, 304

**Blocks**: 607
**Related documents:** docs/core-terms.md (flank), docs/game-design.md

## Current Behavior

Flank left and flank right orders exist (304) but crossing into a
neighbour's quadrant has no special handling.

## Intended Behavior

- A stand can move sideways into a neighbouring seat's quadrant to help that
  front. It stays owned by its seat (only its seat can order it), shown with
  its seat color, and appears on the neighbour's map.
- A stand can be lent: an order hands it to the neighbour seat, after which
  only the neighbour orders it.
- Flanking a foe from the side gives a damage bonus against stands facing
  outward (a simple facing rule).

## Suggested Implementation Steps

1. Facing direction on stands; side-attack bonus in combat rules.
2. "Lend" order kind.
3. Tests: a lent stand refuses its old seat's commands.
