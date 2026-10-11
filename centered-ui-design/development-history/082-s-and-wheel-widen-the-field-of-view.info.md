<!-- made by scripts/file-screenshot on 2026-10-10 23:46, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 24 s 4 --screenshot 24.5 -->

# 082 — s-and-wheel-widen-the-field-of-view

- **Picture:** 082-s-and-wheel-widen-the-field-of-view.png
- **Commit:** 2ae949951 2026-10-10 centered-ui-design: the console spins along its own curve, as the map does
- **Run:** `run --wheel-with 24 s 4 --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M scripts/run-tests
  -  M src/016-the-game.lua
  -  M src/main.lua

## What changed

Compared with picture 081:
- commit: b9333d8c3 -> 2ae949951
- changed: src/016-the-game.lua
- changed: src/main.lua


## What it shows

S held, four notches: the field of view dial reads 659 degrees; the land
squeezed in from the sides, three seats' sections across.

## The story so far

After the console learned to spin along its curve (080-081), the owner
asked to be sure that holding S or A while scrolling really works. The
game now keeps its own list of held keys from key events — the path a
script's keys take too — and the test script checks the dials end to end
(082-084). The owner then saw the console's metal flashing: the metal
light dial carried about 220 fine streaks, and as it turned with the hour
the console's light flickered some ten times a second; the streaks are
gone. And the villagers leaned toward the viewer, the camera looking down
at 62 degrees; modelled with see-in-3d, then stood upright to the screen
like sprites (085-087).
