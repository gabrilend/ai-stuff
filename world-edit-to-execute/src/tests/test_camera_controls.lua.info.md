# test_camera_controls.lua

Checks the camera controls (issue 505c) with no window and no raylib:
frames of input given to the camera (`camera_input.c` through
`render.camera`) pan it the way the view looks at the stand-in speed and
faster zoomed out, the screen's outer 3 pixels scroll only with edges on,
the wheel zooms in 150-unit steps within the limits, and nothing passes
the map's camera bounds. Then the interface's keys that bring the view to
the selection (a hero's key twice, a group's number twice quickly, the
idle worker's key) on a fake game.

- **Usage:** `luajit src/tests/test_camera_controls.lua [DIR] [BUILD]`
  (DIR defaults to the project the test is in; BUILD to
  `$WETE_TEST_BUILD/camera-controls` when set, else
  `DIR/tmp/camera-controls`); exits 1 on a failure. Needs gcc.
