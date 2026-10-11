<!-- made by scripts/file-screenshot on 2026-10-10 21:50, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10 -->

# 018 — arch-view-neighbours-from-their-own-arches

- **Picture:** 018-arch-view-neighbours-from-their-own-arches.png
- **Commit:** 76f335172 2026-10-10 centered-ui-design: villagers walk on a sphere between two poles
- **Run:** `run --screenshot 10` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/003-the-far-camera.lua
  -  M src/004-the-sphere-fold.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/025-the-focus-ring.lua

## What changed

Compared with picture 017:
- changed: src/003-the-far-camera.lua
- changed: src/017-the-tests.test.lua
- changed: src/025-the-focus-ring.lua


## What it shows

A broken picture, kept on purpose. Each neighbour's quadrant was made to
grow from the neighbour's own arch (the console's M), and the ground broke
into wide horizontal bands, a purple one across the middle: the quadrant
across from ours lies two arches away on both sides at once — its angle
wraps round from left to right — so ground pieces spanning the wrap
stretched across the whole screen. The figures are drawn correctly; only the
ground is torn.

## The story so far

After the slant view (012-014) and walking on the sphere (015-016), the
owner suggested projecting the circle onto the curve of the dashboard so
the world's scale matches the arch, and pictured it as "a king in a castle
walking along the battlements viewing all the surrounds". Asked to choose,
the owner chose moving the points (figures upright, one size) over
wrapping a flat picture. This cycle builds the arch view: each tier ring a
scaled copy of the console's arch, our quadrant foot to foot along it as on
the band, each neighbour's quadrant growing from the neighbour's own arch.
017 is the first try, 018 the mistake it exposed, 019 its repair. Still
open: where the far pole lies, whether "more distance" means more tiers,
and how the arch view should be tuned (figure size, how far it reaches).
