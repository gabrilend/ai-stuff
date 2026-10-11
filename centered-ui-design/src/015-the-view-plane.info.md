<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 015-the-view-plane

Lays the dashboard's layers on a sheet hung in the 3D scene in front of the map, sized to exactly fill the view at its distance and zoom, combining metal, glass refraction and dials in one shader.

| Offers | Takes |
|---|---|
| `new(camera, plane_distance, dashboard)` | |
| `draw(plane, flip_y)` | draws into the current (world) canvas |
| `REFRACTION` | how far glass bends at a window's rim, as a share of the picture's height |
