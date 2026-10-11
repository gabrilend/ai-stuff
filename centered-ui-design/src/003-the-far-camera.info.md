<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 003-the-far-camera

Two ways to film the world. The far camera: impossibly far, nearly flat, accurate because the distance only ever appears divided; the world turns with the chair. The hub camera: an ordinary perspective just above the hub, aimed out and down along the chair, one quadrant at a time (issue 214). The slant view: the far camera's tilt and the chair's turn with no perspective, slid so the hub is on the bottom row and zoomed so the ground `slant_reach` out along the chair is on the top row — near by the console, far at the top, nothing shrinking. The arch view: tier rings drawn as copies of the console's arch grown outward, each quadrant growing from its own ally's arch; figures and cuboids anchored on their rings and drawn upright at one size (`project_anchored` in the shader). The console's sheet always hangs on the far camera.

| Offers | Takes | Gives |
|---|---|---|
| `new(settings, aspect)` | settings, width/height | camera: far-camera vectors and numbers; `turn`; `view` ("flat", "hub", "slant" or "arch"); hub eye height, look-down, focal, near, far; slant reach and half height |
| `project(camera, x, y, z)` | a world point | ndc x, y and depth, through the current view |
| `project_fixed(camera, x, y, z)` | a point hung on the camera | the far camera without the turn |
| `set_arch(camera, section, width, height)` | the console's arch (019 section) and window size | the arch view's pixels and scales |
| `hub_basis(camera)` | | the hub camera's forward, right, up |
| `ndc_to_pixels`, `view_plane_corners`, `ground_point_under_pixel` | | as before; picking works under every view |
| `GLSL`, `GLSL_FIXED` | | shader twins: project_world, project_fixed, view_facing (a surface's facing in the viewer's terms), hub_distance, project_anchored (a shape anchored at a ground point: warped anchor, unwarped shape under the arch view) |
| `send(camera, shader, flip_y, fixed)`, `send_used(shader, name, value)` | | the uniforms, each sent only if the shader uses it |
