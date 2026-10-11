<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 015-the-view-plane

Lays the console's layers on a sheet hung in the 3D scene in front of the map, sized to exactly fill the view at its distance and zoom. Drawn after the world picture is finished, because the arch's band looks through the sheet at the world (a lens over the map); windows bend their dials.

| Offers | Takes |
|---|---|
| `new(camera, plane_distance, dashboard)` | |
| `draw(plane, flip_y, world_canvas)` | draws onto the current target, sampling the finished world picture |
| `REFRACTION`, `BAND_BEND` | how far window glass bends; how many times more the band bends |
