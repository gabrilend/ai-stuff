<!-- made by scripts/file-screenshot on 2026-10-10 22:12, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --drag 24 600 990 100 990 1.0 --screenshot 24.6 -->

# 032 — spinning-the-console-mid-drag

- **Picture:** 032-spinning-the-console-mid-drag.png
- **Commit:** 7f80ba0d8 2026-10-10 centered-ui-design: a console 40% the size, and clicks that reach again
- **Run:** `run --drag 24 600 990 100 990 1.0 --screenshot 24.6` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/main.lua

## What changed

Compared with picture 031:
- commit: ea3d1a658 -> 7f80ba0d8
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua
- changed: src/main.lua


## What it shows

Half a second into a drag from right to left along the console. The whole
scene has slid: your arch (seat 1) has moved left, its calendar and
readouts now left of center and its left buttons partly off screen; seat
2's arch is coming in at the right, its ADVANCE button at the edge; between
the two arches' feet near the bottom a dark wedge shows (inside the arch's
curve there is no ground — the hub). Above, the world has turned with the
console: seat 1's gold section has moved left, and seat 2's grey-green
quadrant has come into the right side.

## The story so far

With the console shrunk to 40% and clicks working again (028-031), the
owner asked to "spin the dashboard by clicking and dragging" and to show
"the other player's buttons too ... the exact same arc ... when the other
player's orbit past". A press on the console's metal now takes hold of it:
the chair follows the hand, the row of arches and the world slide
together, and on letting go the chair settles on the nearest seat. Every
arch is drawn whole — its own buttons, dials, labels, and its seat in the
named slot. Next: villagers near the console allowed to crowd closer,
and the open questions (whether a spun-to ally's buttons should answer;
what should fill the hub's gap between arches while spinning).
