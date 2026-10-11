<!-- made by scripts/file-screenshot on 2026-10-10 22:09, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 030 — console-at-forty-percent-calendar-fixed

- **Picture:** 030-console-at-forty-percent-calendar-fixed.png
- **Commit:** ea3d1a658 2026-10-10 centered-ui-design: a console lit like a desk, and magic circles
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/003-the-far-camera.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua

## What changed

Compared with picture 029:
- changed: src/003-the-far-camera.lua
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua
- changed: src/017-the-tests.test.lua


## What it shows

The orders face repaired: the calendar's rings now take their radii from
their windows, so OCTOBER, SUNDAY and 11 read in their windows (the edges
of the neighbouring months peek in at the sides, as on a watch's date
wheel); ESCAPE: SETTINGS has moved clear of the right-hand buttons.

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
