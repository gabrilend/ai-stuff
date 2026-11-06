<!-- made by scripts/build-info-pages from the comments in 023-the-renderer.lua; change the comments and rebuild, not this page -->
# 023-the-renderer


Turns the shapes of 022 into engine meshes and owns the one shader that
draws them, with three looks:

  clay   a wide wrap-around light, soft sky light from above, and a faint
         thumbprint wobble in brightness, so it reads as something pressed
         by hand
  brick  a sharper light and a small glossy highlight
  flat   barely lit: the ground, puddles, painted marks

The camera's projection and view are set once a frame (begin); every draw
after that is one shape, one model matrix, one colour and one look. The 3D
pass turns the depth test on and end_3d turns it off, so 2D drawing after
it is unaffected.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | nothing | Builds the meshes and the shader. Called once, after the window opens. |
| `M.begin_3d` | `r, camera` | camera: proj and view matrices, eye position, fog distance and colour. |
| `M.draw` | `r, part` | One part: the shape's name, its model matrix, a colour {r, g, b[, a]}, the look's name, and the scale on each axis (for turning normals correctly under a stretched shape). |
| `M.draw_list` | `r, parts` | (no comment in the source) |
| `M.end_3d` | `r` | (no comment in the source) |

## Tables of rows

| Name | What it is |
| --- | --- |
| `LOOK` | (no comment in the source) |
| `FORMAT` | (no comment in the source) |
