# 1010 — Modeller: drawer and inter-app integration

## Current behavior

The modeller renders (1009) but has no drawer content and no
exits to other apps. Everything happens in the perspective view
and the inspector with no menu to organise the operations.

## Intended behavior

The modeller's four drawers:

- **Bottom-left (model menu):** new model, open model, save
  model, save as, merge with, set interior policy, close
  current model.
- **Bottom-right (face menu, contextual):** edit color, edit
  roughness, flip normal, delete face. Active when a face is
  highlighted.
- **Top-left (view menu):** rotate to front, rotate to back,
  rotate to side, reset zoom, toggle auxiliary model
  visibility (during a merge).
- **Top-right (exits and settings):** "to files" (browse
  `/models/`), "to programming environment" (open the model
  as a soramech map for direct editing).

The `links.json`:

```json
{
  "exits": [
    { "name": "to files",     "target": "files",   "value_type": "text" },
    { "name": "to programming environment",
      "target": "programming-env", "value_type": "map-path" }
  ]
}
```

`entries.json`:

```json
{
  "entries": [
    { "name": "default",    "value_type": "text" },
    { "name": "open-model", "value_type": "map-path" }
  ]
}
```

The `open-model` entry accepts a model path from any other app
that wants to push a model to the modeller (the files app's
"open in modeller" exit, for instance).

The modeller's interaction with the programming environment is
direct: opening a model in the programming environment shows
the same vertex and face boxes through the soramech canvas,
where the user can edit them as map structure rather than as
3D geometry. Edits in the canvas reflect in the modeller's
view and vice versa.

## Suggested implementation steps

1. Drawer content sub-maps for the four drawers.
2. `links.json` and `entries.json`.
3. The contextual activation of the face menu.
4. The "open in programming environment" wire-up.

## Related documents

- `docs/010-modeller.md`.
- `docs/008-apps-overview.md`.

## Blocked by

608, 609, 610, 1006, 1007, 1009.

## Blocks

1011.
