# 052-frame — one frame, two spaces

The three moves every frame of a two-space score makes (issue 701d):
- **draw_world(rc, raster, choreography, scene, t) → placed** — the
  world at loop moment t into the 3D painter's colour and depth: stars,
  shapes, blobs, wind, beams, streaks, in the order the shape films
  always drew them. `039-shape-films.lua` draws through it too.
- **landmark(rc, raster, placed, tag, size) → x, y** — where the first
  shape bearing a tag appears in the picture, in pixels (far off the
  picture when behind the lens).
- **pane_axes(facing) → n, right, up** — a world pane's directions; its
  top is toward the world's up (toward -z when it lies flat).
- **gather_pane(rc, raster, gathered, pane)** — lays one world pane into
  the depth: each subpixel's ray meets the pane, and where the pane is
  nearer than the surface drawn there (or nothing is), its light there
  is gathered.
- **compose{ rc, gathered, back, front, tm, tonemap, out, index_of }** —
  the light summed (world panes averaged down, back panes where nothing
  is drawn, front panes), tone-mapped once, added to the 3D colour,
  indexed once. `light_only = true` leaves the 3D colour out while its
  depth still hides and shows the light (the phase 7 demo's light half).

The 3D painter's colour is already display colour, so it is not
tone-mapped again; with no light a pixel is exactly the 3D painter's,
and with no world exactly the 2D painter's. Both byte-identity promises
rest on that.
