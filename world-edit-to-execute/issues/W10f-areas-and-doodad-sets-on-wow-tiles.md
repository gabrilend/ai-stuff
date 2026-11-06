# Issue W10f: Areas and Doodad Sets on WoW Tiles

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (the chunk half of step 4, "regions as areas", and a building's doodad set from step 3), without the window
**Priority:** Medium (a WoW map's zones could not be set; a tile added by W10d was in area 0 whatever its neighbours were in)
**Dependencies:** W10e (the placer), W10d (new tiles), W10b (the tile writer, undo), the W client's `adt_read`, `adt_place_read` and table reader (016-dbc.c)
**Blocks:** the AreaTable rows of a map's own zones (W02c's writer, once the editor stack has it); the window's area brush

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- Every chunk of a WoW tile has an area number in its MCNK header (byte 52): AreaTable's id. The stock client names the zone and subzone a player stands in by the chunk under them, and the server's map extractor takes each chunk's area from the same header.
- The editor neither read nor wrote it. The W client's reader (`AdtChunk`) doesn't keep it.
- A tile added by W10d was written with area 0 (W10d decision 4), even beside tiles in an area.
- A building's doodad set (MODF byte 58: which of its WMO's sets of furniture and small models the client draws inside) was kept as written; nothing set it.

*Now:* see Implementation Notes.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #261 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- The area brush picks a chunk only if the chunk's middle is within the radius; at the default brush (about 8 yards against 33-yard chunks) most strokes change nothing and still record a "Set area" undo step. Always include the chunk under the stroke point.
- Listing areas across the map fails entirely when one tile the WDT lists has no file.
- Listing areas reads every tile in full through the C reader and caches it (hundreds of MB on a continent) only to get 256 numbers per tile.
- Setting a doodad set to its current value still marks tiles dirty and records an undo step.
- The area-names reader doesn't check that its C declarations loaded, so it raises instead of returning a reason.
- A chunk whose header isn't found silently gets area 0, which a later write makes permanent.
- The neighbour-area helper has no fold; the chunk-area reader copies the terrain module's block walker with different rules; the same range check is pasted three times; the tool chain grows another elseif.

## Intended Behavior

- **Each chunk's area is read** with its tile, and every area of the map can be listed with its chunks and tiles.
- **Areas are set over whole chunks**, at a point or with a brush's radius, as plain Lua and as the editor's `area` stroke with undo and redo. Saving writes only those four header bytes of each changed chunk.
- **A new tile takes its neighbours' area**, unless it is given one.
- **A building's doodad set is set**, as plain Lua and as an editor step. Saving changes only that record's two bytes.
- **Area names can be read** from a loose `DBFilesClient/AreaTable.dbc` beside the map (a W02 build's, or one put in a map project's `wow/`).

## Suggested Implementation Steps

1. `editor/wowmap.lua`: `chunk_areas(bytes)` reads each chunk's header; `M:tile` puts `area` on each chunk; `area_names(root)` reads the table.
2. `editor/wowterrain.lua`: `area`, `area_at` and `areas`; the writer patches byte 52 for a chunk marked `area`; snapshots carry the area; the `area` stroke takes `brush.wow_area`.
3. `editor/wowtiles.lua`: a new tile's area from `opts.area` or its neighbours (`area_of`).
4. `editor/wowplace.lua`: `doodad_set(m, o, n)` and `E:wow_doodad_set(o, n)`.
5. Tests, from the project root: `test_wow_areas.lua` (new).

## Acceptance Criteria

