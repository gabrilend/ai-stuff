# Issue 112: Stock Object Tables, Read Two Ways and Cross-Checked

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** High (every converted custom map needs the stock values under its modified objects)
**Dependencies:** None open
**Builds on (completed):** MPQ reader (102), object data parsers (110)

---

## Current Behavior

Both routes are built and agree; one criterion is left.

- **Route A (112c, completed):** the stock tables are read from the
  player's own install. `src/parsers/slk.lua` and `profile_txt.lua` read the
  table files; `src/gamedata/stock_rows.lua` merges each of a map's changed
  objects over its stock row, every column labelled by a reviewed type list
  (`field_rules.lua`).
- **Game-version layers (112b):** `src/gamedata/chain.lua` assembles, per
  map, the map's own archive over one patch layer over the disc's archives,
  choosing the layer from the map's editor build (`editor_versions.lua`) and
  its data set. Layers are built for Frozen Throne 1.11 through 1.29.2 and a
  separate Reign of Chaos stack. 112b stays open on the owner's go-ahead to
  download the remaining patch programs (`issues/CRITICAL-PATH.md`, Q-5).
- **Route B (112e):** published values from Liquipedia compared with Route
  A's 1.29.2 melee tables: 0 unexplained mismatches; 94 values on pages with
  no pre-1.30 revision are listed as not yet checkable. 112e stays open on
  its open questions.
- **Not built:** the converter's refusal of an unchecked stock table. No
  code yet marks a table as checked or unchecked, and nothing converts maps
  that would consult such a mark.
- **A fallback still in use (found 2026-09-26):** the cross-reference
  validator (`src/validation/init.lua`, unit placements, about line 268)
  meets a unit id that isn't in the map's own object data and isn't a custom
  id, warns, and then counts it as valid, with the comment "we don't have
  SLK data". The stock rows now exist, so the id can be looked up in the
  map's chain instead: found means valid, not found means an error that
  names the id and the layer searched. The same assumption should be checked
  for doodads and destructables in the same file.

Live figures for both routes come from `luajit src/cli/route-b-report.lua`
rather than from this file. The owner's installs are linked from
`wc3-installs/`.

(Until 2026-09-26 this section still described the starting point: no SLK
parser, and `src/validation/init.lua` noting "we don't have SLK data".)

## Intended Behavior

The owner (2026-09-24): "compare with the remote sources to validate, that way
we can confirm that if we had gone with the 3rd party wiki style approach, we
would arrive at the same conclusion... we should do both just to validate, and
we should require that users do both in order to protect them slightly."

Stock values are obtained **two ways**, and a table is only used once both
agree:

### Route A: from the player's own install

1. **Archive chain per data set.** Reign of Chaos maps (`.w3m`): `war3.mpq`,
   then `War3Patch.mpq`. Frozen Throne maps (`.w3x`): `war3.mpq`, `war3x.mpq`,
   `War3xlocal.mpq`, then `War3Patch.mpq`. Later archives win.
2. **SLK parser.** SLK ("SYLK") is a text spreadsheet format: records such as
   `C;X3;Y12;K"Footman"` set the cell at column 3, row 12; a record that omits
   X or Y reuses the last one. Output: rows keyed by the first column (the
   object id, a 4-character string), fields keyed by the header row's names.
3. **Metadata tables.** `Units\UnitMetaData.slk`, `Units\AbilityMetaData.slk`
   and friends map each 4-character field id used in map files (e.g. `umvs`,
   movement speed) to its SLK column. This is what lets a map's changes be laid
   over the stock row.
