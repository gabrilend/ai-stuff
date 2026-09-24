# Issue 112: Stock Object Tables, Read Two Ways and Cross-Checked

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** High (every converted custom map needs the stock values under its modified objects)
**Dependencies:** None open
**Builds on (completed):** MPQ reader (102), object data parsers (110)

---

## Current Behavior

The object database (`src/parsers/objectdb.lua`) reads a map's own object
changes (w3u, w3a, w3t, w3b, w3d, w3h, w3q). Each changed object stores only
its **modified** fields plus the id of the stock object it copies
(`original_id`). The unchanged fields live in Warcraft III's stock tables
(`Units\UnitData.slk`, `Units\AbilityData.slk` and others, inside the game's
archives), which the project cannot read: there is no SLK parser, and
`src/validation/init.lua` notes "we don't have SLK data".

The owner's installs are linked from `wc3-installs/`: `reign-of-chaos`
(`war3.mpq`) and `frozen-throne` (a separate prefix, with The Frozen Throne
and patch 1.21b being installed 2026-09-24).

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
4. **Functional fields only.** Keep numbers, flags and ids (hit points, damage,
   cooldowns, ranges, costs, target flags, ability ids). Drop art paths, sound
   names, text and tooltips. The keep-list is a reviewed data file.
5. **Merge.** For each custom object: stock row of `original_id` + the map's
   modified fields = the full row (issue W02h consumes this).

### Route B: from published sources

1. Fetch the values community wikis publish for stock objects. First source:
   **Liquipedia** (Warcraft III) through its MediaWiki API, following its API
   terms (checked 2026-09-24): at most one request every 2 seconds (one every
   30 seconds for `action=parse`), a User-Agent naming this project and a
   contact, gzip, and results cached so each page is fetched once. Content is
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

- [ ] Stock rows read for both data sets (Reign of Chaos, Frozen Throne)
- [ ] A custom map's modified abilities merge into full rows
- [ ] Route B fetches within Liquipedia's terms and is cached
- [ ] Comparison report with coverage and every mismatch investigated
- [ ] The converter refuses to use an unchecked stock table
- [ ] `.info.md` beside each new source file

## Open Questions

1. Which other published sources besides Liquipedia (for fields it doesn't cover, e.g. doodads and destructibles)?
2. Should a Route B snapshot be shipped (as a separate CC BY-SA 3.0 file, credited) so every user doesn't have to fetch it, or must each user fetch it themselves as part of "doing both"?

## Related Documents

- `docs/formats/object-data.md`
- `docs/licensing-and-boundaries.md`
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (W02h, open question 7)
- `wc3-installs/README.md`
