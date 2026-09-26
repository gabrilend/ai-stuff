# crossing_sim.lua

The crossing-armies demo's game (issue 804), in the shape the server runs
(`net/server.lua`): two armies of mixed sizes packed round their home
points in a crowd (`runtime/crowd.lua`), each sent as a group to the other's
home; when no unit moves any more they are all sent back.

- **`crossing_sim.new(config) -> sim`:** `config.map` optional (a map
  module; default `net.arenas.crossing`). Returns `order`, `tick`,
  `visible`, `extras` (`config.per_army`, `config.two_radii` optional),
  plus `crowd`, `crossings` (a count) and
  `gave_up_last` (units that gave up in the last crossing).
- **`crossing_sim.map(module, per_army) -> map, grid`:** the map (the
  scaled one when `per_army` is given) and its walkable grid.
- **`crossing_sim.place(config) -> map, crowd, army_ids`:** both armies
  standing at home, no orders yet (the benchmark writes this as a scene).
- **Visible units:** x and z on the ground (y up), velocity, facing,
  `anim` 1 walking / 0 standing, `radius`, `team` (the player). Player 0
  owns the west army (ids first), player 1 the east.
- **Orders:** move orders for the player's own units, as a group.
- **Extras:** one `paths` message per tick in which paths changed, the
  same for every player.
