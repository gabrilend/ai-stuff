<!-- made by scripts/file-screenshot on 2026-10-10 22:45, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 059 — circles-by-distance-at-noon

- **Picture:** 059-circles-by-distance-at-noon.png
- **Commit:** 632aaea7d 2026-10-10 centered-ui-design: the land as lit points, and hot-seat by spinning
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M scripts/run-tests
  -  M src/012-made-by-formula.lua
  -  M src/013-the-world-renderer.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/026-the-terrain.lua

## What changed

Compared with picture 058:
- no source or settings file changed (same program, different run or moment)


## What it shows

Noon, repaired: an even scaled surface of green and sand, the mesas'
ochre tops ringed by clay cliffs that darken where they face away from the
sun; villagers and cuboids stand clearly on top of it all.

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
