<!-- made by scripts/file-screenshot on 2026-10-10 21:14, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel 9.6 1 --screenshot 9.85 -->

# 013 — slant-view-mid-turn

- **Picture:** 013-slant-view-mid-turn.png
- **Commit:** df3d0ea23 2026-10-10 centered-ui-design: every screenshot is kept, with what changed
- **Run:** `run --wheel 9.6 1 --screenshot 9.85` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M scripts/file-screenshot
  -  M src/001-read-the-input.lua
  -  M src/003-the-far-camera.lua
  -  M src/004-the-sphere-fold.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/020-ceramic-boxes.c
  -  M src/022-the-ceramic-host.c
  -  M src/023-the-ceramic-host.lua
  -  M src/025-the-focus-ring.lua

## What changed

Compared with picture 012:
- no source or settings file changed (same program, different run or moment)


## What it shows

The same view a quarter of a second after one notch of the scroll wheel,
partway through the chair's eased turn toward seat 4. The world has swung
round the hub (still at the bottom centre, behind the console): seat 4's
green section has come in at upper left of the arch, seat 1's orange section
is sliding away at lower right, and the quadrant boundary now slants up to
the right. The console's arches slide with the chair: seat 4's arch,
labelled SEAT 4 in green, fills most of the screen and seat 1's foot is at
the right edge. Ground far from the hub has moved much further than ground
near it, as the rim of a turning wheel does.

## The story so far

The project began as round spheroids under a round dashboard (001), grew
figures on bending limbs and an arch console (002), moved the world onto the
ceramic engine with villagers hauling cuboids to coloured sections (003), then
went looking for the tilt-shift look of the owner's valley pictures: a
perspective camera at the hub (004), raised straight up until it saw only
haze (005, 006), compared with blur off, figures leaning, the flat map, dusk
and night (007-011). The owner then asked for the near ground by the
dashboard, the far ground at the top, more distance shown, and far things
"the same size" though they "move faster". This cycle answers with the slant
view: the hub at the bottom row behind the console, the chair's quadrant
running up to the map's edge, no shrinking with distance, the fold still
pressing the outer tiers together. From here every screenshot files itself
in this directory. Waiting on the owner: whether "moves faster" means only
this (more world per step at the top; faster sweep when turning), and
whether "more distance" also means more tiers.
