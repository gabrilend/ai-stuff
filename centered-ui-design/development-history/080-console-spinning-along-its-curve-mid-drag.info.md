<!-- made by scripts/file-screenshot on 2026-10-10 23:40, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --drag 24 1100 990 600 990 1.0 --screenshot 24.6 -->

# 080 — console-spinning-along-its-curve-mid-drag

- **Picture:** 080-console-spinning-along-its-curve-mid-drag.png
- **Commit:** 372ebe4f6 2026-10-10 centered-ui-design: gradient sheen-points, and a sun that circles the hub
- **Run:** `run --drag 24 1100 990 600 990 1.0 --screenshot 24.6` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M src/014-the-dashboard.lua
  -  M src/015-the-view-plane.lua
  -  M src/017-the-tests.test.lua

## What changed

Compared with picture 079:
- commit: b4eb379a1 -> 372ebe4f6
- changed: src/014-the-dashboard.lua
- changed: src/015-the-view-plane.lua
- changed: src/017-the-tests.test.lua


## What it shows

Mid-drag along the console: the console's contents are carried along the
arch's curves — the calendar, readouts and buttons of the seat in front
sliding left and down toward the left foot, stretched along the curve; the
right-hand buttons (FLANK, SHIELD, BUILD) risen toward the apex and drawn
out wide; the next seat's band edge rising in at the right foot. The world
above has turned with it.

## The story so far

With the sun circling the hub (077-079), the owner saw that spinning to a
neighbour's seat still slid the consoles in sideways, "forgetting to curve
it around the arc of the dashboard": they should slide "along the curved
texture, same as the map". The console is now drawn once at home and the
sheet that shows it carries each pixel along its arch-shaped ring by the
spin, half a turn of the curve per seat; clicks go back the same way; each
seat's band shows its own quadrant (080-081). A see-in-3d model of a rigid
wheel of seats showed how that differs from this belt-like motion — asked.
