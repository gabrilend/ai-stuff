# Issue 405f: Units Path Around Units

**Phase:** 4 - Runtime
**Type:** Implementation
**Priority:** Medium
**Parent:** 405 (collision detection)
**Dependencies:** 403 (A* pathfinding), 405d (movement with collision)
**Blocks:** 804 (the crossing-armies demo)

---

## Current Behavior

A* plans over terrain only: other units are not obstacles. When a moving
unit's step would overlap another unit, it slides along it or stops
(`collision`'s blocked move, 405d); units that overlap anyway are pushed
apart afterwards, and a separation force steers neighbours away (404d).
So units squeeze through crowds and shove each other, which Warcraft III
units don't.

## Intended Behavior

Warcraft III's behaviour, as the owner described it (2026-09-25): "units
path around each other and don't walk into the same area that another
unit is in." And on a moving unit meeting a friendly unit standing still:
"it paths around."

A self-contained crowd (`src/runtime/crowd.lua`), separate from the global
entity system so the server's thread can run it:
- **The ground:** a walkability grid (cells of a fixed size, true or false).
- **A unit:** id, position (x, y), radius, speed, and either standing or
  moving along a path of cell centres to its goal.
- **Standing units are obstacles to planning.** A* (`astar.find_path`,
  with `can_pass`) treats every cell a standing unit covers as blocked, so
  paths go around them.
- **No two units ever overlap.** Each tick, in unit id order, a moving unit
  takes its step only if it ends clear of every other unit (a spatial hash
  finds the neighbours). Otherwise it is **blocked** for that tick and
  waits. Nobody is pushed.
- **Blocked by a unit standing still:** re-plan now (it stopped after this
  unit's path was made).
- **Blocked by a moving unit:** wait a few ticks (it'll probably move on);
  if still blocked, re-plan treating that unit's cells as blocked too.
- **No path:** keep waiting and retry every so often; after a limit, give
  up and stand where it is (it then becomes an obstacle to others).
- **Arriving:** a unit whose goal cell is taken stops at the nearest free
  point it can reach.
- **What it reports per unit per tick:** position, velocity, facing,
  standing or walking, and whether its path changed (for drawing).
- Deterministic: same orders, same result (id order, no clock, no random).

## Suggested Implementation Steps

1. The crowd: grid, units, the spatial hash, orders (`move to`), the tick.
2. Tests, each a small scene: a unit paths around a standing unit; two units
   walking head-on in a corridor never overlap and both arrive; a unit
   blocked by a unit that then stops re-plans around it; an unreachable
   goal gives up and stands; two armies swap sides through a gap with no
   overlap at any tick, and every unit arrives or gives up.
3. Record the numbers (wait ticks, retry, give-up) as named values.

## Acceptance Criteria

- [ ] The tests above pass; no overlap at any tick in any of them
- [ ] `.info.md` beside each new source file

## Related Documents

- `issues/completed/404d-advanced-movement-behaviors.md` (separation and sliding, which this doesn't use)
- `issues/completed/405d-movement-collision-integration.md`
- `src/runtime/pathfinding/astar.lua`
