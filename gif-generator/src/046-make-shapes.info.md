# 046-make-shapes — generated scenes from their generators

A scene that needs to compute is kept as a generator, an ordinary Lua
program in `input/shapes/generators/` (shared pieces such as the wizard in
`generators/parts/`). This runs each generator and writes what it returns
to `input/shapes/<name>.lua` as plain data, under a first line naming the
generator and the generator's own opening comment. It never replaces a
scene written by hand.

CLI: `luajit src/046-make-shapes.lua DIR [--check]`, or `./make-shapes
[DIR] [--check]`. `--check` writes nothing and exits 1 when a generated
scene is missing or stale; `./test-shape-films` runs it.
