# Issue W10d: Tiles From the WDT, Added and Taken Off

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (step 2's ground on new tiles; step 8's WDT)
**Priority:** High (a WoW map could only be edited where it already had ground)
**Dependencies:** W10c (the WDL and water writers), W10b (the terrain tools and the tile writer), W10a (the WoW layer), W02a (the ADT and WDT writers), the W client's WDT reader (its 098-wdt.c, custom-client draft PR #25)
**Blocks:** W10's acceptance line 2 for new ground; the brush cursor, the yards conversion and W10 step 3 (the object placer) come after it

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- A WoW map's tiles are taken from the ADT files in its folder (W10a decision 2). The WDT's own list is never read, because the W client had no reader for it.
- A tile can't be added or taken off (W10b decision 12, W10c decision 12).
- An edited water layer of vertex format 1 or 3 is written as format 0. That drops the picture positions that make magma and slime flow (W10c decision 5).

*Now:* see Implementation Notes.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #258 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- Any tile the WDT lists but whose file is missing stops every add, take-off and nearby brush stroke, because the neighbour reader gives up on the first error (the same loop is copied in the history step and the brush loader).
- Putting a taken-off tile back recalculates its own edge normals and marks them changed, but the undo snapshot covers only the neighbours, so undoing a take-off isn't byte-for-byte for real-game tiles.
- Add and take-off recalculate normals one row deeper than the shared edge, against decision 5, changing original-slope bytes in neighbours.
- Undo/redo of add or take-off ignores failures, so the history can say the opposite of the map's state.
- Every taken-off tile is kept in memory forever with its full data and file bytes.
- After the editor takes off a tile and saves, the project check warns the file "was taken away", because the record of copied files isn't updated by editor actions.
- Falling back to listing tiles from files is decided by matching the reader's English error text; it should be a separate flag.
- The WDT is read and parsed twice on open; the tile-name and file-exists helpers are re-implemented; the file-list fallback and the straight-up normal default are silent.

## Intended Behavior

- **The WDT says which tiles a map has.** `wowmap.open` reads the tile list from the WDT through the W client's `wdt_read`.
  - A tile the WDT lists whose file is missing is still one of the map's tiles; reading it says why.
  - An ADT file the WDT doesn't list is not a tile.
  - The terrain tests read W02's WDTs back through the same reader.
- **A tile can be added next to the map's others.** Its ground is either flat at a given height or made to meet its neighbours' edges.
  - Saving writes its file, sets its MAIN flag in the WDT (patched in place), and adds its far view to the WDL.
  - Undo takes it off again.
- **A tile can be taken off.** Saving deletes its file, clears its flag and takes its far view out of the WDL. Undo puts it back, byte for byte.
- **Flowing water keeps its format.** An edited water layer of format 1 or 3 stays in that format.
  - Points the layer already had keep their picture positions.
  - New points get positions that continue the layer's own.
- Everything an edit didn't touch keeps its bytes.

## Suggested Implementation Steps

1. `editor/wowmap.lua`: read the tile list through `wdt_read`; keep the missing and unlisted files apart; fall back to the files present only when the reader can't read WDTs.
2. `editor/wowtiles.lua` (new): add, remove and put back a tile. Supply the base bytes of a tile that has no file, patch the WDT's MAIN flags, and list the tiles taken off.
3. `editor/wowwdl.lua`: `remove`, which takes a tile's far view out of the WDL.
4. `editor/wowterrain.lua`:
   - `save` writes new tiles, the WDT and the WDL, and deletes the files of tiles taken off;
   - `E:wow_add_tile` and `E:wow_remove_tile` each record one history step.
5. `editor/wowwater.lua`: formats 1 and 3 kept through an edit, with their picture positions.
6. Tests, from the project root: `test_wow_tiles.lua` (new), and WDT checks in `test_wow_terrain.lua`.

## Acceptance Criteria

