# camera.lua

The game camera (`camera.c`, issue 501d) for Lua, through LuaJIT's FFI.
`camera.build(DIR, BUILD)` compiles `camera.c` and `camera_input.c` into `BUILD/libcamera.so`
with gcc; `camera.open(lib)` gives `new(x, y, z)`, a camera whose methods
are `bounds_from_w3i(t)`, `clamp()`, `look_at(x, y)`, `target()`,
`frame(w, h)`, `step(input, dt)` (505c's controls: one frame of input, returning the ways it panned), `screen_to_ground(w, h, sx, sy[, ground_z])`,
`world_to_screen(w, h, x, y[, z])`, `view_quad(w, h[, ground_z])` (eight
numbers and how many corners reached the ground) and `view_rect(w, h[,
ground_z])`. Its numbers are `cam.c`, the C struct itself. Ground height
defaults to the camera's own `z`.
