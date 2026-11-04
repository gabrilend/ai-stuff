<!-- made by scripts/file-screenshot on 2026-10-10 21:13, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10 -->

# 012 — slant-view-hub-at-the-bottom

- **Picture:** 012-slant-view-hub-at-the-bottom.png
- **Commit:** b93b2e70d 2026-10-10 centered-ui-design: every screenshot is kept, with what changed
- **Run:** `run --screenshot 10` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  - M input/game-settings.lua
  - M src/001-read-the-input.lua
  - M src/003-the-far-camera.lua
  - M src/004-the-sphere-fold.lua
  - M src/014-the-dashboard.lua
  - M src/016-the-game.lua
  - M src/017-the-tests.test.lua
  - M src/020-ceramic-boxes.c
  - M src/022-the-ceramic-host.c
  - M src/023-the-ceramic-host.lua
  - M src/025-the-focus-ring.lua

## What changed

Compared with picture 011:
- commit: 9d73d0a76 -> b93b2e70d
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/003-the-far-camera.lua
- changed: src/004-the-sphere-fold.lua
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua
- changed: src/017-the-tests.test.lua
- changed: src/020-ceramic-boxes.c
- changed: src/022-the-ceramic-host.c
- changed: src/023-the-ceramic-host.lua
- changed: src/025-the-focus-ring.lua

Settings, before (<) and now (>):

```
<     --                  one quadrant at a time (the scroll wheel turns it)
>     --                  one quadrant at a time (the scroll wheel turns it);
>     --                  "slant": the hub at the screen's bottom behind the
>     --                  console, the quadrant running up to the map's edge
>     --                  at the top, everything the same size near and far
<     view_depth = "hub",
>     view_depth = "slant",
> 
>     -- the slant view: how far out from the hub (world units) the top of the
>     -- screen reaches; the hub is at the bottom. The map's edge is
>     -- edge_radius, so a little more shows all of it.
>     slant_reach = 120,
```

## What it shows

The slant view, ten seconds in, blur on, at noon. The console's arch fills
the lower half, brushed steel with its gold-edged band; seat 1's painted
buttons and the calendar on it. The hub is at the bottom centre of the
screen, hidden behind the console; just above the arch's apex is the gold
ring of seat 1's section, where villagers are setting down cuboids. Above
it the quadrant runs up to the map's edge near the top, its tier rings as
faint arcs centred on the hub and its two boundary lines slanting out to the
corners. The villagers and their cuboids are the same size at the top as
just above the console. The top third and the lowest strip are softly
blurred: the focus ring is a semicircle round the console, sharpest a
little above the apex.

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
