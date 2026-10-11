<!-- made by scripts/file-screenshot on 2026-10-10 23:53, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 24 a -4 --screenshot 24.5 -->

# 088 — facing-follow-0-0-near

- **Picture:** 088-facing-follow-0-0-near.png
- **Commit:** 4808343fa 2026-10-10 centered-ui-design: view dials proven end to end, a steady console, upright villagers
- **Run:** `run --wheel-with 24 a -4 --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/003-the-far-camera.lua
  -  M src/013-the-world-renderer.lua

## What changed

Compared with picture 087:
- commit: 2ae949951 -> 4808343fa
- changed: input/game-settings.lua
- changed: src/001-read-the-input.lua
- changed: src/003-the-far-camera.lua
- changed: src/013-the-world-renderer.lua

Settings, before (<) and now (>):

```
>     -- under the arch view, how much a villager turns to face its path on
>     -- screen: 0 faces its way on the ground (looks like walking left and
>     -- right), 1 follows the ring's curve (back to the camera walking toward
>     -- the middle, facing it walking toward the sides); between or beyond
>     -- to compare
>     figure_facing_follow = 0.0,
> 
```

## What it shows

Follow 0, zoomed in. Only the left third drawn (the window was covered during the capture).

## The story so far

With villagers standing up the screen (085-087), the owner saw that those
walking round a ring still looked as if they walked plainly left and right,
and asked that they turn their backs to the camera walking toward the
middle and face it walking toward the sides — following the ring's curve
on screen — and to see examples. A setting blends from the ground heading
(0) to the on-screen path (1); pictures at 0, 0.5, 1 and 1.5, first zoomed
in (088-091, which showed only the flat middle of the rings) and then at
the ordinary distance (092-095). Waiting on the owner's choice.
