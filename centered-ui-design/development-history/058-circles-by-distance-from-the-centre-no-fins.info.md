<!-- made by scripts/file-screenshot on 2026-10-10 22:44, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 20.5 -->

# 058 — circles-by-distance-from-the-centre-no-fins

- **Picture:** 058-circles-by-distance-from-the-centre-no-fins.png
- **Commit:** 619895b42 2026-10-10 centered-ui-design: the land as lit points, and hot-seat by spinning
- **Run:** `run --screenshot 20.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M scripts/run-tests
  -  M src/012-made-by-formula.lua
  -  M src/013-the-world-renderer.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/026-the-terrain.lua

## What changed

Compared with picture 057:
- changed: src/012-made-by-formula.lua
- changed: src/013-the-world-renderer.lua
- changed: src/016-the-game.lua


## What it shows

Mid-morning again, repaired: each circle shaded straight from its dark
pole to its bright pole (no fins), cut exactly round; ordered only by its
distance from the centre, so a mesa's circles no longer cover lowland in
front of it. The land reads as a smooth scaled surface; the mesas' sunward
cliffs glow orange.

## The story so far

The land as lit points (051-054) was "getting closer": the owner then
asked for flat circles rather than domes, twice as many and mostly
overlapping, lit only by turning — "the spinning of the sprite axies is
what will display their lighting" — the nearest drawn on top and fully
hidden ones never drawn, "so many that they paint a surface". This cycle
turns each circle in the screen's plane by how squarely its slope faces the
sun (055-057). The owner then pointed out the hills looked "a little
funky" — circles were ordered by their height too, not by "one value, the
distance from the center" — and "weird fins" on the circles, which came
from shading along lines of latitude; both fixed (058-059). The tests now
also start the game for a moment, after a shader that would not build
slipped past them.
