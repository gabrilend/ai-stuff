# Issue W10g: Areas of a Map's Own, as AreaTable Rows

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (step 4's "regions as areas": the table half; W10f did the chunks), without the window
**Priority:** Medium (a converted map was one zone; the area brush could paint only numbers no table named)
**Dependencies:** W10f (the area brush), the join of the W02 chain into the editor stack (W02c's `registration.lua`, `dbc.lua` and `output.lua` on this branch), the W client's table reader (016-dbc.c)
**Blocks:** the window's area list; zone music, ambience and light per area

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- W02c registers a converted map as one zone: one AreaTable row (id 9000 + 10 x slot), written in every chunk and kept in `World/Maps/<dir>/registration.lua` with its other table rows. Its slot's other nine area ids were reserved ("one zone now") and unused.
- W10f's area brush paints any number onto chunks, but nothing makes a row for a new number, so the client and the server know no name for it.

*Now:* see Implementation Notes.

## Intended Behavior

- **A map's own areas can be made**, renamed, flagged and taken away, as plain Lua and as editor steps with undo and redo. Each is an AreaTable row with W02c's ids and its own explored-zones bit.
- **A new area is what the area brush paints next.**
- **A save writes the map's registration again**, then every form of the folder's tables as the converter does: the overlay's `DBFilesClient/*.dbc`, the server's SQL, the merged stock tables when they are given, and `patch-W.MPQ`.
- **The rows read back** through the W client's table reader and `wowmap.area_names`.

## Suggested Implementation Steps

1. `wowbuild/registration.lua`:
   - the area bit block for a slot's other areas (`SUBAREAS`, `SUBAREA_BIT_TOP`, `subarea_bit`);
   - `area_row`, which the zone's row now uses too.
2. `editor/wowareas.lua` (new):
   - `load`, `list`, `create`, `change`, `delete`;
   - `snapshot` and `restore` for undo;
   - `save`;
   - `attach` for the editor's steps.
3. `editor/wowterrain.lua`: `save` calls `wowareas.save` when the rows changed.
4. `editor/init.lua`: attach the area steps.
5. `wowbuild/init.lua`: a map converted into the folder keeps clear of the bits of every other map's rows, not only their zones'.
6. Tests, from the project root: `test_wow_area_rows.lua` (new).

## Acceptance Criteria

- [x] A converted map's registration is read: its zone, its slot, its ids. A map without one is refused, saying so, and its chunks still take any number.
- [x] **Made:** areas get the zone's next ids and the slot's own bits, with the zone as parent (or none), flags, and a name cleaned to one line. Bad names, parents and flags are refused, as is a tenth area.
- [x] **Painted and saved:** the save writes the tile and `registration.lua` (the other rows and fields as the converter wrote them). It also writes:
  - the overlay's AreaTable.dbc, read through the W client's reader (36 fields; the ids, map, parent, bit, flags and name);
  - `wowmap.area_names`;
  - the other tables;
  - the server's SQL;
  - `patch-W.MPQ`, or a warning saying why not.
- [x] **Removal:** an area in use isn't taken away. Once painted back, it is, and its id and bit are free again. With everything taken away and saved, `registration.lua` is the converter's byte for byte.
- [x] **Stock tables:** with stock tables given, their bits are avoided and the server's table holds their rows and the map's.
- [x] **In the editor:**
  - a new area becomes the brush's;
  - renamed, painted, undone and redone around saves;
  - everything undone gives `registration.lua` and the tile back byte for byte.
- [x] Another map converted into the folder keeps this map's areas in the tables, and every bit is its own.
- [ ] The stock client names a subzone made here, and marks it explored; AzerothCore reads the rows from its SQL. Both on the owner's machine (decision 13).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Which maps can have areas of their own?
2. Which ids do they take?
3. Which explored-zones bits (AreaBit)?
4. What can an area's parent be?
5. Which flags, and by what names?
6. What are the other columns?
7. What names are allowed? What does renaming the zone do?
8. When can an area be taken away?
9. How is a new area painted?
10. What does a save write, and when?
11. How does undo work?
12. What happens when the map is converted again?
13. What is checked, and what is left for the owner's machine? Does the W client's AreaTable layout (custom-client's 097) agree with W02c's?

## Decisions (2026-11-05; each the owner's to overturn)

1. **Maps W02c registered.**
   - An area of a map's own is a row of the map's registration (`World/Maps/<dir>/registration.lua`). A map without one, such as a stock map or one not converted by W02c, is refused, saying so.
   - Its chunks still take any area number through W10f's brush.
2. **The zone's block: its next nine ids, the lowest free.**
   - W02c gives each slot ten area ids, 9000 + 10 x slot to + 9: the zone's and nine reserved.
   - A new area takes the lowest one this map doesn't use. An id freed by a deletion is taken again, since a deleted area has no chunks (decision 8).
   - Nine areas besides the zone is the limit. A larger block would move every slot's ids, so it waits for a map that needs it.
3. **A block of bits under the zones', each area its own.**
   - The zones take bits 4095 - slot (W02c). A slot's other areas take 3995 - 9 x slot - (k - 1) for its area k, so slots 0-99 cover 3096-3995 (`registration.subarea_bit`).
   - A bit is skipped if any of these use it:
     - the stock table (when given; as the converter checks its zone's);
     - any row of any map in the folder;
     - this map's own rows.

     A skipped bit is replaced by the highest free one at or below 3995.
   - The converter now keeps a new zone clear of every other map's rows' bits, not only their zones'.
   - The client keeps 4096 explored bits (W02c), so each area gets one of its own. Whether the stock rows' bits stay under 3096 is unchecked without the stock table.
4. **The zone, or none.**
   - The parent is the map's zone (the default), making a subzone, or 0, making a zone of its own on the same map.
   - Deeper nesting is refused: 3.3.5a's client names a zone and a subzone, as remembered (unchecked).
5. **0 by default; a number or names from memory.**
   - A new area's flags are 0, like W02c's zone row.
   - Flags are a whole number (u32) or names of `ar.FLAGS`: capital 0x100, sanctuary 0x800, town 0x200000, rest_horde 0x400000, rest_alliance 0x800000, no_fly 0x20000000.
   - The names are 3.3.5a's AreaFlags as remembered from TrinityCore's `DBCEnums.h`, unchecked against this project's or the W client's code. Neither reads them.
6. **The zone's other columns.**
   - A new row is built by `registration.area_row`, which W02c's zone row now uses too: the map's ContinentID, ExplorationLevel 0, MinElevation -500, AmbientMultiplier 0, and no sounds, music or faction mask.
   - LightID is 0, so the map's own light (W02i) shows in every area.
7. **One line of up to 120 characters; renaming the zone renames its row only.**
   - A name is cleaned as W02c cleans the map's name: colour codes and line breaks out, at most 120 characters. An empty name is refused.
   - Renaming the zone changes its AreaTable row. The map keeps its own name in Map.dbc.
8. **Only when nothing uses it.**
   - The zone can't be taken away, since Map.dbc names it.
   - An area with chunks in it can't either. Every tile is read to check, and the refusal says how many chunks and which tiles.
   - An area that another area names as its parent can't be taken away either. With decision 4's parents, only the zone can be one.
9. **The brush paints the area just made.**
   - `E:wow_new_area` sets `brush.wow_area` to the new id and says so.
   - The brush is not changed back on undo; it is a tool setting, not map data.
10. **The registration, then every form of the folder's tables, when the rows changed.**
    - `wt.save` writes the edited tiles first. Then, if the rows changed, `wowareas.save` writes `registration.lua` again with the converter's serializer. Its `written` time is the conversion's, so an undone edit leaves the file as it was.
    - Then it runs `wowbuild.output.write` over the map's root (a project's `wow/` or a build folder). That writes:
      - the overlay's tables;
      - `server/dbc.sql`;
      - `server/dbc/*.dbc`, merged with the stock tables when they are given (`opts.stock_dbc` of `wowmap.open`, else the owner's AzerothCore folder when it is there, as for the converter);
      - `patch-W.MPQ`, rebuilt with every map's ground. Without StormLib, an older one is removed and a warning says so, as the converter does.
    - A save that changes only ground doesn't rebuild these forms, so an existing `patch-W.MPQ` holds the ground of its last rebuild. A save of area rows or a conversion brings it up to date (still open).
11. **The map's AreaTable rows snapshotted per step.**
    - `E:wow_new_area`, `E:wow_change_area` and `E:wow_delete_area` are one step each. Undo puts back the rows as they were, and the next save writes them.
    - Everything undone and saved gives `registration.lua` back byte for byte (tested).
12. **Converting the map again makes it one zone again.**
    - The converter owns the build folder and writes the registration and tiles afresh (W02c). The areas made here, and the chunks painted into them, are then gone.
    - A project's `wow/` copy is the editor's, and a conversion doesn't touch it.
13. **Checked by code, and left for the owner's machine.**
    - **Confirmed here:** the overlay's AreaTable.dbc is read through the W client's `dbc_open`, `dbc_u32` and `dbc_text`, field by field: id, map, parent, bit, flags and name. `wowmap.area_names` reads it too, and the merged server table holds the stock rows and the map's.
    - **The W client's layout:** custom-client's 097-table-layouts.c (its draft PR #24, the table layouts) lists AreaTable as 36 fields, in the same order and of the same kinds as W02c's `dbc.lua`. It agrees, but it was written from `dbc.lua`, so the agreement isn't independent. Its draft PR #29 reads the converter's written tables against those layouts and finds all eleven agree.
    - **Unchecked:**
      - the column layout against a stock AreaTable.dbc (W02c);
      - the flags' meaning (decision 5);
      - whether the stock rows' bits stay under 3096.
    - **To check on the owner's machine:**
      - the stock client naming a subzone made here and marking it explored;
      - AzerothCore reading the rows from `server/dbc.sql` and naming the area the player stands in.

## Implementation Notes

*(2026-11-05)*

- **`src/wowbuild/registration.lua`:** `SUBAREAS`, `SUBAREA_BIT_TOP`, `subarea_bit(slot, k)` and `area_row(ids, o)`. The zone's row now comes from `area_row`, with the same fields as before.
- **`src/wowbuild/init.lua`:** the zone's bit keeps clear of every other map's rows' bits.
- **`src/editor/wowareas.lua`** (new):
  - **Reading:** `load` and `list`;
  - **Edits:** `create`, `change` and `delete`;
  - **Flags:** `FLAGS`;
  - **Undo:** `snapshot` and `restore`;
  - **The save:** `save`;
  - **Editor:** `attach` (`E:wow_new_area`, `E:wow_change_area`, `E:wow_delete_area`).
- **`src/editor/wowterrain.lua`:** `save` writes the registration and the folder's tables when the rows changed, and lists `registration.lua` among the files written.
- **`src/editor/init.lua`:** attaches the area steps.
- **Tests:** `src/tests/test_wow_area_rows.lua` (new): 54 with the library, 1 skipped without. The other tests are unchanged; see the PR for counts.

**Still open:**
- decision 13's checks on the owner's machine;
- `patch-W.MPQ` rebuilt on ground-only saves (decision 10);
- more than nine areas a map (decision 2);
- an area's own music, ambience and light (its columns are 0 now);
- the window's area list and brush.

*(2026-11-05, later)* **Decisions 2, 3 and 10 are superseded** by
`W10h-patch-w-never-behind-and-more-areas.md`:
- **Decision 2 (nine areas a map):** by W10h decision 5. A map's first
  nine areas keep the zone's block and the slot's own bits; the next 90
  take ids 10000 + 90 x slot onwards (`area_more`), so a map holds up to
  99 besides its zone (`ar.MAX` 100).
- **Decision 3 (a taken bit falls back to the highest free, down to 0):**
  by W10h decision 6. A pooled bit is now the lowest free of the areas'
  block, 3096-3995, and never leaves it.
- **Decision 10 (the patch made again only when the rows change):** by
  W10h decisions 1-3. Any save that writes a file of a registered map
  makes the folder's forms again, then the plan and stamp; `ar.save` now
  writes only `registration.lua`, and `ar.forms` makes the forms.
- Also found: a map project's WoW build left these tables out (W10h
  decision 4); it carries them now.
