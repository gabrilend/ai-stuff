# Issue W10e: The Object Placer on WoW Tiles

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (step 3, the object placer, without its window)
**Priority:** High (a WoW map's models and buildings could not be changed)
**Dependencies:** W10d (tiles from the WDT), W10b (the tile writer, undo), W02b (the placement rules whose form this follows), the W client's `adt_place_read` (020-adt.c, public since custom-client draft PR #25)
**Blocks:** W10's acceptance line 3; the window's placing cursor

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- A WoW map's models (M2 doodads) and buildings (WMOs) are read through the W client's reader as data, but nothing places, moves or removes them.
- The tile writer keeps a tile's placement blocks exactly as they were.

*Now:* see Implementation Notes.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #259 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- For a tile added and not yet saved, the loader reads records from whatever file is on disk at that name; after removing a stock tile and adding one at the same place, any object edit fails and every object tool on the map is refused until save.
- The loader runs once per map, so a tile that returns through undo never gets its records attached: new placements can reuse its ids, and saving its edits fails.
- A new building's box ignores its turn, so its chunk references miss the chunks it actually stands in.
- If a save fails partway, a tile's file can already be replaced while its entries keep old record numbers; the next save maps references through the wrong numbers and corrupts MCRF.
- One listed-but-missing tile makes every object tool on the whole map refuse.
- Every editor step copies every placement on every tile into history (gigabytes on a continent over 50 steps).
- The loader reads every tile in full only to find unique ids and records.
- Placing without x and y raises a Lua error instead of returning a reason.
- Sizes are silently held to 1–65535 and a lost ground height silently drops a moved object to the ground; unused locals and a copied file reader remain.

## Intended Behavior

- **Objects can be changed as plain Lua.** Models and buildings are placed, moved, turned, sized and taken away on a WoW map's tiles. The editor gets the same as history steps with undo and redo, before and after a save.
- **Only placement bytes change.** Saving an edited tile rewrites only its placement blocks:
  - the name lists (MMDX/MMID, MWMO/MWID);
  - the records (MDDF, MODF);
  - the chunks' references (MCRF);
  - the offsets that follow them.

  An unedited tile, and every unedited record, stays byte for byte.
- **Unique ids stay unique across the map.** An object that crosses a tile edge is listed where the client looks for it.
- **The W client's reader reads it back.** That is `adt_read`, and `adt_place_read` for a single record. W02's own placements, written again from the data, come out unchanged.

## Suggested Implementation Steps

1. `editor/wowplace.lua` (new):
   - **Load:** every tile, each entry tied to its file record;
   - **Edit:** place, move, rotate, scale, delete, near;
   - **Undo:** snapshot, restore;
   - **Save:** the plan of an edited tile's blocks and references; the MCRF patch;
   - **Editor:** `attach`, the editor's history steps.
2. `editor/wowterrain.lua`: `tile_bytes` writes the plan, and `save` passes the map and records what was written.
3. `editor/init.lua`: attach the placer.
4. Tests, from the project root: `test_wow_objects.lua` (new).

## Acceptance Criteria

- [x] With nothing edited, nothing is written. W02's placements, written again from the data (records and references), are W02's byte for byte.
- [x] **Place:** a model is placed, saved and read back by `adt_read` and `adt_place_read`. Its name is added to MMDX/MMID, the other records are unchanged, and only its chunk's MCRF changes.
- [x] **Move, turn, size:**
  - a model moved across the tile edge keeps its id and its height over the ground, and both tiles' references follow;
  - a model turned and sized changes only those fields.
- [x] **Buildings:**
  - a building over the tile edge is listed by both tiles with one id and referenced by the chunks its box touches on each side;
  - a turned building's box doesn't grow;
  - a deleted building takes its references with it.
- [x] Ids are never reused. Placing off the map, sizing a building and an unknown id are refused.
- [x] Placements and ground edits on one tile are written in one save.
- [x] In the editor, undo and redo work before and after saves. Everything undone and saved gives every file back byte for byte.
- [ ] A placed model and building shown by the stock client and Noggit, on the owner's machine (decision 13).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. What do the tools take, and in what units?
2. What does a save rewrite, and what does it keep?
3. What happens to the name lists?
4. How are positions written so a round trip is exact?
5. How are unique ids chosen?
6. Which tiles list an object that crosses a tile edge?
7. Which chunks reference an object (MCRF), and does the client use them?
8. Where does a moved object stand in height?
9. What happens to a building's box when it is turned or moved?
10. Can a building be sized? What size is a new building?
11. How does undo work, especially across a save?
12. Is a yards conversion needed?
13. Which byte offsets come from the readers, and which are unchecked?

## Decisions (2026-11-05; each the owner's to overturn)

1. **World yards and the file's own angles.**
   - An object is `{ kind = "m2" or "wmo", uid }`: every entry on the map's tiles with that kind and unique id.
   - Positions are world yards as the reader gives them (x north, y west, z up), as the terrain tools use.
   - Rotations are the file's three angles in degrees. The second turns the object about the vertical: W02b's facing, `ry = WC3 angle + 90`. `yaw` sets only that one; `rot` sets all three.
   - The kind comes from the file's extension (.m2 or .mdx for a model, .wmo for a building); anything else is refused.
   - `pl.load` reads every tile of the map. Ids and buildings across tiles need them all.
2. **Only the placement blocks and the references of an edited tile.**
   - A tile without a placement edit is not written for one.
   - In an edited tile:
     - MDDF and MODF keep each record as it was, byte for byte, except the fields an edit changed;
     - records of objects taken away are left out, and new ones go at the end;
     - each chunk's MCRF is written again only when its references changed.
   - The blocks after a changed one move along, and MHDR's, MCIN's and each MCNK header's offsets follow (W10b's machinery).
   - A record's flags, its building's name set and its padding are kept from the record it had. A new record has them at 0, as W02b writes them.