- [x] Every chunk's area is read from its header; W02's tiles read 0 everywhere.
- [x] One chunk set and saved: the file is the one read but for that chunk's header bytes 52-55; the other tile, the WDT and the WDL are untouched; `adt_read` still reads it, and the area reads back.
- [x] A radius over a tile edge sets the chunks whose middles are within it on both tiles, and both are written.
- [x] Numbers outside 0-65535, fractions and places off the map are refused.
- [x] An area and a ground edit in one chunk are written in one save.
- [x] A new tile takes the area most of its neighbours' facing chunks are in (opts.area first; 0 with none); the saved file's headers say so.
- [x] A building's doodad set is written in its MODF record's bytes 58-59 and nowhere else; `adt_place_read` reads it; the chunks' references are unchanged. A model, a number out of range and an unknown building are refused.
- [x] In the editor, area strokes and doodad sets undo and redo before and after saves; everything undone and saved gives every file back byte for byte.
- [x] Area names are read from a loose AreaTable.dbc; a table too narrow, cut short or naming past its text is refused.
- [ ] The stock client names the zone from a chunk set here, and AzerothCore's map extractor reads the areas, on the owner's machine (decision 9).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Where does the area come from, given the W client's reader doesn't keep it?
2. What does the area tool set: points, cells or chunks?
3. Which numbers are allowed?
4. What area does a new tile have?
5. Where do areas' names come from?
6. Are AreaTable rows written here?
7. What doodad set numbers are allowed, and what else changes with one?
8. How do undo and redo work across a save?
9. What is checked, and what is left for the owner's machine?

## Decisions (2026-11-05; each the owner's to overturn)

1. **The header's byte 52, read beside the reader.**
   - The W client's `AdtChunk` has no area field, so `wowmap.chunk_areas` walks the tile's blocks and reads each MCNK header's byte 52 (u32), placed by the header's own ix and iy.
   - `M:tile` puts it on each chunk as `area`, 0 where a chunk is missing.
   - The offset is the one W02a writes it at (3.3.5a's MCNK: the area id after the shadow map's size at 48, before the building references' count at 56). The W client doesn't read it, so it is unchecked against a reader; see decision 9.
2. **Whole chunks: those whose middles are within the radius, or the chunk at the point.**
   - A chunk is in one area, so the tool never splits one.
   - With a radius (`wt.area(m, x, y, { radius, area })`, and the brush's `wow_radius` or `size` cells), it takes every chunk whose middle is within it, on every tile it reaches.
   - With no radius, or 0, it takes the chunk the point is in. That is the precise way to set one chunk.
   - A chunk already in that area isn't marked, so it isn't written.
3. **0 to 65535.**
   - The header keeps 32 bits, but the server's extracted map files keep a chunk's area in 16, and 3.3.5a's ids fit.
   - 0 is "no area", as W02a writes it. Fractions and negatives are refused.
   - Whether a number is in the client's AreaTable isn't checked: the stock table is a game file (decision 5).
4. **A new tile takes its neighbours' area (this supersedes W10d decision 4's "Area is 0").**
   - `opts.area` when given.
   - Else the area most of its side neighbours' facing chunks are in (the west neighbour's ix 15 column, the north neighbour's iy 15 row, and so on, all counted together). With no side neighbour, the corner neighbours' corner chunks. The lower number on a tie, and 0 with no neighbour.
   - A tile among tiles in one zone is in that zone, as its ground meets theirs (W10d decision 3).
   - A new tile in area 0 has nothing to patch, since W02a's writer writes 0.
5. **Names from a loose AreaTable.dbc, through the W client's table reader.**
   - `wowmap.area_names(root)` reads `root/DBFilesClient/AreaTable.dbc` through 016-dbc.c (`dbc_open`, `dbc_u32`, `dbc_text`): `{ [id] = { name, map, parent } }`.
   - Columns are 3.3.5a's as W02c lays them out (1 id, 2 map, 3 parent, 12 the name's first language). That layout is unchecked there too.
   - The stock table isn't read: it is in the game's archives (no game files here). A W02 build writes its own table in its loose folder, and a project can keep one in `wow/`.
   - The reader trusts a table's header, so the sizes are checked here first: a table cut short, narrower than 12 fields, or with a name past its text is refused.
6. **AreaTable rows aren't written here yet.**
   - W02c's table writer and registration (`wowbuild/dbc.lua`, `registration.lua`) are on the W02 chain, which this stack (W10a-W10e) branched before.
   - Merging the chain in would carry its whole diff into this PR, so a new zone's row (a name, its map, its parent) waits until the two stacks meet. Until then an area number is set here and named by W02's build or by hand.
