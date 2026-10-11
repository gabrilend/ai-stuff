<!-- made by scripts/file-screenshot on 2026-10-10 21:14, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10 -->

# 014 — slant-view-without-blur

- **Picture:** 014-slant-view-without-blur.png
- **Commit:** df3d0ea23 2026-10-10 centered-ui-design: every screenshot is kept, with what changed
- **Run:** `run --screenshot 10` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
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

Compared with picture 013:
- changed: input/game-settings.lua

Settings, before (<) and now (>):

```
<     view_blur = "on",
>     view_blur = "off",
```

## What it shows

Picture 012 again with the focus ring switched off: the same seed and
moment, so every villager and cuboid stands where it did; now all of them
are crisp, from just above the console to the map's edge near the top. The
tier rings and quadrant lines are sharp to the edge. Without the blur the
view reads as a map seen at a slant rather than a miniature.

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
