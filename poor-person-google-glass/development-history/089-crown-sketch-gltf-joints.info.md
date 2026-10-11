<!-- made by scripts/file-screenshot on 2026-10-10 23:30, from the
     viewer run as: view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.2 60 20 --screenshot 0.5 --views joints -->

# 089 — crown-sketch-gltf-joints

- **Picture:** 089-crown-sketch-gltf-joints.png
- **Commit:** 2620ab43a 2026-10-10 poor-person-google-glass: tolerance calculations, with a format to write them in
- **Run:** `view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.2 60 20 --screenshot 0.5 --views joints`
- **Uncommitted at the time:**
  -  M scripts/run-tests
  -  M src/008-say-goodbye.lua
  -  M src/010-the-viewer.lua
  -  M src/019-a-calculation-and-its-checks.lua
  -  M src/022-calculate.lua
  - ?? input/calculations/joint-gap-under-heat.lua
  - ?? input/joints/
  - ?? input/materials.lua
  - ?? src/024-writing-lua-data.lua
  - ?? src/025-materials.lua
  - ?? src/026-finding-joints.lua
  - ?? src/027-joint-records.lua
  - ?? src/028-joints.lua

## What changed

Compared with picture 088:
- commit: d0c94b3e0 -> 2620ab43a
- changed: src/008-say-goodbye.lua
- changed: src/010-the-viewer.lua
- changed: src/019-a-calculation-and-its-checks.lua
- changed: src/020-working-out-tolerances.lua
- changed: src/021-the-tolerance-report.lua
- changed: src/022-calculate.lua
- changed: src/023-the-tolerance-tests.test.lua
- changed: src/024-writing-lua-data.lua
- changed: src/025-materials.lua
- changed: src/026-finding-joints.lua
- changed: src/027-joint-records.lua
- changed: src/028-joints.lua


## What it shows

The crown sketch from above and in front, joints view: seven round marks where parts meet, each labelled with its two parts and its state — grey for the five empty records (band/emitters, emitters/light pipes, band/dials, light pipes/dials, band/panel arm), red for band/light pipes (fail), green for panel arm/panel (pass). Grey labels hard to read over the dark band.

## The story so far

After the tolerance calculations, the owner asked for the viewer to keep tolerance records: an empty spot for every place two pieces meet, filled with an equation whose inputs come from the model's structure and its materials. This is the first picture of those records on the model; the crown sketch has materials and two joints filled in as an example.
