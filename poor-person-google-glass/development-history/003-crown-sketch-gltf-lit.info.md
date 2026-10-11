<!-- made by scripts/file-screenshot on 2026-10-10 21:47, from the
     viewer run as: view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.2 60 20 --screenshot 0.5 --views lit,annotated -->

# 003 — crown-sketch-gltf-lit

- **Picture:** 003-crown-sketch-gltf-lit.png
- **Commit:** e9924b358 2026-10-10 poor-person-google-glass: a CAD viewer, and a phase of tools beneath the crown
- **Run:** `view-cad /dev/shm/poor-person-google-glass/shapes/crown-sketch.gltf --drag 0.2 60 20 --screenshot 0.5 --views lit,annotated`
- **Uncommitted at the time:**
  -  M src/008-say-goodbye.lua
  -  M src/009-the-orbit-camera.lua
  -  M src/010-the-viewer.lua
  -  M view-cad
  - ?? scripts/file-screenshot

## What changed

Compared with picture 002:
- no source or settings file changed (same program; another view, file or moment)


## What it shows

The same lit view as 001, turned about 10 degrees further: the owner's game keys reached the window (the spin key), which is how the window's focus problem was found.

## The story so far

The project began the same evening as a head-worn projector design (the crown) with no code. Phase 0 (tools) was added for a CAD viewer: STL, OBJ and glTF read into one shape record and drawn in a LÖVE window. The first screenshots were read from the screen and came back black while the owner played a game over the window; the viewer was rebuilt to draw into its own canvas and save pictures from it, in six views. These are its first pictures; 001 and 003 differ because the owner's keys reached the window.