3. **Names are appended; the file's own names stay; this session's unused ones are trimmed from the end.**
   - A model or building whose name the tile hasn't got gets it added at the end of MMDX/MWMO, with its offset in MMID/MWID. No existing number changes.
   - A name the tile had when the map was loaded stays even when nothing uses it any more. The hut's name stays after the hut is deleted.
   - A name added in this session that nothing uses is dropped from the end. So an undone placement, saved, leaves the lists as they were (tested).
4. **Positions with the reader's own float, 17066.666f.**
   - The W client turns placement space into world as `17066.666f - stored`.
   - The way back uses the same float, so a position read and written again is the same float. W02's records encoded again from the data are byte for byte W02's (tested).
   - A building's world box goes back to placement space with its corners swapped, as the axes flip (020-adt.c's reading, inverted).
5. **The map's largest unique id + 1, and never reused in the session.**
   - At load, the next id is one past the largest id on any tile. Each placement takes the next and moves it on.
   - A deleted object's id is not given out again, so an undo can always bring it back.
   - W02b numbers its placements 1, 2, 3 ...
6. **A model is listed by the tile it stands in; a building by every tile its box touches, with one id.**
   - The W client keeps each tile's list and places an id once, by the first tile that lists it (042-doodads.c, 173s). A building listed by two tiles therefore shows once, and stays while either tile is loaded.
   - W02b lists objects the same way.
   - Only an object that was edited is listed again by this rule. An untouched object keeps the tiles it had.
   - Moving a model over a tile edge takes it out of one tile's MDDF and into the other's, with the same id (tested). A building moved, or placed over an edge, likewise.
7. **MCRF by W02b's rule for what moved; every other reference renumbered and kept.**
   - In 3.3.5a a chunk lists the MDDF and MODF numbers of what stands in it (MCRF: models first, then buildings; counts at header bytes 16 and 56). MCRD and MCRW are later expansions' split files, not 3.3.5a's.
   - Neither project's code reads MCRF; the W client places by the tile lists (decision 6). The stock client is known to cull by these lists, so they are kept right.
   - **Kept:** references to objects that didn't move are renumbered, and dropped for objects gone.
   - **Worked out again:** for a moved, turned (building) or new object, by W02b's rule. A model is referenced by the chunk it stands in; a building by every chunk its box touches.
   - A point on a chunk line belongs to the chunk south or east of it (within 0.1 mm, since W02b places on tile points and some sit on chunk lines). A box ending exactly on a line doesn't reach past it.
   - A chunk with no MCRF that needs references is refused.
8. **A moved object keeps its height over the ground.**
   - `pl.move(m, o, x, y)` sets z to the ground at the new place plus the object's old height over the ground at the old place. A z given is used as it is.
   - A new object stands on the ground unless a z is given.
