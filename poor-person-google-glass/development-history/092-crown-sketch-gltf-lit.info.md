<!-- made by scripts/file-screenshot on 2026-10-10 23:38, from the
     viewer run as: view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.1 60 0 --tilt 0.15 30 --mouse 0.2 1275 400 --screenshot 0.7 --views lit -->

# 092 — crown-sketch-gltf-lit

- **Picture:** 092-crown-sketch-gltf-lit.png
- **Commit:** e9bccc358 2026-10-10 poor-person-google-glass: tolerance records kept on the model, one per joint
- **Run:** `view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.1 60 0 --tilt 0.15 30 --mouse 0.2 1275 400 --screenshot 0.7 --views lit`
- **Uncommitted at the time:**
  -  M input/viewer-settings.lua
  -  M src/007-read-the-input.lua
  -  M src/009-the-orbit-camera.info.md
  -  M src/009-the-orbit-camera.lua
  -  M src/010-the-viewer.lua
  -  M src/011-the-tests.test.lua

## What changed

Compared with picture 091:
- no source or settings file changed (same program; another view, file or moment)


## What it shows

As 091, after the mouse rested at the right edge for half a second: the pillar slid 183 mm to the right, level, so the crown has moved left in the frame, its left side cut off by the edge.

## The story so far

The owner asked for the viewer to hold a model like a museum artifact on a plinth inside a round case: left-drag turns it around an upright pillar, right-drag tilts, the wheel zooms, and the mouse near an edge slides the pillar. The window was also made a fixed size, so the tiling window manager leaves it floating at 1280 x 800 instead of stretching it to a tall tile; every picture from here on is that size, so the scripted test pictures were all taken anew.