- [x] A map's tiles come from its WDT, read through `wdt_read`. Missing and unlisted files are told apart.
- [x] W02's WDTs read back through `wdt_read` in the terrain tests: tiles, version, blend-map form; a short WDT is refused.
- [x] A tile is added flat, or matching its neighbours. It is saved, read back by the W client, listed by the WDT and drawn in the WDL. It joins its neighbours exactly.
- [x] Adding and then taking off a tile, saved, leaves the WDT, the WDL and the neighbour tile byte for byte as they were.
- [x] A new tile edited before its first save (raised, painted, a hole, water) is written with those edits.
- [x] The editor's add and take-off are one history step each, with undo and redo before and after a save.
- [x] An edited format-3 or format-1 layer keeps its format. Its old points keep their positions; new points continue them; other chunks' water keeps its bytes.
- [ ] A new tile, and an edited flowing-water layer, shown by the stock client and Noggit (the owner's machine; decision 12).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Where does the tile list come from, and what if the reader can't read WDTs?
2. What about a tile the WDT lists with no file, or a file it doesn't list?
3. What ground does a new tile get?
4. What else does a new tile hold, and how is it written?
5. What happens to the neighbours' normals?
6. How is the WDT changed?
7. How does the WDL follow an added or removed tile?
8. Can a tile be taken off, and what happens to its file?
9. Where can a tile be added?
10. How do undo and redo work?
11. How does flowing water (formats 1 and 3) survive an edit? (Reversing W10c decision 5, as asked.)
12. Which byte offsets come from the readers, and which are unchecked?

## Decisions (2026-11-05; each the owner's to overturn)

1. **The WDT's MAIN, read through the W client's `wdt_read`; the files present only without it.** This supersedes W10a decision 2.
   - `wowmap.open` reads the WDT through `wdt_read` (098-wdt.c, built into libwreaders.so). A tile is one of the map's when MAIN's flag 1 is set.
   - wete's tile `<tx>_<ty>` is MAIN entry `ty * 64 + tx`. The W client numbers the same entry `x * 64 + y`, with its x being wete's ty. So `wdt_has_tile(w, ty, tx)` asks about wete's tile (tx, ty).
   - The terrain test checks this both ways on W02a's WDT: the raw flags and `wdt_has_tile`, with a transposed tile absent.
   - Without the library, or with one built before `wdt_read`, the tiles are taken from the ADT files present, as before. `M.tile_source` is then `"files"` and `M.tile_source_why` says why.
   - No WDT reader is written here: one reader per format (decided 2026-10-07).
   - A WDT the reader refuses (for example, cut short) stops the map from opening, with the reader's reason.
2. **A listed tile without its file is still a tile; an unlisted file is not.**
   - A tile the WDT lists whose file is missing stays in `M.tiles` and is also in `M.missing`. Reading it says that the WDT lists it but its file isn't there. The project's check with reading on calls this an error.
   - An ADT the WDT doesn't list is in `M.unlisted`. The project's check with reading on gives a warning, because the W client never loads it.
   - Copying a map into a project (`mapfile.add_wow`) still copies every file in the folder.
3. **Flat at a height, or a Coons patch of its neighbours' edges; shared points keep their heights in both modes.**
   - `tiles.add(m, tx, ty, { height })` makes the ground flat at that height.
   - Without a height, each side the new tile shares with a neighbour is that neighbour's edge, point for point.
     - A side with no neighbour runs straight between its corners.
     - A corner no tile shares takes the mean of the corners beside it that are known. If none are known, it takes the mean of all known corners.
     - Inside, the Coons patch blends each side toward the one across, less the blend of the four corners. A tile below one neighbour therefore carries that neighbour's edge straight across, and the ground keeps its slope (tested).
   - Middles are the mean of their four corners, and each chunk's base is its lowest point (W02a's rules).
   - Points shared with a tile already there keep that tile's height in both modes, so the ground never splits. A flat tile next to higher ground rises to meet it within its first cell.
4. **One texture, nothing else; written by W02a's writer, then patched.**
   - The new tile has one texture: `opts.texture`, or else the first texture of a neighbour (side neighbours before corner neighbours). With neither, it is refused.
   - It has no holes, shadow, tints (127), water or placed objects. Area is 0 and the chunk flags are W02a's 0x8000.
   - Its file is `<dir>_<tx>_<ty>.adt`.
   - At its first save, W02a's tile writer (`adt.tile_bytes`) makes the base bytes from its ground, normals and first texture. W10b's and W10c's patching then adds whatever was painted, cut or watered since, as for any edited tile. That patching is tested.
