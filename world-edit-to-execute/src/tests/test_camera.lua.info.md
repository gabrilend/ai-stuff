# test_camera.lua

Checks the camera model (issue 501d) with no window and no raylib. WC3's
default camera over known points: the ground points under the screen's
centre, a quarter up, down and right must be the ones the test works out
from the camera's angles by plain trigonometry; screen to ground and back
lands within a hundredth of a pixel, turned and tilted; nothing is
answered above the horizon or behind the eye; the view's four ground
corners form the expected trapezoid, cut at the far clip when zoomed out;
the target stays inside the map's camera bounds as `war3map.w3i` stores
them, and the distance inside its limits. Also builds `camera.c` alone as
strict C99.

- **Usage:** `luajit src/tests/test_camera.lua [DIR] [BUILD]` (DIR
  defaults to the project the test is in; BUILD to
  `$WETE_TEST_BUILD/camera` when that is set, else `DIR/tmp/camera`);
  exits 1 on a failure. Needs gcc.
