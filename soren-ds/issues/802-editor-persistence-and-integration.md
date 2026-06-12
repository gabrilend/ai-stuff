# 802 — Editor: persistence and inter-app integration

## Current behavior

The editor renders and accepts input (801) but documents live
only in RAM — close the editor and the work is gone. There is no
drawer with file-open and file-save actions, and no inter-app
exits to send the current document elsewhere.

## Intended behavior

The editor's drawers each present a small radial menu:

- **Bottom-left drawer (and top-left if focused there):** file
  menu — "open", "save", "save as", "new document".
- **Bottom-right drawer (and top-right):** exits — "to
  messenger" (send the document body as a new message), "to
  files" (hand the document path to the files app for
  relocation or rename), "to programming environment" (open
  the document as a soramech box's source).

The file menu's operations wire to the filesystem boxes:

- "open" — a file picker sub-flow (lists `/programs/` and
  subdirectories via `list-directory`; user picks via touch or
  radial menu; `read-path` loads the bytes into the focused
  panel).
- "save" — `write-path` to the document's current path. If the
  document is unnamed, falls through to "save as".
- "save as" — a name picker sub-flow, then `write-path`.
- "new document" — clears the focused panel, marks the
  document unnamed.

The inter-app exits use the link declaration (609) and the link
transition (610) from phase 6. Each exit's value type is `text`
(the document body) for messenger, `text` for files, and `text`
for the programming environment.

Documents save to `/programs/` by default. Each document is its
own directory with a `meta.json`, a `boxes/` directory if the
document is a map, and `src/*.c` files if the document contains
box source. A plain-text document is just a single `.txt` file at
the document's path.

## Suggested implementation steps

1. Drawer content sub-map for the editor's four drawers.
2. File picker and name picker sub-flows.
3. Wire the file menu to `read-path`, `write-path`,
   `list-directory`.
4. The editor's `links.json` and `entries.json` per 609.

## Related documents

- `docs/004-input-model.md`.
- `docs/005-display-and-compositor.md`.
- `docs/008-apps-overview.md`.
- `docs/011-filesystem.md`.

## Blocked by

406, 407, 608, 609, 610, 801.

## Blocks

811.