9. **A building's box moves with it; when turned, it becomes the square that holds it at every turn.**
   - Moving shifts the box by the move.
   - Turning makes the footprint a square centred where the building stands, with a half-side equal to its farthest corner's distance. That square holds the building however it is turned, so turning again never grows it.
   - A box that is already such a square (W02b's kind, or one made here) is kept as it is. The height is kept.
   - The model's own box (the WMO's MOHD) isn't read: there are no game files here.
10. **Models only; a new building's box from `size`.**
    - A model's size is MDDF's 1024ths, held to 1-65535. A building is refused, since MODF keeps no scale in 3.3.5a.
    - A new building's box is `size = { across (west-east), up, deep (north-south; else across) }` yards. Without it the box is 10 x 10 x 10, W02b's default.
11. **Each step snapshots every tile's placements; undo after a save matches by id.**
    - Each editor step (`E:wow_place`, `E:wow_move_object`, `E:wow_rotate_object`, `E:wow_scale_object`, `E:wow_delete_object`) snapshots every tile's placements before it, and the tiles it touched after it.
    - **Before a save:** undo puts the lists back exactly, including what still needs writing. Nothing is written for a step undone (tested).
    - **After a save:** the file numbers its records afresh. A snapshot entry identical to the entry with its id there now is that entry. Any other entry is written again whole, from its data, with its references worked out again.
    - Everything undone after a save, then saved, gives every file back byte for byte (tested). So does one step undone after a later save (the hut back, with its references).
12. **No yards conversion is needed here.**
    - The placer works in world yards, as the terrain tools do.
    - Turning the window's cursor (WC3 units) into yards is the brush cursor's work, which needs the window.
13. **Offsets confirmed by code, and the unchecked list.**
    - **Confirmed by the W client's reader:**
      - MDDF (36 bytes) and MODF (64 bytes) as `adt_place_read` reads them: name, id, position, rotation, scale, doodad set and box. The box's corner swap is confirmed by reading records written here back through it.
      - MMDX/MMID and MWMO/MWID, by `adt_read`'s naming of each placement.
    - **Written by W02a/W02b and kept, but read by neither project, so unchecked:**
      - MCRF and MCNK header bytes 16 (model references) and 56 (building references), and bytes 32, 88, 96 and 120 (W10b);
      - MDDF's flags and MODF's flags and name set (kept from the record).
    - **To check on the owner's machine:**
      - a model and a building placed, moved and deleted on a stock tile;
      - a building over a tile edge, shown once;
      - the stock client drawing each from its chunks' MCRF.

## Implementation Notes

*(2026-11-05)*

- **`src/editor/wowplace.lua`** (new):
  - **Loading and finding:** `load`, `near` and `entries_of`;
  - **Edits:** `place`, `move`, `rotate`, `scale`, `delete`, and `touch` (every entry counted as edited);
  - **Undo:** `snapshot` and `restore`;
  - **The save:**
    - `plan(m, original, t)`: the six blocks, each chunk's references, and what was written;
    - `patch_refs(B, refs)`: one chunk's MCRF, its header counts and the offsets after it;
    - `encode(p, name)`: one record;
    - `saved(t, pending)`;
  - **Editor:** `attach(E)`.
  - **Grid:** `places_of` (which tiles and chunks) and `chunk_at`.
- **`src/editor/wowterrain.lua`:**
  - `tile_bytes` asks `wowplace.plan` when `tile.places_dirty`, writing its blocks and chunk references beside the ground's and water's;
  - `save` passes the map, and a written tile records its new record numbers;
  - `restore` keeps a tile dirty while its placements are.
- **`src/editor/init.lua`:** attaches the placer.
- **Tests:** `src/tests/test_wow_objects.lua` (new): 59 with the library, 1 skipped without. It covers:
  - loading;
  - W02's placements written again unchanged;
  - a model placed;
  - a model moved across the tile edge, turned and sized;
  - a building over the edge;
  - a building turned (square kept; a long building's box made square once);
  - a building deleted;
  - refusals, and ids not reused;
  - placements and ground in one save;
  - the editor's steps with undo and redo around saves.

  The other tests are unchanged; see the PR for counts.

**Still open:**
- decision 13's checks on the owner's machine;
- the window's placing cursor and its yards conversion;
- reading a WMO's own box (MOHD) for a new building, once game files are at hand.
