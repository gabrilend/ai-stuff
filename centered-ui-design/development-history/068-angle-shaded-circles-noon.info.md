<!-- made by scripts/file-screenshot on 2026-10-10 22:57, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 068 — angle-shaded-circles-noon

- **Picture:** 068-angle-shaded-circles-noon.png
- **Commit:** b8ff3dc2a 2026-10-10 centered-ui-design: bar-chart circles to watch the turn, and drags that carry
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/012-made-by-formula.lua

## What changed

Compared with picture 067:
- no source or settings file changed (same program, different run or moment)


## What it shows

Noon at the ordinary distance: the land a fine sheen of green and sand
scales; the mesas' ochre tops ringed by clay cliffs whose circles facing
away from the sun are dark; villagers carry cuboids across.

## The story so far

With the turn confirmed by the bar-chart circles (060-066), the owner drew
what a circle should look like with the sun at the top right — eight
sections, brightest toward the sun, darkest opposite (kept in
assets/references/) — "a smoother gradient probably", and noted it could
render any surface, water among them, with few bits per point, the ceramic
engine handling the updates. The circle now shades by direction round its
centre, blended; the turn is unchanged. Open: whether moving surfaces like
water should keep their points in the engine's shared memory.
