# 031-carving

Six passes from a seed to a maze.

Read this page rather than the source, and read
[carving the maze](../docs/003-carving-the-maze.md) before either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `generate(root, params, streams)` | project root, a checked parameter table, a stream set | the stone store, and a report table |
| `is_room(x, y)` / `is_link(x, y)` | | which job a cell has in the lattice |
| `link_height(ha, hb)` | | what height the cell between two rooms takes |
| `floor_components(...)` | | labels the connected pieces of floor |
| `DIRECTIONS` | | the four compass steps, as `{dx, dy}` pairs |

## The passes, in order

| Pass | What it does |
| --- | --- |
| one, terraces | nested slabs, each smaller than the last, plus scattered outcrops. Room heights only; nothing knows a maze exists. |
| two, staircases | **placed before the maze is carved.** A flight is a run of rooms whose heights step by two, with the links between them forced open. |
| three, the maze | a randomized depth-first **forest** over the rooms, restarted from every room it has not reached, then braiding |
| four, realising | heights become columns; walls take the tallest nearby room's height plus the wall rise |
| five, repair | the connectivity check, which on a healthy maze finds nothing to do, and the orphan fill |
| six, walls | re-measures every wall against whatever floor is beside it now |

## The report it fills in

`seed`, `width`, `depth`, `layers`, `rooms`, `rooms_reached`, `staircases_cut`,
`extra_staircases`, `staircase_sites`, `orphans_filled`, `walls_raised`,
`floor_pieces`, `height_histogram`, and the repair pass's `repair_flights`,
`stair_attempts_made`, `stair_unbuildable`, `stair_unhelpful`.

## Four things that were wrong first

Each of these produced a maze that was confidently broken, and each is guarded by
a comment at the place it went wrong.

- **Scattered rectangles do not make terraces.** They make noise: every edge is a
  height change, the edges land everywhere, and the result renders as a field of
  cubes at a hundred different heights.
- **Staircases cut into a finished maze sever it.** The flight lands correctly
  and drops the room it passes through three layers below the corridor that room
  belonged to. Placing them first costs nothing.
- **Flooding through every cell** joins two terraces by a chain of wall tops —
  a route along the tops of the walls, which nothing can reach and nothing would
  take. `floor_components` floods through floor only.
- **Counting pieces** rejects a repair flight that joins two and severs a third.
  The repair pass steers by how much floor is stranded outside the biggest piece.

## When it refuses

`generate` raises if the floor cannot be made into one piece, and the message
carries a diagnosis: per piece, its size, its height range, how many straight runs
out of it reach other floor at all, and how much longer the shallowest flight
would need to be. "It is in four pieces" is not actionable on its own.
