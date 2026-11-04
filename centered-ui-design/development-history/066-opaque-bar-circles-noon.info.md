<!-- made by scripts/file-screenshot on 2026-10-10 22:51, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 066 — opaque-bar-circles-noon

- **Picture:** 066-opaque-bar-circles-noon.png
- **Commit:** 1abb118e6 2026-10-10 centered-ui-design: the land painted by turned circles
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua

## What changed

Compared with picture 065:
- changed: input/game-settings.lua

Settings, before (<) and now (>):

```
<     view_circle = "bars-open",
>     view_circle = "bars",
```

## What it shows

The opaque bar circles at the same moment and distance, for comparison
with 065: each a crisp spiral on dark, the land darker and more patterned.

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
