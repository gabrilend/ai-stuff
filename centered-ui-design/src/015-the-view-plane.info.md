<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 015-the-view-plane

Lays the console's layers on a sheet hung in the 3D scene in front of the map, sized to exactly fill the view at its distance and zoom; it hangs on the camera and does not turn with the chair. Windows bend their dials; the arches' bands carry the map painted from beyond (024): each band pixel looks up its ally's quadrant at its place along the band (angle) and across it (hub to farthest tier).

| Offers | Takes |
|---|---|
| `new(camera, plane_distance, dashboard)` | |
| `draw(plane, flip_y, beyond)` | draws onto the current target; `beyond` is the map-from-beyond canvas |
| `REFRACTION` | how far window glass bends |

Spinning along the curve: the sheet's shader finds each pixel's arch-shaped ring and angle, moves the angle by the spin (half a turn of the curve per seat), and reads the console there; the seat the angle falls in shifts the band's quadrant. The Lua twin is the dashboard's `unwarp`.
