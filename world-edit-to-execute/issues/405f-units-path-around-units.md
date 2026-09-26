# Issue 405f: Units Path Around Units

**Phase:** 4 - Runtime
**Type:** Implementation
**Priority:** Medium
**Parent:** 405 (collision detection)
**Dependencies:** 403 (A* pathfinding), 405d (movement with collision)
**Blocks:** 804 (the crossing-armies demo)

---

## Current Behavior

Built (2026-09-25): `src/runtime/crowd.lua`, tested by
`src/tests/test_crowd.lua` (all pass). Two armies of 40 swapping sides
through a 12-cell gap: no overlap at any tick, about 80% arrive at or
beside their goals, the rest give up after 20 s without getting closer,
about 0.5 ms a tick.

What the first versions taught, each now a rule in the file:
- **Waiting on a waiting unit deadlocks.** A unit blocked by a "moving"
  unit that was itself waiting waited forever; the armies gridlocked within
  a second. Now a moving unit that hasn't moved for 4 ticks counts as
  standing.
- **A group ordered one by one weaves around itself** (later members were
  still standing when earlier ones planned). Now `move_group` marks them all
  moving first.
- **A cell whose centre is just clear can still block the first step** of a
  unit starting off-centre; planning keeps 0.15 of a cell further away.
- **"As close as it can get" made jams permanent:** units stopped short of
  a goal behind a passing crowd and stood there for good. Now a unit that
  stopped short only because of moving units waits and tries again.
- **Blocked ticks in a row don't measure being stuck:** in a crowd a unit
  steps, is blocked, re-plans and steps again forever. Giving up is now
  measured as getting no closer to the goal, and needs 20 s: at 5 s or
  10 s half the armies gave up while queued.
- **Known limit:** two 8-deep armies meeting head-on in an 8-cell gap jam
  for good (each front stalls against the other and walls off the gap).
  A "keep right" planning cost was tried and removed: it only bends paths
  that already bend, and Warcraft III isn't known to do it.
- The project's general A* (`runtime/pathfinding/astar.lua`) wasn't used:
  its diagonal steps cut past wall corners, which a round unit would clip.

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
- **Standing units are obstacles to planning.** A* (its own, eight
  directions, no corner cutting) treats every cell a standing unit covers
  as blocked, so paths go around them.
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
   goal is approached as closely as possible; a boxed-in unit gives up;
   two armies swap sides through a gap with no
   overlap at any tick, and every unit arrives or gives up.
3. Record the numbers (wait ticks, retry, give-up) as named values.

## Acceptance Criteria

- [x] The tests above pass; no overlap at any tick in any of them
- [x] `.info.md` beside each new source file

## Open Questions

- **The narrow-gap jam** (asked 2026-09-25): two groups meeting head-on in
  a gap no wider than themselves jam for good. What does Warcraft III do
  there: jam too, or does something let one side through (units briefly
  allowed to overlap allies, one side yielding)?

## Related Documents

- `issues/completed/404d-advanced-movement-behaviors.md` (separation and sliding, which this doesn't use)
- `issues/completed/405d-movement-collision-integration.md`
- `src/runtime/pathfinding/astar.lua`
