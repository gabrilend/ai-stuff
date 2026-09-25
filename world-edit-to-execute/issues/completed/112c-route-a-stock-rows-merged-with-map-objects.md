# Issue 112c: Route A, Stock Rows Merged With a Map's Objects

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High
**Dependencies:** 112b (per-map game data chains)

---

## Current Behavior

**Completed 2026-09-24.**

- `src/parsers/slk.lua` and `src/parsers/profile_txt.lua` parse the stock
  tables and profile files (`src/tests/test_slk.lua`, 17 checks, including
  real 1.21b data: Storm Bolt's 3 levels and 9-second cooldown).
- `src/gamedata/field_rules.lua` (reviewed data): the borrowed metadata types
  (Blizzard's text and art), id columns no metadata row names (ids, an
  ability's base `code`), and each kind's tables and profile files
  (abilities, units, items; both the `*Func.txt` and `*Strings.txt` files).
- `src/gamedata/stock_rows.lua` merges each object: stock parent's row
  through the map's chain, changes on top via the metadata table. **Every
  column is copied**, and each carries a label: `fact`, `borrowed`, `editor`
  or `map` (see Intended Behavior). Both of an object file's tables are
  handled: new objects (copied from a stock parent) and stock objects changed
  in place.
- `src/tests/test_stock_rows.lua`: DAoW-2.1's 315 abilities merge with no
  problems; its custom Animate Dead (`A003`) is checked field by field,
  labels included (its name "Raise Dead" is the map's; its tooltip and icon
  path are borrowed); all maps in `assets/` merge with no problems
  left; two kinds were found and fixed (run the test for current counts):
  - **Objects defined only in a map's own tables.** DAoW-5.2 and 5.3 ship
    their own `Units\AbilityData.slk` and item, buff and upgrade tables (a
    map optimizer's work), and define custom abilities only there. The chain
    reads the map's archive first (112b), so the map's changes to those
    abilities apply, and each object only the map's table defines gets a row
    of its own (`defined_in = "map table"`). These first showed up as 369
    "orphan" change sets, until the owner asked whether the triggers used
    those ids: the maps' units named 275 of them and their scripts 45.
    `test_stock_rows` checks DAoW-5.2's `A008` and that no orphans remain.
  - **Three-letter field codes.** Curse's chance-to-miss field is `Crs` in
    the metadata and `Crs\0` (padded with a zero byte) in map files, on
    stock Curse (`Acrs`) and copies of creep Curse (`ACcs`). The object-file
    reader (`src/parsers/objectdata.lua`) trims trailing zero bytes from ids;
    before that, 31 changes came out as the hex string `0x43727300` and were
    reported as unknown codes. Now every change in every test map applies:
    no orphans, no unknown codes, no unknown parents.

Before this: a map's object files (w3u, w3t, w3a, w3b, w3d, w3h, w3q) parse into lists of
changes (`src/parsers/objectdata.lua`): each custom object names the stock
object it copies (`original_id`) and lists changes as `field_id` (a 4-character
code such as `acdn`, cooldown), `level`, `column` and `value`. DAoW-2.1.w3x
alone has 315 custom abilities.

The stock values those changes sit on are readable through each map's chain
(`src/gamedata/chain.lua`): the data-set copy, then the plain path, in the
patch layer, then the archives. But nothing parses the stock tables yet:

- **SLK files** (`Units\AbilityData.slk` and the rest): a text spreadsheet
  format. `C;X3;Y12;K"Footman"` puts a value in column 3, row 12; a record
  that leaves out X or Y keeps the previous one. Row 1 holds the column names;
  column 1 holds each object's id.
- **Profile text files** (`Units\HumanUnitFunc.txt` and so on): INI-style
  `[id]` sections of `Key=value`; some gameplay values live here (missile
  speed and arc, for example), alongside art and text.
- **Metadata tables** (`Units\UnitMetaData.slk`, `AbilityMetaData.slk`, …):
  one row per field code: `field` (the column name), `slk` (which table:
  `UnitBalance`, `AbilityData`, `Profile`, …), `index`, `repeat` (levels),
  `data` (for abilities' `DataA`…`DataI` columns), and `type` (`int`,
  `real`, `string`, `model`, `icon`, …).

## Intended Behavior

For every custom object in a map: its full row, made of the stock object's
row from the map's chain with the map's changes laid over it, every column
copied. That's what W02h writes into the converted map's tables.

- **Field codes to columns.** From the metadata row: a level-dependent field
  (`repeat` > 0) maps to `field .. level` (`Cool1`); an ability data field maps
  to `"Data" .. letter(data) .. level` (`DataA1`); an indexed list field uses
  its `index`.
- **Copy everything, label whose it is.** Owner's decision (2026-09-24):
  "copy everything, and we will work slowly to replace all the artwork and
  such." Each column is labelled:
  - `fact`: numbers, flags, ids, lists of ids, order strings; what makes a
    map play the same.
  - `borrowed`: Blizzard's text and art (names, tooltips, icon, model and
    sound paths), by metadata `type`. Read from the player's own install, used
    only on their machine, never committed or shipped. Each is on a
    replacement track: names from the map or from our own gathered name
    lists; tooltips rebuilt by the UI from the facts they mirror ("tooltips
    are mirrors that reflect the values of facts and variables - they are
    part of the UI"); art by the asset forge.
  - `editor`: columns no metadata row describes (comments, sort keys);
    copied, never read by the game.
  - `map`: set by the map's own changes, whatever the type; the map author's
    value.
  The borrowed types are a reviewed data file, not code. The count of
  borrowed columns is how replacement progress is measured.
- **Errors, not guesses.** A field code with no metadata row, or a stock id not
  in the chain, is reported per map, never skipped silently.

## Suggested Implementation Steps

1. `src/parsers/slk.lua` and `src/parsers/profile_txt.lua`, with tests on small hand-made files and real 1.21b data (`src/tests/test_slk.lua`).
2. `src/gamedata/field_rules.lua` (reviewed data): each kind's tables and profile files (both `*Func.txt` and `*Strings.txt`), the borrowed metadata types, and the id columns no metadata row names.
3. `src/gamedata/stock_rows.lua` `load`: metadata, tables and profile entries through a map's chain (opened with the map, so its own tables count); the column → metadata type index, trying a profile field's bare name before the name-plus-level form; ids only the map's own tables define.
4. `stock_rows.merge`: stock row + changes = full row, every column labelled; rows for objects only the map's tables define; per-map problems (orphan, unknown parent, unknown code) and counts, including borrowed columns.
5. `src/parsers/objectdata.lua`: trailing zero bytes trimmed from ids (three-letter field codes such as `Crs`).
6. `src/tests/test_stock_rows.lua`: one custom ability field by field with labels; a map-defined ability (DAoW-5.2 `A008`); a three-letter code (Curse in DaoW-(HvA)-7.5); every object of every map in `assets/` with no problems.

The game version is whatever layer the chain picks (issue 112b); until more patch layers exist, every map reads 1.21b.

## Acceptance Criteria

- [x] SLK and profile files parse, with tests
- [x] Every custom ability in DAoW-2.1.w3x merges into a full row, or appears in the report with a reason
- [x] Every column copied and labelled by a reviewed type list (owner decided 2026-09-24: copy everything)
- [x] `.info.md` beside each new file

## Open Questions

1. ~~Review the dropped types~~ Answered 2026-09-24: nothing is dropped; everything is copied and labelled (see Intended Behavior).
2. ~~`Crs\0`~~ Answered 2026-09-24: not a later patch's field. It is Curse's chance to miss (`Crs` in the 1.21b metadata; `ACcs` is creep Curse, not Carrion Swarm as first written here), stored padded to four bytes. Fixed in the object-file reader.
3. ~~Orphan change sets~~ Answered 2026-09-24: they weren't orphans. The owner asked "Do the triggers create new abilities that use those IDs maybe?"; the ids were in the maps' units and scripts, defined in the maps' own tables. The chain now reads the map first; orphans are still reported if any ever appear.

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md` (Route A)
- `issues/112b-game-version-layers-per-map.md` (the chain)
- `docs/formats/object-data.md`
