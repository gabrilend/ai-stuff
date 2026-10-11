<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 003-the-far-camera

The impossibly far camera, without losing accuracy: positions are measured from the map's center and the camera distance only ever appears divided. The world turns with the player's chair (`camera.turn`); things hung on the camera (the console's sheet) do not.

| Offers | Takes | Gives |
|---|---|---|
| `new(settings, aspect)` | settings, width/height | camera: right/up/back unit vectors (three numbers each), half_height (zoom), aspect, distance, depth_half_range, turn (radians, 0) |
| `project(camera, x, y, z)` | a world point | screen ndc x, y (-1..1, up +) and depth, after the chair's turn |
| `project_fixed(camera, x, y, z)` | a point hung on the camera | the same, without the turn |
| `ndc_to_pixels(x, y, width, height)` | ndc | window pixels (top-left origin) |
| `view_plane_corners(camera, plane_distance)` | distance in front of the map's center | four corners {x, y, z, u, v} of a sheet that exactly fills the view at that distance |
| `ground_point_under_pixel(camera, px, py, width, height)` | a pixel | world x, z on the ground (turn undone) |
| `GLSL`, `GLSL_FIXED`, `send(camera, shader, flip_y, fixed)` | | shader twins: project_world (turned) and project_fixed; their uniforms |
