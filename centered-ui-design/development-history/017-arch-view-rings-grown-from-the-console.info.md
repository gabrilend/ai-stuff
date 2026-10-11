<!-- made by scripts/file-screenshot on 2026-10-10 21:49, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10 -->

# 017 — arch-view-rings-grown-from-the-console

- **Picture:** 017-arch-view-rings-grown-from-the-console.png
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

Compared with picture 016:
- commit: 4631a8407 -> 76f335172
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/003-the-far-camera.lua
- changed: src/004-the-sphere-fold.lua
- changed: src/013-the-world-renderer.lua
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua
- changed: src/017-the-tests.test.lua
- changed: src/025-the-focus-ring.lua

Settings, before (<) and now (>):

```
<     --                  at the top, everything the same size near and far
>     --                  at the top, everything the same size near and far;
>     --                  "arch": the tier rings drawn as copies of the
>     --                  console's arch grown outward from it, the hub on the
>     --                  arch itself, everything the same size near and far
<     view_depth = "slant",
>     view_depth = "arch",
> 
>     -- the arch view: how far out from the hub (world units) the top of the
>     -- screen reaches above the arch's apex; the hub lies on the arch itself
>     arch_reach = 112,
```

## What it shows

The first arch view. Above the console the tier rings are no longer
circles round a hidden hub but copies of the arch's own curve, each larger
than the last: the faint rings and seat 1's gold section (now a long
crescent over the apex) bow the same way the console's band does. Villagers
and cuboids stand upright on them, the same size at the top as near the
arch, smaller than in the slant view (the whole hub-to-edge distance fits
in the half screen above the apex). Fewer figures are on screen than in the
slant view: only our own quadrant is shown; past the arch's feet the
neighbours' ground ran on below the bottom row, out of sight.

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
