<!-- made by scripts/file-screenshot on 2026-10-10 22:23, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 24 a -5 --screenshot 24.5 -->

# 045 — painted-terrain-seen-near

- **Picture:** 045-painted-terrain-seen-near.png
- **Commit:** f99ef3260 2026-10-10 centered-ui-design: personal space, and two view dials turned by key and wheel
- **Run:** `run --wheel-with 24 a -5 --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/007-seeding-the-units.lua
  -  M src/013-the-world-renderer.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua

## What changed

Compared with picture 044:
- no source or settings file changed (same program, different run or moment)


## What it shows

Meant as five notches nearer (0.6), but the distance dial reads 0.9: the
person's own input had reached the scripted run (the window had focus).
Splotches large near the console; seat 1's section at the top.

## The story so far

After personal space and the A and S view dials (034-041), the owner asked
for test terrain: "different colors painted in splotches on the ground ...
closer circles drawn on-top", each tipped toward the camera to curve a
little, one side bright and one dark. The first splotches (042-046) varied
in size and were spread evenly by tier; the owner then asked for one size,
as many to every stretch of ring (so more on the longer rings deeper out),
and no blur ("it's clearer without it") (047-049). Along the way, scripted
runs were found to take the owner's own typing and mouse (the window opens
on their screen and takes focus): a wrong distance in 045 and 046, stray
spins earlier. Scripted runs now ignore the person's input.
