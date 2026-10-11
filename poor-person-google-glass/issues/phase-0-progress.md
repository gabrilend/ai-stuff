# Phase 0 Progress — Tools

## Goals
Instruments the other phases use. First: a CAD viewer, so the crown's parts
can be modelled in any CAD program and looked at here, in 3D; then a way to
make models from words alone, so parts can be sketched by their
relationships before anyone knows a single measurement.

For current done/open counts, run:

    /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /home/ritz/programming/ai-stuff/poor-person-google-glass -m

## Completed Issues
- **001 — A shape as triangles.** The one record every reader fills and the
  viewer draws, so file formats and drawing never touch; and the formula-made
  cube and crown sketch, so no test model is drawn by hand.
- **002 — Reading and writing STL.** Both kinds, told apart by size; y-up
  shapes are turned to STL's z-up on the way out so they stand upright.
- **003 — Reading and writing OBJ.** Parts and material colours; colour
  from pictures deliberately not read (the owner's own voxel engine will
  do particle colour by equations instead).
- **004 — Reading and writing glTF.** The house format (structured JSON):
  parts, colours, placements down a node tree, base64 or .bin buffers, .glb;
  keys written in a fixed order, so the same shape always gives the same
  bytes.
- **007a–007e — From words to a model.** A closed vocabulary with its
  contract document, a reader that refuses everything it cannot read at
  once with suggestions, a solver for sizes, directions and places, a builder
  for five kinds of solid, and `./describe`. Four example objects, including
  the owner's rectangular-lensed glasses.

- **008 — Standing inside a model.** A model can bring its own places to
  stand and the haze of what fills it; the viewer steps through them and,
  from the pixels of the flat-colour view, measures which parts each place
  shows — so "every feature seen at least once" is a checked number.

## In progress
- **005 — The viewer** works: pictures from its own canvas in six views,
  filed in development-history/. Waits on: reading on several threads; how
  many pictures to keep.
- **006 — The demo** works; closes after 005 and 007.
- **007 — From words to a model**: all pieces built; waits on: free English
  through a language model; parts pointing the other way.
