<!-- made by scripts/file-screenshot on 2026-10-10 21:43, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10 -->

# 015 — walking-on-the-sphere-at-ten-seconds

- **Picture:** 015-walking-on-the-sphere-at-ten-seconds.png
- **Commit:** 296f49543 2026-10-10 centered-ui-design: a slant view, near by the console and far at the top
- **Run:** `run --screenshot 10` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/004-the-sphere-fold.lua
  -  M src/017-the-tests.test.lua
  -  M src/020-ceramic-boxes.c
  -  M src/022-the-ceramic-host.c
  -  M src/023-the-ceramic-host.lua

## What changed

Compared with picture 014:
- commit: b93b2e70d -> 296f49543
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/004-the-sphere-fold.lua
- changed: src/017-the-tests.test.lua
- changed: src/020-ceramic-boxes.c
- changed: src/022-the-ceramic-host.c
- changed: src/023-the-ceramic-host.lua

Settings, before (<) and now (>):

```
<     view_blur = "off",
>     view_blur = "on",
> 
>     -- the world is a sphere: our hub is one pole, and the foes' kingdom
>     -- across from it is the other, this many tiers out (past the tiers
>     -- shown). Laps around the hub are shortest near either pole, so walkers
>     -- far out cross the map's wide outer rings fast from side to side.
>     far_pole_tier = 7,
```

## What it shows

The slant view at ten seconds, with haulers walking on the sphere. More
villagers are on the move than in 012 (same seed and moment, old walk):
haulers spread across the whole quadrant, a crowd drifting sideways at the
right, several carrying cuboids toward seat 1's gold section just above the
console's apex. The delivered-count dials on the console read 2, 1, 4, 5
(012 read 1, 1, 4, 4): the faster walk has already delivered more.

## The story so far

After the slant view (012-014) the owner answered how the far stuff should
move: the world is a sphere, our hub one pole and the foes' kingdom the
other, and the slant view is the flat plane between, "not bent one way or
the other, rather, simply perfect to you"; far walkers "move left-right
faster while they are far away, but closer / farther is always just dense".
This cycle makes the haulers walk at a steady pace measured on that sphere,
so near the far pole (one tier past the map's edge) a short lap is drawn as
the map's wide outer ring and sideways walking crosses the screen fast. The
walk no longer depends on which view is on. Still open: where exactly the
far pole lies, and whether "more distance" means more tiers.
