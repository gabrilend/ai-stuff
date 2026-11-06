# null.lua

The headless renderer for Lua (issue 501c): real render slots and
`null_render.c`, reached through LuaJIT's FFI from a small shared library,
so game code that writes slots runs with no window and no raylib.

- **`null.build(dir, build) -> path`**: compiles `slots.c` and
  `null_render.c` into `build/libnull-render.so` with gcc.
- **`null.open(path) -> backend`**: a fresh slot array.
  - **`backend.render`**: the entity calls of the renderer's Lua bridge
    (`bridge.c`, 508c) with its defaults and limits: `create_entity`,
    `destroy_entity`, `set_position`, `set_color` (clamped 0-255, alpha
    255), `set_selected`, `set_visible`, `set_scale` (at least 0.01),
    `set_team`, `set_rotation`, `set_mesh`, `get_slot_count`,
    `find_by_entity`, and the `MESH_*` and `MAX_SLOTS` constants. With
    `package.loaded.render = backend.render`, `src/render.lua` and any
    scene written for the window run headless. Terrain calls are not
    offered (terrain is not in the slots).
  - **`backend:report(map) -> table`**: `active`, `drawn`, `hidden`,
    `kinds` (`circle`, `cube`, `triangle`, `cylinder`), `placeholders`,
    `outside`, `selected`, `checksum` (16 hex digits). `map` is
    `{min_x, min_y, max_x, max_y}` or nil.
  - **`backend:text(map)`**: the C report's text.
  - **`backend:close()`**: frees the slots; afterwards the calls do what
    the bridge does with no slot array (nothing, -1, nil, 0 slots).
