# 001-world.h / 001-world.c — public surface

The **square-room world** (issue 103): the map, held as two lenses over one set
of cells — a tile grid for the renderer/collision, a room table + door graph for
gameplay. Pure data + a builder + a validator; no threads, no rendering.

## Coordinate conventions (also on the header struct)

- Grid is `cells[y*width + x]`; x = column (+east), y = row (+south); one cell =
  one tile. Moving bodies use float tile positions.
- Height (z) is a separate axis: `floor_h`/`ceil_h` per cell (tile units); a
  body stands on its cell's `floor_h`.
- A **solid** cell blocks movement AND sight; open cells belong to a room
  (`room_id >= 0`), solid/void cells carry `room_id -1`.

## Types

- `cell_t` — solid flag, wall surface id, floor/ceiling height, room id.
- `room_t` — id, footprint `[x0,x1)×[y0,y1)`, floor/ceiling, special-property tag.
- `door_t` — the two rooms it links, the opening cell, passable flag.
- `world_t` — grid + cells + rooms + doors + spawn room.
- `world_stats_t` — validator output (counts + problem count).

## Build / destroy / query

- `world_t *world_build_test(void)` — the hand-authored two-room test map (wall +
  door + step-up). NULL on OOM.
- `void world_destroy(world_t *)`.
- `const cell_t *world_cell(w, cx, cy)` — cell or NULL out of bounds.
- `int world_is_solid(w, cx, cy)` — 1 if solid **or off-map** (the void blocks).
- `int world_room_at(w, cx, cy)` — room id or -1.

## Room-behaviour dispatch (the Phase-4/6 seam)

The deliverable seam: a room's `special` tag indexes a behaviour table, and the
engine fires enter/step/exit without knowing what the behaviour means.

- `int world_register_behaviour(int tag, room_behaviour_t)` — register a
  `{name, on_enter, on_step, on_exit}` at a tag (1 ok / 0 out of range).
- `void world_room_enter/step/exit(w, room_id, ctx)` — fire the room's tag's
  callback; a NULL/unregistered callback is a safe no-op (an unfilled seam does
  nothing, it isn't an error).
- Phase-1 tags: `ROOM_PLAIN`, `ROOM_SPAWN` (both no-ops for now). Phase 4/6
  register real puzzle/combat/treasure behaviours here.

## Validator

- `int world_validate(w, &stats)` — 1 if coherent (open cells name real rooms,
  doors link real rooms, spawn room exists, rooms don't overlap), 0 otherwise;
  fills `stats` with counts. Runnable standalone (`001-world-test.c`) so docs
  cite it instead of hardcoding map sizes.

## Related

- `src/000-main.c` — builds the world, renders it top-down, moves the player.
- Issue `103`; consumers `104` (render), `105`/`106` (collision), Phase 4/6 seams.
