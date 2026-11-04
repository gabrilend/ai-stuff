<!-- made by scripts/file-screenshot on 2026-10-10 22:06, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 028 — console-at-forty-percent-orders

- **Picture:** 028-console-at-forty-percent-orders.png
- **Commit:** 0722349aa 2026-10-10 centered-ui-design: a console lit like a desk, and magic circles
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/014-the-dashboard.lua
  -  M src/017-the-tests.test.lua

## What changed

Compared with picture 027:
- commit: 11d975d1d -> 0722349aa
- changed: input/game-settings.lua
- changed: src/014-the-dashboard.lua
- changed: src/017-the-tests.test.lua

Settings, before (<) and now (>):

```
<     arch_height_share = 0.5,
>     arch_height_share = 0.2,
<     arch_span_degrees = 720,
>     arch_span_degrees = 450,
```

## What it shows

The console at 40% of its old area: a low, wide arch along the bottom
fifth of the screen, its surface laid out in one row — order buttons in
fours at each end, frame readouts left of center, the unit count and the
four section counts right, the calendar and the named slot (CLICK A UNIT)
in the middle. The calendar is broken: the month window is black, the
weekday window empty grey, the day number garbled — their paper rings were
drawn at the old fixed radii. The world above is larger than before (the
arch view grows from the lower arch): seat 1's section a big gold oval with
six stacked cuboids, villagers clearly limbed, the neighbours' green
quadrants at the lower sides.

## The story so far

After the console's metal was redone and the magic circles widened the
arch view (020-027), the owner asked for "40% as much dashboard in total
square footage". The arch keeps the window's full width, so it is now 40%
as tall — a fifth of the window — and its surface was laid out again in
rows across, at the old pixel sizes. Because the arch view's rings grow
from the arch, the lower arch also brought the world closer: figures are
larger. The shrink exposed three faults, each kept in a picture: the
calendar's rings had fixed radii and went blank (028), the settings row sat
on engraved labels (029), and clicking villagers stopped working (the
reach was tied to the console's height and fell to 10 pixels; also a
figure drawn twice by a magic circle could only be clicked at one copy).
030 and 031 show the repairs.
