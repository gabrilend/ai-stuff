<!-- made by scripts/file-screenshot on 2026-10-10 22:47, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 20 a -6 --screenshot 20.5 -->

# 060 — bar-circles-morning-near

- **Picture:** 060-bar-circles-morning-near.png
- **Commit:** 1abb118e6 2026-10-10 centered-ui-design: the land painted by turned circles
- **Run:** `run --wheel-with 20 a -6 --screenshot 20.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua

## What changed

Compared with picture 059:
- commit: 632aaea7d -> 1abb118e6
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/013-the-world-renderer.lua
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua

Settings, before (<) and now (>):

```
>     -- how each terrain circle is drawn: "shade", dark pole to bright pole;
>     -- or "bars", a spiral of bars growing from none to the rim, to watch
>     -- each circle's turn (the longest bar where the bright pole would be)
>     view_circle = "bars",
```

## What it shows

Mid-morning, zoomed in (A held, six notches nearer): every terrain circle
drawn as a fan of bars around its centre, growing from nothing to the rim
— a spiral — on a dark background; the fans overlap like scales, each
showing its upper part, all turned alike across the flat land and turned
differently on the mesa's cliff at the top right.

## The story so far

With the land painted by turned circles (055-059), the owner asked to see
the turn itself: each circle drawn as a spiral of bars growing from none
(dark) to the rim (full colour), winding one way or the other by the sun's
side of the screen (060-062) — and then, "yes we are rotating around the
same axis!" — and to compare the bars with an opaque background and a
clear one (064-066). The owner also found dragging the console no longer
worked: with arches as wide as the screen, letting go settled on the
nearest seat only after half a screen of drag, so ordinary drags slid
back; a drag of a sixth of an arch now carries on to the next seat (063).
Waiting on the owner: what should use the "hold A and scroll" view
distance next, and the earlier questions.
