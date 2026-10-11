# poor-person-google-glass - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description, in the owner's own words. Written
  first, read most.
- notes/ideas - ideas the owner said in passing that belong to no issue
  yet (her own voxel engine, curve fitting, a Tantive IV turret game), kept
  word for word.

## Documentation
- docs/table-of-contents.md - this file.
- docs/core-terms.md - the agreed names for every part: crown, emitter, light
  pipe, filling, tab, slot, mask, store, aperture, release, panel, panel arm,
  dials, A/B, pocket stick, cuff, heat fins, air pumps.
- docs/how-it-works.md - the device in one page: three flows (light,
  decisions, heat) and what changes how fast.
  - docs/datapath-light.md - from a picture to light on the panel.
  - docs/datapath-input.md - from a turned dial to a new picture or arm pose.
  - docs/datapath-heat.md - from heat sources to throttle, pumps and fins.
  - docs/datapath-cad-viewer.md - from a model file to a lit, turnable
    picture, its six views, and how pictures are kept (phase 0).
  - docs/datapath-words-to-model.md - from a description in words to a
    model (phase 0).
- docs/shape-words.md - every word a description may use, and what it
  means: the contract for ./describe.
- docs/physics-check.md - each part set against known physics and the
  closest device that already exists.
- docs/roadmap.md - the phases (0 to 6) and the demo each ends with.
- docs/open-questions.md - every question met so far, waiting for an answer.
- docs/balance-updates.md - append-only log of knobs turned and why.

## Phases
Phases group related functionality, not calendar time. It is normal for the
last issue completed in a project to belong to phase 1.

0. Tools - instruments for the other phases; first, the CAD viewer.
   (issues/phase-0-progress.md)
1. The mask - tabs, slots, and the picture they let through.
   (issues/phase-1-progress.md)
2. The stored light - the light budget, the store and its aperture.
   (issues/phase-2-progress.md)
3. The panel on its arm - where the light lands, and the safety rule.
   (issues/phase-3-progress.md)
4. The inputs - dials, buttons, stick, cuff, one decision table.
   (issues/phase-4-progress.md)
5. The crown and its heat - layout, heat, throttle, pumps, fins.
   (issues/phase-5-progress.md)
6. The whole crown - every phase on one clock. (issues/phase-6-progress.md)

## Project files
- .file-index-counter - the highest reading-order index used by any file in
  the project, so a new file can take the next number without a search.
- run-phase-demo - asks which completed phase to demonstrate, then runs it.
- view-cad - opens a CAD file (STL, OBJ, glTF) in the 3D viewer, and files
  every picture it takes.
- describe - turns a description in words (input/descriptions/) into a model
  and a report (output/described/).
- development-history/ - every picture the viewer has taken, numbered, each
  with notes on what made it and what changed.
- scripts/file-screenshot - files pictures into development-history/.
- scripts/run-tests - every test, including a scripted viewer window.
- scripts/make-test-shapes - writes the formula-made test models in every
  format.
- scripts/make-light-pipe - writes the light pipe's inside, with its
  stations, to output/models/light-pipe.gltf.
- input/viewer-settings.lua - the viewer's window, view and colours.
- input/descriptions/ - objects described in words: a drum, a lamp, the
  crown, glasses.
