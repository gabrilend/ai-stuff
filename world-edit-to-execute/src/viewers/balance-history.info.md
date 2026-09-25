# balance-history.html

A self-contained page (no network) that draws `history.js` from
`src/cli/balance-history.lua`, copied beside it by `scripts/balance-history.sh`.

- **Heat map**: how many numbers each version changed from the one before,
  per kind of object (unit, ability, item, upgrade); hover a cell for the count.
- **Object list**: search by name or id, filter by kind, sorted by how many
  of the object's numbers changed.
- **Per-object charts**: one step chart per changed field, version on the x
  axis; larger points mark a change; hover for the value and what it was.
- **Patch view**: pick a version from the header menu or click a heat-map
  column to see every number it changed from the version before, grouped by
  object, old → new with the difference (issue 115a).
- **Versions the project doesn't read** (issue 115b): when `notes.js` is
  present, they appear in the version menu and as hatched columns marked *
  on the heat map, every one labelled "not supported by this project — patch
  notes only"; the notes view opens with that banner, the reason (a later
  version left alone, or no patch program found), and the source page and
  licence. A notes page named for a version family the game already reads
  (Patch 1.14 beside 1.14b) isn't repeated. Notes are text only, never on the
  charts.
- **Address**: `index.html#tft/hkni` opens a game and an object;
  `index.html#tft/v/1.22a` opens a patch; `index.html#tft/n/1.32.10` a notes-only version.
- Light and dark themes (follows the system; the ◐ button switches and is
  remembered in this browser when storage is allowed).