5. **Normals by W02a's rule; the neighbours' edges are worked out again.**
   - Every point of a new tile gets its normal by W02a's rule (`wt.normal`).
   - The corners on its neighbours' shared edges are worked out again: they were one-sided, as at a map's edge, and are now two-sided. Their files' MCNR change there and nowhere else (tested on the hut's tile).
   - Taking a tile off makes its neighbours' edges one-sided again. So adding a tile and then taking it off, saved, leaves a W02 neighbour byte for byte as it was (tested).
   - A stock neighbour's own edge normals come back as they were only through undo: the editor's undo puts the edge chunks back from a snapshot (decision 10).
6. **MAIN's flag bit, patched in place; nothing else in the WDT.**
   - At the save, each added or removed tile's MAIN entry has bit 1 set or cleared. The entry's other bits, its second word, MPHD and MWMO keep their bytes.
   - Adding and removing a tile changes exactly one byte (tested).
   - A WDT with no full MAIN is refused.
7. **Appended or patched whole; taken out with MAOF moved along.**
   - A new tile's far view goes in at the WDL's end (W10c decision 4). A tile written for the first time, or put back after a save, counts as edited everywhere, so a far view the WDL already holds for it is patched whole.
   - `wowwdl.remove` takes a removed tile's MARE (and the MAHO right after it) out, sets its MAOF entry to 0, and moves the later entries along.
   - It is refused when the entry doesn't point at an MARE, or when another entry points into the bytes being taken out.
   - A map without a WDL still gets none (W10c decision 1).
8. **Yes, it falls out naturally; the file goes at the save, and the bytes are kept for undo.**
   - `tiles.remove` takes a tile off the map's list and its shared grid, and keeps its data and its file's bytes.
   - The save deletes the file (unless a new tile has taken the name), clears the flag and takes out the far view.
   - `tiles.put_back` gives the tile back whole. After a save, its file is written again from the bytes it had, with any edits made before it was taken off.
   - A listed tile whose file is missing can be taken off; only its flag changes.
9. **Inside 0-63, where the map has no tile, and not over a file the WDT doesn't list.**
   - A flat tile can go anywhere in range.
   - A matching tile needs at least one of its eight neighbours.
   - A file the WDT doesn't list at that name is never written over; the add says to move it first. A file of a tile taken off but not yet saved is written over, because it is the map's own.
