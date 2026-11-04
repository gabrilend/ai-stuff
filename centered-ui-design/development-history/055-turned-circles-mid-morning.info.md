<!-- made by scripts/file-screenshot on 2026-10-10 22:42, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 20.5 -->

# 055 — turned-circles-mid-morning

- **Picture:** 055-turned-circles-mid-morning.png
- **Commit:** 632aaea7d 2026-10-10 centered-ui-design: the land as lit points, and hot-seat by spinning
- **Run:** `run --screenshot 20.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/012-made-by-formula.lua
  -  M src/013-the-world-renderer.lua
  -  M src/017-the-tests.test.lua
  -  M src/026-the-terrain.lua

## What changed

Compared with picture 054:
- commit: 0851eb669 -> 632aaea7d
- changed: src/012-made-by-formula.lua
- changed: src/013-the-world-renderer.lua
- changed: src/017-the-tests.test.lua
- changed: src/026-the-terrain.lua


## What it shows

Flat circles, twice as many, overlapping like scales so each shows only its
upper edge; mid-morning, each turned so its bright pole leans toward the
morning sun. The lowland reads as a textured green-and-sand surface; three
mesas rise as ochre plateaus with clay cliffs, the cliffs facing the sun
lighter than those facing away. At the circles' left and right rims thin
bright and dark wedges show — the "fins".

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
