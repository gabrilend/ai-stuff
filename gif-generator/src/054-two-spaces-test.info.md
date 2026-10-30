# 054-two-spaces-test — one canvas, two spaces keeps its promises

- every stroke-only score in `input/` compiles as it always has and
  films the bytes it filmed before panes
  (`tests/two-spaces/stroke-fingerprints.lua`);
- each of the six approved films, said as a score (camera{}, world{},
  a shape{} per shape, its stars as the sky), films its approved bytes;
- a front pane's light alone composes into the 2D painter's own pixels;
- a world pane's light is gathered where nothing is drawn, hidden behind
  a nearer shape, and shines over a farther one;
- `tests/two-spaces/broken.lua`, a dozen mistakes across both spaces,
  gets all twelve in one refusal;
- `tests/two-spaces/mixed.lua` films, films the same twice, and survives
  the writer;
- the phase 7 demo's score (`issues/completed/demos/phase-7/meeting.lua`)
  passes the wall; its shapes' half films the score with its strokes and
  panes taken away, and both halves are the score as it always films.

CLI: `luajit src/054-two-spaces-test.lua DIR`; `./test-shape-films`
runs it.
