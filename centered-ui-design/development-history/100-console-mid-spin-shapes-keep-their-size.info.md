<!-- made by scripts/file-screenshot on 2026-10-11 00:08, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --drag 24 1100 990 600 990 1.0 --screenshot 24.6 -->

# 100 — console-mid-spin-shapes-keep-their-size

- **Picture:** 100-console-mid-spin-shapes-keep-their-size.png
- **Commit:** 3cba5ed0a 2026-10-10 centered-ui-design: villagers turn to face their path along the curve
- **Run:** `run --drag 24 1100 990 600 990 1.0 --screenshot 24.6` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M scripts/run-tests
  -  M src/003-the-far-camera.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/015-the-view-plane.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/026-the-terrain.lua

## What changed

Compared with picture 099:
- changed: src/014-the-dashboard.lua
- changed: src/015-the-view-plane.lua
- changed: src/017-the-tests.test.lua


## What it shows

Mid-spin on curves parallel to the arch's edge: the calendar, readouts and
order buttons keep their round shapes as they slide along the curve; the
next seat's edge rises in at the right.

## The story so far

After the facing examples (088-095), the owner noticed the terrain
circles snapping to a new colour as the sun passed behind, asked for a D
dial to spread the rings up the screen, and found the console's buttons
"toooo stretched" while spinning. The circles' turn now reverses smoothly
(098-099); D spreads the rings while everything on them keeps its size
(097); and the console now slides along curves parallel to its own edge,
by equal distances, so buttons keep their shape (096 shows the first try,
equal distances on scaled rings, which still made slivers; 100 the fix).
