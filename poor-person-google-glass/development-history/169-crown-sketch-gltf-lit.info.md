<!-- made by scripts/file-screenshot on 2026-10-11 00:23, from the
     viewer run as: view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.1 40 0 --tilt 0.2 10 --screenshot 0.4 --views lit,annotated,joints -->

# 169 — crown-sketch-gltf-lit

- **Picture:** 169-crown-sketch-gltf-lit.png
- **Commit:** 3c0cb88d7 2026-10-10 poor-person-google-glass: the light pipe as a faceted, glowing hall, seen from inside
- **Run:** `view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.1 40 0 --tilt 0.2 10 --screenshot 0.4 --views lit,annotated,joints`
- **Uncommitted at the time:**
  -  M src/010-the-viewer.lua
  -  M src/018-the-light-pipe-model.lua
  - ?? input/calculations/bend-light-hold.lua
  - ?? scripts/render-gallery
  - ?? src/030-gif-writer.lua
  - ?? src/031-making-a-gif.lua
  - ?? src/032-the-gif-tests.test.lua

## What changed

Compared with picture 168:
- changed: src/010-the-viewer.lua
- changed: src/030-gif-writer.lua
- changed: src/031-making-a-gif.lua
- changed: src/032-the-gif-tests.test.lua


## What it shows

Gallery still: crown-sketch-gltf-lit, in the 1280 x 800 window.

## The story so far

The owner asked for picture renders and GIFs of the display work. The viewer records frames (a turn on the plinth, a walk through stations), the project's own GIF encoder makes them into moving pictures, and a gallery script gathers every model's stills and GIFs into output/gallery/. These stills were taken by the gallery run.