10. **One history step each, with the neighbours' edges snapshotted.**
    - `E:wow_add_tile(tx, ty, opts)` and `E:wow_remove_tile(tx, ty)` work on the map `E:wow_edit` picked.
    - Each records one step. Undo of an add takes the tile off; redo puts the same tile back. Undo of a take-off puts it back.
    - Either way, the chunks along the shared edges are put back from W10b's snapshots, including their marks for what still needs writing.
    - Undo before a save leaves nothing to write. After a save, the next save writes the files back as they were (tested both ways, and for the hut's tile taken off and put back).
11. **Formats 1 and 3 are kept, with their picture positions.** This supersedes the last bullet of W10c decision 5, which wrote such a layer as format 0.
    - An edited layer is matched to the file's layer of the same kind: the first of that kind for the first, and so on. If that file layer was format 1 or 3, the edited layer is written in the same format, each point with its two u16 picture positions after the heights. Format 3 then has its depth bytes; format 1 has none.
    - A point the file's layer had keeps its exact positions. That covers every point of the old rectangle, so the cells that stay wet keep theirs.
    - A point new to the layer gets the positions the layer's own points lie on: a plane fitted to them by least squares over the chunk's 9 x 9 corners, rounded and held to 0-65535. A run of positions that rises steadily, the usual case, carries on unchanged (tested exactly).
    - A layer with no positions at all gets `UV_STEP` (2) a cell. That value is a guess and unchecked.
    - A layer of a kind the file didn't have is written in format 0 (W02a), as before. An edited format-2 layer is still written as format 0.
    - Other chunks' water keeps its bytes (tested).
12. **Offsets confirmed by code, and the unchecked list.**
    - **Confirmed by the W client's readers:**
      - MAIN at 8 bytes an entry, flag 1, index `ty * 64 + tx` in wete's numbering (098-wdt.c, both ways);
      - MPHD's flag 0x4 (8-bit blend maps);
      - MH2O formats 1 and 3: heights, then 4 bytes a point, then format 3's depths (020-adt.c reads the heights and depths at those places).
    - **Unchecked:**
      - the picture positions' meaning: which u16 runs along the columns, their scale (`UV_STEP`), and how the stock client wraps them. Neither project's reader reads them; they are kept and continued, never interpreted.
      - MAIN's second word (kept as it is);
      - WDL blocks before MAOF (low-detail buildings in a stock WDL): taking a tile out moves only what comes after the tile, so offsets inside those blocks are untouched. No stock WDL has been tried.
      - MCNK header bytes 32, 88, 96 and 120 (W10b);
      - MH2O's attributes (W10c).
    - **To check on the owner's machine:**
      - a tile added to a stock map, and one taken off;
      - an edited magma or slime layer, flowing in the stock client and Noggit.

## Implementation Notes

*(2026-11-05)*

- **`src/editor/wowmap.lua`:**
  - `read_wdt(bytes, lib)` and `tile_name(dir, tx, ty)`.
  - `open` lists the WDT's tiles and sets `missing`, `unlisted`, `wdt_info` and `tile_source` (with `tile_source_why`). It opens the reader library when the map is opened.
  - `M:tile` says when a listed tile's file is missing.
- **`src/editor/mapfile.lua`:** `validate_wow` with reading on warns about each ADT the WDT doesn't list.
- **`src/editor/wowtiles.lua` (new):**
  - `add`, `remove` and `put_back`;
  - `base_bytes`, `wdt_bytes`, `taken_off` and `saved` for the save;
  - `border_chunks` for the editor's undo;
  - `off_at`.
- **`src/editor/wowwdl.lua`:** `remove`.
- **`src/editor/wowterrain.lua`:**
  - `save` patches a tile with no file from its base bytes. It writes the WDT when tiles were added or taken off, counts an added tile's far view as whole, removes far views, and deletes taken-off tiles' files after the writes.
  - `E:wow_add_tile` and `E:wow_remove_tile`.
  - `wt.internal` also gives `index_tile`, `renormal`, `read` and `KEY`.
- **`src/editor/wowwater.lua`:**
  - `chunk_bytes` takes each layer's carried format and positions;
  - `carried` matches layers by kind;
  - `ww.plane` (least squares) and `ww.UV_STEP`.
- **Tests:**

  | Test | With the library | Without |
  |---|---|---|
  | `test_wow_tiles` (new) | 80 | 1 skipped |
  | `test_wow_terrain` | 168 (was 161: 7 WDT checks through `wdt_read`) | 70 and 15 skipped (was 14) |

  Unchanged:

  | Test | With the library | Without |
  |---|---|---|
  | `test_wow_water_and_far_view` | 58 | 6 and 1 skipped |
  | `test_wow_terrain_editor` | 77 | 3 and 1 skipped |
  | `test_wow_layer` | 50 | 34 and 2 skipped |
  | `test_mapfile` | 36 | 36 |
  | `test_editor` | 83 | 83 |
  | `test_editor_integration` | 44 | 44 |
  | `test_wow_placements` | 89 | 71 and 5 skipped |

  `test_wow_tiles` covers:
  - **The tile list:**
    - from the WDT;
    - a missing file and an unlisted one, both said by the project's check;
    - a flag cleared by hand;
    - a short WDT refused;
    - a library without `wdt_read`, falling back to the files.
  - **A flat tile:**
    - refusals: an existing tile, out of range, over an unlisted file, matching with no neighbour;
    - its ground, its edge, its texture and its chunks' places;
    - the neighbour's edge normals;
    - the files written: the WDT's one byte, an untouched tile byte for byte, the neighbour changed only in its edge normals;
    - read back by `adt_read`, joined, with the same edge normals in both files;
    - the WDL through `adt_wdl_read`, the other far views kept;
    - saved again with nothing written;
    - taken off and saved, every file as it was.
  - **A matching tile:**
    - its edge, carried across, still rising east;
    - raised, painted, cut and watered before its first save, then read back;
    - the editor's add and take-off with undo and redo around saves, the hut's tile back byte for byte.
  - **Flowing water:**
    - format-3 and format-1 layers (written by the test's own MH2O writer) read;
    - a cell wetted and a cell dried;
    - the format, the kept positions, the new positions, the read-back water and the untouched chunks' bytes;
    - `ww.plane`.

**Still open:**
- decision 12's checks on the owner's machine;
- the window's brush cursor and the yards conversion (next);
- W10 step 3 (the object placer).

*2026-11-05, later:* decision 4's "Area is 0" is superseded by W10f
decision 4 (`W10f-areas-and-doodad-sets-on-wow-tiles.md`): a new tile
takes `opts.area`, else the area most of its neighbours' facing chunks
are in, else 0.
