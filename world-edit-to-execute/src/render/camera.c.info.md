# camera.c

The game camera as numbers (issue 501d), declared in `camera.h`. Plain C
in WC3's own units and axes (x east, y north, z up, degrees as WC3's
camera natives give them); needs neither raylib nor Lua.

- **`GameCamera`**: the target on the ground (`x`, `y`, and the ground's
  height `z`), `distance`, `rotation` (90 looks north), `aoa` (WC3's angle
  of attack: 304 is 56 degrees below level), `fov` (taken as vertical),
  `farz`, the zoom limits, and the map's camera `bounds`.
- **`camera_init(cam, x, y, z)`**: WC3's default game camera there
  (Blizzard.j's `bj_CAMERA_DEFAULT_*`: 1650, 304, 90, 70, far clip 5000),
  no bounds, the stand-in zoom limits 250 to 9000.
- **`camera_bounds_from_w3i(cam, corners)`**: the eight floats
  `war3map.w3i` stores (four corners, x and y each); the bounds are the
  rectangle around them. The target is then held inside.
- **`camera_clamp`, `camera_look_at`**: the target held inside the bounds,
  the distance inside its limits.
- **`camera_frame(cam, width, height, frame)`**: the eye and the screen's
  axes on the world for a screen of that size; the answers below take it.
- **`camera_screen_to_ground(frame, sx, sy, ground_z, &x, &y)`**: the
  ground point under a screen point, the ground taken as level at
  `ground_z`; false at or above the horizon.
- **`camera_world_to_screen(frame, x, y, z, &sx, &sy)`**: the screen point
  of a world point; false behind the eye.
- **`camera_view_quad(cam, frame, ground_z, corners)`**: the four screen
  corners on the ground (top left, top right, bottom right, bottom left);
  a corner that doesn't reach the ground within `farz` is taken where it
  crosses `farz`. Returns how many reached the ground.
- **`camera_view_rect(cam, frame, ground_z, rect)`**: the rectangle around
  the quad, for culling.
