<!-- made by scripts/file-screenshot on 2026-10-10 22:42, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 056 — turned-circles-at-noon

- **Picture:** 056-turned-circles-at-noon.png
- **Commit:** 632aaea7d 2026-10-10 centered-ui-design: the land as lit points, and hot-seat by spinning
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/012-made-by-formula.lua
  -  M src/013-the-world-renderer.lua
  -  M src/017-the-tests.test.lua
  -  M src/026-the-terrain.lua

## What changed

Compared with picture 055:
- no source or settings file changed (same program, different run or moment)


## What it shows

Noon: the circles stand bright-pole-up, so the land reads evenly lit; the
mesas' cliffs facing the camera (away from the noon sun on the far side)
turn dark-pole-up. Some mesa-top circles cover lowland circles in front of
them (ordered partly by height), and the fins are clearer here.

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
