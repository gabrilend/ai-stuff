# camera_input.c

WC3's camera controls on the camera model (issue 505c), declared in
`camera_input.h`. Plain C, no raylib.

- **`CameraInput`**: one frame's input: the arrow keys held, whether the
  screen's edges scroll (`edges`), the mouse, the screen's size, and wheel
  notches (positive comes closer).
- **`camera_pan_ways(in)`**: the ways it pans, as bits (1 left, 2 right,
  4 up, 8 down): the keys, and with `edges` the mouse within the outer 3
  pixels.
- **`camera_step(cam, in, dt)`**: pans along the view's heading at 1400
  units a second at the default distance (in proportion to the
  distance), zooms 150 a notch, then holds the camera inside the map's
  bounds and its zoom limits (`camera_clamp`). The speeds are stand-ins
  until 516d.
