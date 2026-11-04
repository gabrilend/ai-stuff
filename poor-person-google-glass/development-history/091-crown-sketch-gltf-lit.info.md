<!-- made by scripts/file-screenshot on 2026-10-10 23:38, from the
     viewer run as: view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.1 60 0 --tilt 0.15 30 --screenshot 0.7 --views lit -->

# 091 — crown-sketch-gltf-lit

- **Picture:** 091-crown-sketch-gltf-lit.png
- **Commit:** e9bccc358 2026-10-10 poor-person-google-glass: tolerance records kept on the model, one per joint
- **Run:** `view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.1 60 0 --tilt 0.15 30 --screenshot 0.7 --views lit`
- **Uncommitted at the time:**
  -  M input/viewer-settings.lua
  -  M src/007-read-the-input.lua
  -  M src/009-the-orbit-camera.info.md
  -  M src/009-the-orbit-camera.lua
  -  M src/010-the-viewer.lua
  -  M src/011-the-tests.test.lua

## What changed

Compared with picture 090:
- commit: d18378df5 -> e9bccc358
- changed: input/viewer-settings.lua
- changed: src/007-read-the-input.lua
- changed: src/009-the-orbit-camera.lua
- changed: src/010-the-viewer.lua
- changed: src/011-the-tests.test.lua

Settings, before (<) and now (>):

```
>     -- false: the window keeps its size (a tiling window manager leaves it
>     -- floating), so it and its pictures stay one size
>     window_resizable = false,
>     -- the mouse within this many pixels of an edge slides the pillar the
>     -- model stands on; how fast, as a share of the viewing distance per second
>     edge_margin_pixels = 40,
>     edge_speed = 0.8,
```

## What it shows

The crown sketch in the new 1280 x 800 window, turned 0.6 radians by a left-drag (side to side only) and tilted down by a right-drag: the band from above and in front, the panel arm and panel at the right, small in the wide frame.

## The story so far

The owner asked for the viewer to hold a model like a museum artifact on a plinth inside a round case: left-drag turns it around an upright pillar, right-drag tilts, the wheel zooms, and the mouse near an edge slides the pillar. The window was also made a fixed size, so the tiling window manager leaves it floating at 1280 x 800 instead of stretching it to a tall tile; every picture from here on is that size, so the scripted test pictures were all taken anew.