7. **Any 16-bit doodad set; nothing else of the record changes.**
   - `pl.doodad_set(m, o, n)` sets every entry of the building to `n` (0-65535; MODF's u16 at 58). A model is refused: MDDF has no set.
   - How many sets a WMO has is in the WMO (MODS), which isn't read here (no game files), so a number past its last set isn't refused. What the stock client draws then is unchecked (decision 9).
   - The record is patched where it is (W10e decision 2's "fields an edit changed"); its place, box and the chunks' references stay as they are, since a set doesn't move it.
8. **Undo by the chunk snapshot and the placements snapshot, as the other tools.**
   - An area stroke is one step: W10b's chunk snapshots now carry `area`, and a chunk restored after a save is written again whole (its area with it).
   - `E:wow_doodad_set` is one step of the placer (W10e decision 11).
   - Everything undone after a save, then saved, gives every file back byte for byte; one step undone after a later save brings back just that step (tested).
   - A stroke the brush refuses (no `brush.wow_area`) is said, and still recorded as a step that changes nothing, as every WoW brush's is.
9. **Checked by code, and left for the owner's machine.**
   - **Confirmed here:** a tile with areas and sets written is read by `adt_read`; the set by `adt_place_read`; the areas from the header, which the writer patches at the offset the reader reads.
   - **Unchecked:** byte 52's meaning in the stock client and the server's extractor; the AreaTable columns; what the stock client draws for a doodad set past a WMO's last.
   - **To check on the owner's machine:** a chunk's area set to a stock zone's id names that zone in the stock client; AzerothCore's map extractor reads the areas of a converted map; a building's set changes its inside.

## Implementation Notes

*(2026-11-05)*

- **`src/editor/wowmap.lua`:** `chunk_areas(bytes)`; `M:tile` sets each chunk's `area`; `AREA_TABLE` and `area_names(root, lib)`.
- **`src/editor/wowterrain.lua`:**
  - `AREA_MAX`, `chunk_middle`, `area_at`, `area` and `areas`;
  - the writer patches byte 52 for a chunk marked `area`;
  - `snapshot` and `restore` carry it, and a chunk restored after a save is marked for it;
  - the `area` tool (`brush.wow_area`, history name "Set area").
- **`src/editor/wowtiles.lua`:** `area_of(near)` (also `tiles.area_of`); `tiles.add` takes `opts.area`, checks it, and marks the area for writing when it isn't 0.
- **`src/editor/wowplace.lua`:** `doodad_set` and `E:wow_doodad_set`.
- **Tests:** `src/tests/test_wow_areas.lua` (new): 84 with the library, 1 skipped without. It covers:
  - reading (the header by hand, every area of the map);
  - one chunk set, saved, byte for byte but its four bytes, read back;
  - a radius over the tile edge;
  - refusals;
  - an area and raised ground in one save;
  - a new tile's area (`area_of` on made neighbours; added, saved, read back; `opts.area`; none);
  - a building's doodad set (the record's two bytes, `adt_place_read`, the references, refusals, set back to W02's);
  - the editor's area strokes and doodad set with undo and redo around saves;
  - area names from made tables, and refusals of bad ones.

  The other tests are unchanged; see the PR for counts.

**Still open:**
- decision 9's checks on the owner's machine;
- AreaTable rows for a map's own zones (decision 6), and a new-area tool that adds one;
- the window's area brush and a map of the areas.

*2026-11-05, on joining the W02 chain into this stack:* W02c's converter
writes the map's own zone (its area id, 9000 + 10 x slot) in every chunk,
not 0. So on the joined branch a converted map reads as one area, the
zone, and a tile added beside it takes the zone by decision 4; the
acceptance line "W02's tiles read 0 everywhere" holds for W02a alone.
`test_wow_areas.lua` takes the zone from the map's registration.
