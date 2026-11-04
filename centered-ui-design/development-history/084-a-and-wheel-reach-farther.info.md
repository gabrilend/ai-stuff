<!-- made by scripts/file-screenshot on 2026-10-10 23:47, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 24 a 4 --screenshot 24.5 -->

# 084 — a-and-wheel-reach-farther

- **Picture:** 084-a-and-wheel-reach-farther.png
- **Commit:** c1fec5a53 2026-10-10 centered-ui-design: the console spins along its own curve, as the map does
- **Run:** `run --wheel-with 24 a 4 --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M scripts/run-tests
  -  M src/016-the-game.lua
  -  M src/main.lua

## What changed

Compared with picture 083:
- no source or settings file changed (same program, different run or moment)


## What it shows

A held, four notches: the distance dial reads 1.5; the map shrinks toward
the console under black sky.

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
