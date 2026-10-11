<!-- made by scripts/file-screenshot on 2026-10-10 22:26, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 047 — even-splotches-no-blur

- **Picture:** 047-even-splotches-no-blur.png
- **Commit:** f99ef3260 2026-10-10 centered-ui-design: personal space, and two view dials turned by key and wheel
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/003-the-far-camera.lua
  -  M src/007-seeding-the-units.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/main.lua

## What changed

Compared with picture 046:
- changed: input/game-settings.lua
- changed: src/003-the-far-camera.lua
- changed: src/007-seeding-the-units.lua
- changed: src/013-the-world-renderer.lua
- changed: src/014-the-dashboard.lua
- changed: src/016-the-game.lua
- changed: src/017-the-tests.test.lua
- changed: src/main.lua

Settings, before (<) and now (>):

```
<     view_blur = "on",
>     view_blur = "off",
```

## What it shows

Noon, blur off, the terrain re-seeded: every splotch the same size and
spaced so each stretch of ring holds about as many — sparse just above the
console, thicker toward the far rings. Everything is sharp from the
console to the map's edge; villagers stand clear among the splotches.

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