4. **Every field copied, each labelled by whose it is** (owner's decision,
   2026-09-24: "copy everything, and we will work slowly to replace all the
   artwork and such"). Numbers, flags and ids are `fact`; names, tooltips and
   art paths are `borrowed` (Blizzard's, on the player's machine only, each on
   a replacement track); fields the map sets are `map`. The borrowed types
   are a reviewed data file.
5. **Merge.** For each custom object: stock row of `original_id` + the map's
   modified fields = the full row (issue W02h consumes this).

### Route B: from published sources

1. Fetch the values community wikis publish for stock objects. First source:
   **Liquipedia** (Warcraft III) through its MediaWiki API, following its API
   terms (checked 2026-09-24): at most one request every 2 seconds (one every
   30 seconds for `action=parse`), a User-Agent naming this project (only
   the tool, no contact: the owner, 2026-09-25, keeps personal details out of
   requests), gzip, and results cached so each page is fetched once. Content is
   CC BY-SA 3.0 and requires attribution.
2. Parse each page's infobox/stat tables into the same shape as Route A
   (object id → field → value).
3. The Route B data is kept **in its own file, credited to its source, under
   its own licence** (CC BY-SA 3.0), next to, never inside, the project's RGPL
   tables. It is used only to check, never to fill a table.

### The comparison

For every object and field both routes cover: `match`, `mismatch` (both
values shown), `only in A`, `only in B`. Numbers compare with a tolerance of
the source's own rounding (wikis often round). The report gives coverage
(the share of Route A's fields that Route B confirms) and lists every mismatch.
A mismatch is not "fixed"; it is investigated (a patch-version difference, a
wiki error, or a parser bug) and the finding recorded.

### Required of every user

The stock table from Route A is only used by the converter when a comparison
report exists for that exact install (identified by the archives' hashes) and
has no uninvestigated mismatches. A user's first conversion therefore runs
both routes once, on their machine. The Route B cache is theirs too; it is
fetched politely and reused.

### What doing both routes shows, and what it doesn't

- **It shows** that the functional values maps depend on can be found in two
  independent places and agree, so the numbers are facts about the game, not
  something only extractable from Blizzard's files.
- **It doesn't make the routes interchangeable for the project's licence.**
  A table *built from* the wiki would have to carry CC BY-SA 3.0 and couldn't
  be part of the RGPL project; that is why Route B only checks.
- **It doesn't make the wiki independent of Blizzard.** Wiki editors measured
  the same game. The wiki is independent of *us*, which is what a cross-check
  needs.
- The transcripts record which route generated the table (A) and which
  confirmed it (B). The record should say that plainly.

## Sub-Issues

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| 112a | stormlib-build-and-update-script | None | StormLib (MIT) built from a pinned tag by a script, with a LuaJIT binding, to read patch archives our own reader can't |
| 112b | game-version-layers-per-map | 112a | Each patch is a complete layer of the files it produces; loading a map picks its layer and data set, and nothing on disk is patched |
| 112c | route-a-stock-rows-merged-with-map-objects | 112b | SLK, profile and metadata parsing; each custom object's full row (stock row plus the map's changes), every field labelled fact, borrowed, editor or map |
| 112d | older-patch-program-shapes | 112b | Layers for 1.01–1.20e: three older patch-program shapes (an older diff encoding, several nested archives, unnamed inner files) and the Reign of Chaos stack |
| 112e | route-b-published-values-cross-check | 112c, 112b | Liquipedia's infobox values, as each page stood when 1.29.2 was current, compared field by field with Route A |

Finding from 112b (2026-09-24): custom maps start from the data-set copies of
the stock tables (`Custom_V0\` for Reign of Chaos maps, `Custom_V1\` for Frozen
Throne maps), not the melee tables in `Units\`. Route A reads through each
map's chain (`src/gamedata/chain.lua`), not the plain paths.

## Suggested Implementation Steps

1. SLK parser (`src/parsers/slk.lua`) with tests on small hand-made SLK text.
2. Stock chain reader for both data sets; list which SLKs exist in each archive.
3. Metadata join and the functional-field keep-list.
4. Merge with the object database (`original_id` + modified fields).
5. Route B fetcher with the rate limit, User-Agent, cache and parser for the first page type (units).
6. Comparison and report (JSON, plus an HTML page for reading).
7. The "both routes required" gate in the converter.
8. Tests: known stock values (e.g. the Footman's hit points and movement speed) match in both routes; a custom map's modified object merges to the expected row.

## Acceptance Criteria

- [x] Stock rows read for both data sets (Reign of Chaos, Frozen Throne) (112b, 112c)
- [x] A custom map's modified abilities merge into full rows (112c)
- [x] Route B fetches within Liquipedia's terms and is cached (112e)
- [x] Comparison report with coverage and every mismatch investigated (112e)
- [ ] The converter refuses to use an unchecked stock table
- [ ] The cross-reference validator looks stock ids up in the map's chain instead of assuming them valid
- [x] `.info.md` beside each new source file (the last one, `editor_versions.info.md`, written 2026-09-26)

## Open Questions

1. Which other published sources besides Liquipedia (for fields it doesn't cover, e.g. doodads and destructibles)?
2. Should a Route B snapshot be shipped (as a separate CC BY-SA 3.0 file, credited) so every user doesn't have to fetch it, or must each user fetch it themselves as part of "doing both"?

## Related Documents

- `docs/formats/object-data.md`
- `docs/licensing-and-boundaries.md`
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (W02h, open question 7)
- `wc3-installs/README.md`
