# poor-person-google-glass - Table of Contents

Every document in docs/ and notes/ belongs somewhere in this tree. Source code
and issue files do not; they have their own indexes.

## Vision
- notes/vision - the founding description, in the owner's own words. Written
  first, read most.

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
    picture (phase 0).
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
- view-cad - opens a CAD file (STL, OBJ, glTF) in the 3D viewer.
- scripts/run-tests - every test, including a scripted viewer window.
- scripts/make-test-shapes - writes the formula-made test models in every
  format.
- input/viewer-settings.lua - the viewer's window, view and colours.
