# crowd.lua

Round ground units of several sizes that slide past each other, orbit
what's in the way, nudge idle allies aside and settle into groups, as the
owner describes Warcraft III's (issue 405f). Stands alone (no global entity
system), so the server's thread can run one. Deterministic: id order, no
clock, no random numbers.

- **`crowd.new(grid, cell_size) -> crowd`:** `grid[y][x]` booleans (true:
  walkable), from 1; `cell_size` world units a cell. Measures each open
  cell's clearance (distance to the nearest wall) once.
- **`crowd:add(id, x, y, radius, speed, team, path_radius)`:** a standing
  unit; `radius` is what it collides with, `path_radius` (optional:
  radius + `PATHING_EXTRA`) the larger circle others steer round (only
  when the crowd's `look_ahead` is above 0; off by default); `speed`
  in world units a second; `team` any value (only a unit's own team is
  nudged). Raises on a repeated id.
- **`crowd.look_ahead`** (per crowd; `LOOK_AHEAD`, 0, to start): how far
  ahead a unit steers round pathing radii; 0 is off.
- **`crowd:move_group(ids, x, y)`**, **`crowd:move(id, x, y)`:** orders; a
  lone unit is a group of one.
- **`crowd:tick(dt, deciding_order)`:** one tick in two phases: every
  moving unit decides alone from a snapshot of the tick's start (in
  `deciding_order`, a list of ids, if given: any order gives the same
  tick), then every unit settles in id order.
- **`crowd:snapshot()`**, **`crowd:decide(u, dt)`**, **`crowd:settle(u,
  dt, last_try)`**, **`crowd:do_requests(u)`:** the phases' parts, for a
  runner that splits the deciding across threads.
- **`crowd:pack(x, y, radii) -> places`:** places for circles of these
  radii packed round a point (for placing armies at the start).
- **`crowd:any_overlap() -> a, b`**, **`crowd:any_in_wall() -> u`:** the
  checks the tests hold it to.
- **A unit's fields:** `x`, `y`, `vx`, `vy` (per second), `facing`
  (radians), `radius`, `speed`, `team`, `moving`, `arrived`, `gave_up`
  (bools), `path` (list of `{x, y}`), `step`, `goal_x`, `goal_y`,
  `path_changed` (bool: set when the path changes, left set until whoever
  reads it clears it), `group`, `path_radius`, `backing`, `back_offs`.
  The crowd counts `back_offs_total`.
- **The rules** (each explained in the file): a step is taken only if clear;
  blocked by a unit → slide along it, keeping the goal-ward part, the same
  way round (head-on: to its right); by a wall → slide along the wall's
  edge; an idle ally in the way → nudged aside; two movers blocking each
  other → the higher id steps aside (or waits); sliding without progress →
  plan round the standing bundle; a group member meeting an arrived
  groupmate → slides inward while it can, settles once within the group's
  packed size (or after a while outside it); blocked beside its goal →
  stands; no closer for 2 s → gridlocked: backs off (and the stuck units
  round it too), then tries again, up to three times; no closer for 20 s
  → gives up. Before all of it, a unit steers to pass outside the pathing
  radii ahead of it.
- **The numbers:** `GAP`, `GIVE_WAY_TICKS`, `GIVE_WAY_FOR`, `BUNDLE_TICKS`,
  `BUNDLE_GAP`, `BUNDLE_KEEP`, `NUDGE_EVERY`, `NO_PROGRESS_TICKS`,
  `PROGRESS`, `ARRIVE`, `SLIDE_OUTWARD`, `SLIDE_AROUND`, `REPLAN_EVERY`,
  `SETTLE_TICKS`, `SETTLE_FAR_TICKS`, `PACKING`, `PATHING_EXTRA`,
  `LOOK_AHEAD`, `GRIDLOCK_TICKS`, `BACK_OFF`, `BACK_OFFS`; each commented at its
  definition. Changes go in `docs/balance-updates.md`.
