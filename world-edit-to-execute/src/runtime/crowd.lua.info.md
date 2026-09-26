# crowd.lua

Ground units that path around each other and never overlap, as Warcraft
III's do (issue 405f). Stands alone (no global entity system), so the
server's thread can run one. Deterministic: id order, no clock, no random.

- **`crowd.new(grid, cell_size) -> crowd`:** `grid[y][x]` booleans (true:
  walkable), from 1; `cell_size` world units a cell.
- **`crowd:add(id, x, y, radius, speed)`:** a standing unit; `speed` in
  world units a second. Raises on a repeated id.
- **`crowd:move(id, x, y)`**, **`crowd:move_group({{id, x, y}, ...})`:**
  orders; a group is all marked moving before any plans.
- **`crowd:tick(dt)`:** one tick, every unit in id order.
- **`crowd:any_overlap() -> a, b`:** the first overlapping pair (tests).
- **A unit's fields:** `x`, `y`, `vx`, `vy`, `facing` (radians), `moving`
  (bool), `gave_up` (bool), `path` (list of `{x, y}`), `step`,
  `path_changed` (bool: set when the path changes, and left set until whoever reads it clears it), `radius`, `speed`, `goal_x`, `goal_y`.
- **The rules:** a step is taken only if it ends clear of units and walls;
  blocked by a standing or stalled unit → re-plan around it every few
  ticks; by a moving one → wait (longer for higher ids), then re-plan with
  it as an obstacle; goal taken → nearest free cell, looked at again on
  arrival; goal unreachable → as close as it can get; stopped short only
  by moving units → wait and retry; can't leave its cell → give up after
  5 s; no closer to the goal for 20 s → give up.
- **The numbers:** `WAIT_TICKS` 8, `STALL_TICKS` 4, `REPLAN_TICKS` 4,
  `RETRY_TICKS` 16, `GIVE_UP_TICKS` 312, `NO_PROGRESS_TICKS` 1250,
  `PROGRESS` 0.25, `PLAN_MARGIN` 0.15, `ARRIVE_EPSILON` 0.02.
- **Known limit:** two groups meeting head-on in a gap no wider than
  themselves jam for good.
