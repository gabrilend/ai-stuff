# crowd.h / crowd.c

The crowd of round units (`src/runtime/crowd.lua`) ported to C line for
line, so it can run on threads (issue 515k). The Lua crowd is the
reference; `test-crowd-c.sh` checks every position matches it exactly.

- **A tick is three calls:** `cr_tick_begin(c)` (one thread: the
  snapshot), `cr_decide(c, index, dt)` for every unit (any thread, any
  order, at once), `cr_tick_end(c, dt)` (one thread: settling in id
  order). `cr_tick(c, dt)` does all three on one thread.
- **`cr_new(w, h, walkable, cell)`:** `walkable[(y-1)*w + (x-1)]` (1 open,
  0 wall), top row first. **`cr_add(c, x, y, radius, speed, team)`:** the
  next id. **`cr_move_group(c, ids, n, x, y)`.** **`cr_free(c)`.**
- **`cr_units(c) -> cr_unit *`**, **`cr_count`**, **`cr_tick_count`**,
  **`cr_set_look_ahead`**, **`cr_any_overlap(c, &a, &b)`.**
- **`cr_unit`:** the Lua unit's fields under the same names (doubles for
  positions and sizes, ints for flags and counts); `path` is `cr_point`s
  with `path_len`, `has_path` 0 for none; `back_offs_done` counts its
  back-offs (a crowd-wide count would be written by several threads).
- **Port notes:** neighbours are visited in the Lua order (bucket by
  bucket, dx then dy, entry order within a bucket); the planner's working
  arrays and neighbour lists are per thread.
