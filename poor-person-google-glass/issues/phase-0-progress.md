# Phase 0 Progress — Tools

## Goals
Instruments the other phases use. First: a CAD viewer, so the crown's parts
can be modelled in any CAD program and looked at here, in 3D.

For current done/open counts, run:

    /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /home/ritz/programming/ai-stuff/poor-person-google-glass -m

## Completed Issues
- **001 — A shape as triangles.** The one record every reader fills and the
  viewer draws, so file formats and drawing never touch; and the formula-made
  cube and crown sketch, so no test model is drawn by hand.
- **002 — Reading and writing STL.** Both kinds, told apart by size; y-up
  shapes are turned to STL's z-up on the way out so they stand upright.
- **004 — Reading and writing glTF.** The house format (structured JSON):
  parts, colours, placements down a node tree, base64 or .bin buffers, .glb.

## In progress
- **003 — OBJ** works and is tested; waits on whether to read texture
  colours.
- **005 — The viewer** works and is tested (scripted runs, goodbye receipt,
  black-capture check); waits on whether to read on several threads.
- **006 — The demo** works; closes after 003 and 005.
