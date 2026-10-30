# 050-shape-wall-test — the 3D wall keeps its promises

Asks the wall directly, no pixels:
- the word lists and the code name the same motions and shapes;
- every scene in `input/shapes/` and `tests/shape-films/` passes;
- `tests/shape-films/misspelled.lua`, with one mistake in each of twelve
  places, gets exactly those twelve lines in one pass, each with its
  nearest word, and `choreography.load` refuses it with all twelve;
- a few words legal in one place and not another (a part may not travel,
  a cube takes no proportions, a `becomes` may set `roll = false`, a
  target is a point or "ahead", an anchor is checked like any table).

CLI: `luajit src/050-shape-wall-test.lua DIR`; `./test-shape-films` runs
it, with the docs check and the film tool's own refusal.
