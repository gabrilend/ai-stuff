# 1006 — Model loading

## Current behavior

Models save (1005) but can't yet be loaded back — opening a
model is symmetric work the modeller doesn't yet do.

## Intended behavior

The drawer's "open" option lets the user pick a model directory
from `/models/` (via `list-directory` from 407) and loads it
into the modeller's working state. The flow:

1. The user picks `/models/<name>/` from the drawer's file
   picker.
2. The modeller's loader walks the directory's box files,
   parses each, reconstructs the vertex grid by reading every
   vertex box's literal coordinates and placing the vertex in
   the grid at those coords.
3. Reconstructs each face by reading the face box's input
   connections (which name the vertices that compose it),
   restoring the face's color and roughness from the box's
   JSON metadata fields.
4. Replaces the modeller's current grid and face list with the
   loaded ones. The undo history resets.
5. Centers the perspective view on the model's centroid for an
   immediate visible result.

The load path is the inverse of the save path; both share the
on-disk format. A model authored on one device and transferred
to another (via the USB inbox, an rmail attachment, or a manual
SD card copy) loads identically.

A malformed model directory is a hard error reported to the
user — the load doesn't half-restore a broken state.

## Suggested implementation steps

1. `model_deserialize(in_dir, grid_out, faces_out)`.
2. The vertex restoration pass.
3. The face restoration pass.
4. Drawer "open" wiring with file picker.
5. Auto-centering on the model's centroid.

## Related documents

- `docs/010-modeller.md`.
- `docs/011-filesystem.md`.

## Blocked by

407, 1005.

## Blocks

1007, 1011.
