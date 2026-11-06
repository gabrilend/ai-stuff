# test_minimap.lua

Checks the minimap (issues 507a, 507c, 507d, 507e) on a fake game with no
window. Conversions on a square map and on maps twice as wide and twice
as tall, fitted as WC3 fits them, with their margins; the interface
drawing the picture fitted and a dot per unit (owner's colour, buildings
larger, the ally colours and creep toggles); the camera's view box from
501d's camera (`render.camera`, built with gcc), moving, growing and
turning with it and cut exactly where it leaves the map; clicking,
dragging and right-clicking on the minimap moving the camera and ordering
the selection.

- **Usage:** `luajit src/tests/test_minimap.lua [DIR] [BUILD]` (DIR
  defaults to the project the test is in; BUILD to
  `$WETE_TEST_BUILD/minimap` when set, else `DIR/tmp/minimap`); exits 1
  on a failure. Needs gcc.
