<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 009-the-orbit-camera

The camera on a ball around the shape (issue 005). Pure arithmetic, no LÖVE. Matrices are 4 rows of 4 numbers, multiplying column vectors; projection is OpenGL's (-1..1 after dividing by w). World is y up.

**camera**: target ({x,y,z}), yaw, pitch, fov (radians), distance, radius (numbers).

| Offers | Gives |
|---|---|
| `new(fov_degrees)` | a camera |
| `fit(camera, centre, radius, aspect)` | aims and backs off so the ball fits the narrower screen direction |
| `orbit(camera, yaw, pitch)` | turns; pitch stops at ±89° |
| `pan(camera, dx, dy, screen_height)` | slides the target so the shape follows the mouse |
| `zoom(camera, notches)` | 10% closer per notch |
| `eye(camera)`, `view(camera)`, `projection(camera, aspect)` | position; matrices |
| `upright(up_axis)` | the model matrix standing a z-up shape upright |
| `multiply(a, b)`, `transform(m, point)` | matrix product; x, y, z, w |
