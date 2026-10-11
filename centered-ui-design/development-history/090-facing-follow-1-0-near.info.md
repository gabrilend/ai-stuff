<!-- made by scripts/file-screenshot on 2026-10-10 23:54, from the
     game run as: run /mnt/mtwo/programming/ai-stuff/centered-ui-design --wheel-with 24 a -4 --screenshot 24.5 -->

# 090 — facing-follow-1-0-near

- **Picture:** 090-facing-follow-1-0-near.png
- **Commit:** 4808343fa 2026-10-10 centered-ui-design: view dials proven end to end, a steady console, upright villagers
- **Run:** `run --wheel-with 24 a -4 --screenshot 24.5` (from /mnt/mtwo/programming/ai-stuff/centered-ui-design)
- **Uncommitted at the time:**
  -  M input/game-settings.lua
  -  M src/001-read-the-input.lua
  -  M src/003-the-far-camera.lua
  -  M src/013-the-world-renderer.lua

## What changed

Compared with picture 089:
- changed: input/game-settings.lua

Settings, before (<) and now (>):

```
<     figure_facing_follow = 0.5,
>     figure_facing_follow = 1.0,
```

## What it shows

Follow 1, zoomed in: as 089 — the rings are flat here; the examples were retaken at the ordinary distance.

## The story so far

With villagers standing up the screen (085-087), the owner saw that those
walking round a ring still looked as if they walked plainly left and right,
and asked that they turn their backs to the camera walking toward the
middle and face it walking toward the sides — following the ring's curve
on screen — and to see examples. A setting blends from the ground heading
(0) to the on-screen path (1); pictures at 0, 0.5, 1 and 1.5, first zoomed
in (088-091, which showed only the flat middle of the rings) and then at
the ordinary distance (092-095). Waiting on the owner's choice.
