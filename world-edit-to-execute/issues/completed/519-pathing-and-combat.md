# Issue 519: Units That Find Their Way and Fight

**Phase:** 5 (with Phase 7 gameplay pulled forward)
**Type:** Implementation
**Priority:** High
**Dependencies:** 518 (interface), 517a (terrain fields), B01 (A*)

---

## Current Behavior

Ordered units walk in straight lines through cliffs and sea; Attack only
walks; nothing has hit points; the pathing grid marks nearly all of DAoW
5.4b unwalkable; the Allies panel calls enemies allies.

## Intended Behavior

Units route around cliffs and deep water, and fight as WC3's do: acquire,
chase, turn, wind up, strike, recover, cool down; melee and missiles;
armour; death; creep camps; destructible buildings; health bars.

| Part | What | Where |
|------|------|-------|
| 519a | Pathing grid water fix; routes on A* without corner cutting, own line-of-sight smoothing, regions for "as close as it can get" | `runtime/pathfinding/grid.lua`, `astar.lua`, `src/demo/wc3map/pathing.lua` |
| 519b | Combat | `src/demo/wc3map/combat.lua`, `game.lua` |
| 519c | Bake groups (buildings re-bake when one falls), health bars, attack targeting, the dead leave selections | `src/render/geometry.{c,h}`, `ui/wc3/hud.lua`, `demo/wc3map/main.lua` |

## Acceptance Criteria

- [x] Deep water blocks, dry ground away from cliff edges never does (checked over all of Daow4.4)
- [x] Routes never cross blocked ground; unreachable targets end as close as possible
- [x] Melee and ranged attacks, WC3's armour formula, one strike per cooldown
- [x] Move ignores enemies, attack-move fights, hold position doesn't chase, creeps leash home
- [x] Units fall and are cleared; buildings can be destroyed and vanish from the view
- [x] `test_combat_pathing.lua`: 27 tests; full suite (108 files) passes
- [x] A scripted battle on DAoW 5.4b rendered and checked

## Implementation Notes

**Date:** 2026-09-29

### 519a: pathing

**Grid bug.** `grid.lua` blocked a tile when `water_level > 64`, but
`water_level` is the water's height, not its depth, so every tile with the
water flag and a level over 64 was blocked, wet or not: 4,610 walkable
cells on DAoW 5.4b against 102,570 of dry land. Depth is now the surface
over the ground (`w3e.water_z - ground_z`): 110,744 walkable (dry land and
shallow water). Two test files built fake tiles with `water_level` meaning
depth; their tiles now say the same depths in real levels.

**Corner cutting.** The project's A* and smoother (Bresenham) let a route
slip diagonally between two blocked cells that touch at a corner; a test
over 20 routes found 52 sample points on blocked ground. A* gains
`corner_cutting = false` (opt-in; the default keeps old behaviour), and
map routes use their own conservative line check for smoothing.

**Unreachable targets.** Walkable cells are labelled by connected region
at load (0.4 s with the grid on DAoW 5.4b, 108 regions); a target outside
the unit's region is swapped for its region's nearest cell. Routes take
2-80 ms.

### 519b: combat

Stats from the map where it sets them (`uhpm`, `ua1b/d/s`, `ua1c`,
`ua1r`, `uacq`, `udef`, `uaen`); the rest are stand-ins by archetype
(labelled in `combat.lua`). Armour: `0.06a / (1 + 0.06a)` reduction.
Sides: forces are allies only with their `allied` flag (DAoW 5.4b puts
the Scarlet Crusade and the Scourge in one force *not* allied: the
Allies panel showed them allied before this).

Whole map: 4,378 units simulate at about 3 ms a tick. Left alone, DAoW
5.4b stays nearly at peace (one skirmish in 20 s). Twelve Crusaders sent
at the nearest Scourge unit route there, kill it, run into the Scourge's
base, and lose ten of twelve within a minute.

### 519c: view

`render.geo_bake(size, group)` / `geo_unbake(group)`: doodads are group
0, buildings group 1, re-baked at most once a second when one falls.
Health bars over hurt or selected units, all of them with Alt; group icons
and hero buttons show real health. Food counts living units only.

### Not yet

- Doodads (trees, rocks) don't block pathing; buildings don't either.
- Units don't push each other apart (no collision between units).
- No experience, levels, abilities or corpses beyond a few seconds.
- The attack stand-ins and 64-deep wading are unmeasured (see 516d).
