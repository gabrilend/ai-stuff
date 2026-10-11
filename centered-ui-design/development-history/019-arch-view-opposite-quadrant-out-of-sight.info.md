<!-- made by scripts/file-screenshot on 2026-10-10 21:51, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10 -->

# 019 — arch-view-opposite-quadrant-out-of-sight

- **Picture:** 019-arch-view-opposite-quadrant-out-of-sight.png
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

Compared with picture 018:
- changed: src/003-the-far-camera.lua


## What it shows

The repair: ground two or more arches away (never visible) is sent far
below the bottom row, and the bands are gone. Our quadrant's rings and
seat 1's gold crescent bow over the console as in 017; at the lower left
and right corners the neighbours' rings now rise from their own arches as
pale lines meeting the screen's edges, with a few of their villagers at the
right edge. Blur is on: sharp around the section's crescent, softer toward
the top.

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
