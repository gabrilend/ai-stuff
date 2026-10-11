<!-- made by scripts/file-screenshot on 2026-10-10 21:43, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 10.5 -->

# 016 — walking-on-the-sphere-half-a-second-later

- **Picture:** 016-walking-on-the-sphere-half-a-second-later.png
- **Commit:** 4631a8407 2026-10-10 centered-ui-design: a slant view, near by the console and far at the top
- **Run:** `run --screenshot 10.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/004-the-sphere-fold.lua
  -  M src/017-the-tests.test.lua
  -  M src/020-ceramic-boxes.c
  -  M src/022-the-ceramic-host.c
  -  M src/023-the-ceramic-host.lua

## What changed

Compared with picture 015:
- no source or settings file changed (same program, different run or moment)


## What it shows

The same run half a second later, for comparison with 015. Figures near
the top have shifted further left or right than figures near the console
have moved in or out — e.g. the crowd at the right has slid along its
ring. Two more cuboids have been set down in sections (the dials read 4, 2,
4, 5).

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
