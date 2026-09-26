# crossing_sim.lua

The crossing-armies demo's game (issue 804), in the shape the server runs
(`net/server.lua`): two armies in a crowd (`runtime/crowd.lua`) sent to
each other's side; when no unit moves any more they are all sent back.

- **`crossing_sim.new(config) -> sim`:** `config.map` optional (a map
  module; default `net.arenas.crossing`). Returns `order`, `tick`,
  `visible`, `extras`, plus `crowd` and `crossings` (a count).
- **`crossing_sim.map(module) -> map, grid, west, east`:** the map, its
  walkable grid, and each army's starting cells.
- **Visible units:** x and z on the ground (y up), velocity, facing,
  `anim` 1 walking / 0 standing. Player 0 owns the west army (ids first),
  player 1 the east.
- **Orders:** move orders for the player's own units, as a group.
- **Extras:** one `paths` message per tick in which paths changed, the
  same for every player.
