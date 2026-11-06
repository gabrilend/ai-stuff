# 603 — Armor Has Two Tracks

| | |
| --- | --- |
| Phase | 6 — Growth |
| Blocked by | 601 |
| Blocks | none |
| Files | `src/006-soldier.lua`, `src/008-movement.lua`, `src/011-hit-resolution.lua`, `src/026-first-person-view.lua` |

## Current behavior

Built in `src/006-soldier.lua` (rating, thickness, walk share,
awareness), `src/010-swings.lua` (thick armor's longer windups) and
`src/026-first-person-view.lua` (the edge glow reads the narrowed arc).
Tested in tests/035-command-and-growth.lua.

## Intended behavior

Armor follows the infantry-equipment-designer idea of separate tracks:

- **rating** — points; each point takes a configured percentage off every
  hit, capped. Raised by the armor perks.
- **thickness** — thin (attack at normal speed, walk at normal speed) or
  thick (+2 rating points, walk slower, swing windups a little longer).

Armor also narrows **awareness**: the 160 degree awareness arc loses a
configured number of degrees per rating point, never below the 90 degree view.
The first-person view's edge glow reads this narrowed arc.

## Suggested implementation steps

1. Derive rating, thickness penalties and awareness in the soldier
   constructor.
2. Test: thick armor slows walking and adds two points; awareness narrows
   with rating and stops at 90.
