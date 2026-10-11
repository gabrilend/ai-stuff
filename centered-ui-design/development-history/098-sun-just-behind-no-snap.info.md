<!-- made by scripts/file-screenshot on 2026-10-11 00:05, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 36.2 -->

# 098 — sun-just-behind-no-snap

- **Picture:** 098-sun-just-behind-no-snap.png
- **Commit:** 3cba5ed0a 2026-10-10 centered-ui-design: villagers turn to face their path along the curve
- **Run:** `run --screenshot 36.2` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
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

Compared with picture 097:
- no source or settings file changed (same program, different run or moment)


## What it shows

Just before the sun passes behind the viewer: the circles turned toward one side.

## The story so far

After the facing examples (088-095), the owner noticed the terrain
circles snapping to a new colour as the sun passed behind, asked for a D
dial to spread the rings up the screen, and found the console's buttons
"toooo stretched" while spinning. The circles' turn now reverses smoothly
(098-099); D spreads the rings while everything on them keeps its size
(097); and the console now slides along curves parallel to its own edge,
by equal distances, so buttons keep their shape (096 shows the first try,
equal distances on scaled rings, which still made slivers; 100 the fix).
