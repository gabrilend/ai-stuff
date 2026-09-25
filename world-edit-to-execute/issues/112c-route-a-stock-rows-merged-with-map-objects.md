# Issue 112c: Route A, Stock Rows Merged With a Map's Objects

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High
**Dependencies:** 112b (per-map game data chains)

---

## Current Behavior

A map's object files (w3u, w3t, w3a, w3b, w3d, w3h, w3q) parse into lists of
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
row from the map's chain with the map's changes laid over it, keeping only
functional fields. That's what W02h writes into the converted map's tables.

- **Field codes to columns.** From the metadata row: a level-dependent field
  (`repeat` > 0) maps to `field .. level` (`Cool1`); an ability data field maps
  to `"Data" .. letter(data) .. level` (`DataA1`); an indexed list field uses
  its `index`.
- **Functional only.** Dropped by metadata `type`: text, tooltips, names, art
  (`model`, `icon`, `texture`, sound labels) and editor-only fields. The list
  of dropped types is a reviewed data file, not code.
- **Errors, not guesses.** A field code with no metadata row, or a stock id not
  in the chain, is reported per map, never skipped silently.

## Suggested Implementation Steps

1. `src/parsers/slk.lua` and `src/parsers/profile_txt.lua`, with tests on small hand-made files.
2. `src/gamedata/stock_tables.lua`: which tables each object kind reads, loaded through a chain.
3. Metadata join and the functional-type filter (data file).
4. Merge: stock row + changes = full row; per-map report of unknown codes and ids.
5. Tests: a known stock value read through the chain; one DAoW custom ability's full row (its cooldown and data fields as changed, everything else from its stock parent).

## Acceptance Criteria

- [ ] SLK and profile files parse, with tests
- [ ] Every custom ability in DAoW-2.1.w3x merges into a full row, or appears in the report with a reason
- [ ] Only functional fields kept, by a reviewed type list
- [ ] `.info.md` beside each new file

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md` (Route A)
- `issues/112b-game-version-layers-per-map.md` (the chain)
- `docs/formats/object-data.md`
