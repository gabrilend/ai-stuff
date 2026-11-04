<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 025-the-focus-ring

The tilt-shift blur: sharp in a ring of distance around the hub, blurring nearer and farther. Each pixel's ground distance is worked out from the camera (the ray through it, met with the ground); under the hub camera the sharp ring is an arc on screen.

| Offers | Takes |
|---|---|
| `new()` | |
| `draw(ring, world_canvas, camera, edge_radius, flip_y)` | draws the finished world onto the current target through the ring |
| `FOCUS_SHARE`, `SHARP_HALF_WIDTH_SHARE`, `BLUR_RAMP_SHARE`, `MOST_BLUR_PIXELS` | where the ring is and how wide (shares of the map's edge radius); the widest blur |
