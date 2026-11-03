<!-- made by scripts/file-screenshot on 2026-10-10 22:02, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --screenshot 24.5 -->

# 025 — magic-circle-450-degrees-at-noon

- **Picture:** 025-magic-circle-450-degrees-at-noon.png
- **Commit:** 11d975d1d 2026-10-10 centered-ui-design: the world's rings follow the console's arch
- **Run:** `run --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/003-the-far-camera.lua
  -  M src/012-made-by-formula.lua
  -  M src/013-the-world-renderer.lua
  -  M src/014-the-dashboard.lua
  -  M src/016-the-game.lua
  -  M src/017-the-tests.test.lua
  -  M src/025-the-focus-ring.lua

## What changed

Compared with picture 024:
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/003-the-far-camera.lua
- changed: src/013-the-world-renderer.lua
- changed: src/017-the-tests.test.lua
- changed: src/025-the-focus-ring.lua

Settings, before (<) and now (>):

```
>     -- how many degrees of the world one arch shows foot to foot: 90 is just
>     -- this seat's quadrant; past 360 the circle runs on past itself (a
>     -- "magic circle"), the far side of the world showing at both ends
>     arch_span_degrees = 450,
```

## What it shows

Noon on the second day, the arch now spanning 450 degrees foot to foot
instead of one quadrant's 90. Three seats' quadrants fit above the console
as wide fans with soft edges: seat 1's brown in the middle with its gold
section a round patch (no longer a long crescent), seat 4's green at the
left with its lime section, seat 2's grey-green at the right with its cyan
section. Many more villagers are in view, carrying cuboids toward their
sections. The named slot reads SEAT 1 - LEVEL 2 (the mouse pointer was over
a villager).

## The story so far

Through the slant view (012-014), walking on the sphere (015-016) and the
arch view (017-019), the camera came to look across the console like a
desk, and the owner found its metal's reflection "pretty intense ... it
looks weird at this angle". This cycle redesigns the metal (020-024):
brushed along the arch, lit by the time of day like the world, a soft sheen
at its far edge, a faint highlight sliding with the hour, and a panel lamp
so it can be read at night. The owner also laid out the two teams — ours A
B over C D at the hub, the foes 1 2 over 3 4 at the far pole, each pair
facing across the sphere — and asked for "magic circles that had more than
360 degrees of rotation" so more fits on screen (025-027): one arch now
spans a set angle foot to foot, and past a full turn the same ground shows
twice. Waiting on the owner: which span feels right, how vague far reports
should be, and what the Greek stage's staircase means.
