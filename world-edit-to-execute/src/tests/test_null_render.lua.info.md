# test_null_render.lua

Checks the headless renderer (issue 501c). One scene of fifteen items
(every kind, two placeholders, one hidden, two outside the map, items on
both edges, clamped colours, a zero scale) is built three ways with no
window and no raylib: from a C program the test writes and compiles, from
Lua through the bridge's calls (`render.null`), and through
`src/render.lua` as a game would. Each must give the scene's counts and
the checksum the test works out by itself from the scene's values, the
same on every run; a changed field must change it, and calls after close
must do nothing.

- **Usage:** `luajit src/tests/test_null_render.lua [DIR] [BUILD]`
  (BUILD defaults to `DIR/tmp/null-render`); exits 1 on a failure. Needs
  gcc.
