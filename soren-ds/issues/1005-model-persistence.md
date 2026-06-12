# 1005 — Model persistence

## Current behavior

A model in progress lives in RAM (1001–1004) but vanishes on
exit. The modeller needs to write its current state to the SD
card so the user can come back to it.

## Intended behavior

A model saves as a directory under `/models/<name>/`. The
directory follows the standard soramech-map layout from 302:

- `meta.json` — name, description, entry box id (the model's
  root), src_dirs (empty — models contain no executable code).
- `boxes/` — one JSON file per vertex and per face. Each vertex
  is a `read` box carrying its (x, y, z) coordinates as its
  literal value. Each face is a `call` box whose function is
  the kernel's `face-render` (a leaf box that emits the face's
  polygon for the perspective view) and whose connections wire
  the three or four vertex boxes into its inputs.

A model's "function" is its rendering — running the model's map
emits the polygon list the perspective view consumes. This is
also what makes encapsulation natural: encapsulating a model
into another model means including its sub-graph of vertex and
face boxes into the parent.

Save flow:

1. The drawer's "save" option captures the current vertex grid
   and face list.
2. A serialiser walks the grid and the faces, producing
   `meta.json` and one box JSON file per vertex / face.
3. `write-path` (406) writes each file under
   `/models/<name>/`. The name comes from a name-picker
   sub-flow if the model is unnamed.
4. Encapsulation marks are added: every vertex's `external`
   block declares the vertex as a possible input port; every
   face's `external` block declares the face as a possible
   output port. This is what makes the saved model encapsulate
   cleanly into a parent model (1007).

## Suggested implementation steps

1. `model_serialize(grid, faces, out_dir)`.
2. The vertex-to-box JSON translation.
3. The face-to-box JSON translation.
4. The external-port declarations on every box.
5. Drawer "save" wiring with name picker.

## Related documents

- `docs/010-modeller.md`.
- `docs/012-soramech-runtime.md` — encapsulated sub-maps.
- `docs/011-filesystem.md`.

## Blocked by

305, 406, 1003, 1004.

## Blocks

1006, 1007.
