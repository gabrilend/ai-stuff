# circling_sim.lua

A stand-in game for the server (issue 803), until the real simulation is
joined up. Units circle the centre exactly as the renderer's ceramic test
units do; unit ids start at 1, and each belongs to player `(id - 1) %
players`.

- **`circling_sim.new(config) -> sim`:** `config.units`, `config.players`,
  and optionally `config.deaths` (tick → unit id). Returns the three
  functions the server calls (`order`, `tick`, `visible`) and `orders`,
  the orders kept.
- **`circling_sim.unit_record(id, t) -> unit record`:** unit `id` at `t`
  seconds, as the unit_states message carries it.
