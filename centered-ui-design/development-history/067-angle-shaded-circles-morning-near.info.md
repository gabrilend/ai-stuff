<!-- made by scripts/file-screenshot on 2026-10-10 22:57, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 20 a -6 --screenshot 20.5 -->

# 067 — angle-shaded-circles-morning-near

- **Picture:** 067-angle-shaded-circles-morning-near.png
- **Commit:** b8ff3dc2a 2026-10-10 centered-ui-design: bar-chart circles to watch the turn, and drags that carry
- **Run:** `run --wheel-with 20 a -6 --screenshot 20.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/012-made-by-formula.lua

## What changed

Compared with picture 066:
- commit: 1abb118e6 -> b8ff3dc2a
- changed: input/game-settings.lua
- changed: src/012-made-by-formula.lua

Settings, before (<) and now (>):

```
<     view_circle = "bars",
>     view_circle = "shade",
```

## What it shows

Mid-morning, zoomed in (0.6): every terrain circle shaded by direction
round its centre, a smooth sweep from a bright side to a dark side meeting
at a point in the middle, like a shallow cone seen from above; all turned
alike on the flat land, so the field reads as soft scales; the mesa's clay
cliff at the top right turned differently. Seat 1's cuboids at the top.

## The story so far

With the turn confirmed by the bar-chart circles (060-066), the owner drew
what a circle should look like with the sun at the top right — eight
sections, brightest toward the sun, darkest opposite (kept in
assets/references/) — "a smoother gradient probably", and noted it could
render any surface, water among them, with few bits per point, the ceramic
engine handling the updates. The circle now shades by direction round its
centre, blended; the turn is unchanged. Open: whether moving surfaces like
water should keep their points in the engine's shared memory.
