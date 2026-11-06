# Issue W10c: The Far View and Water on WoW Tiles

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (step 2's "place liquids", and the far view's half of step 8)
**Priority:** High (W10b's edits otherwise leave the far view and the water behind)
**Dependencies:** W10b (the terrain tools and the tile writer), W10a (the WoW layer, read through the W client's reader), W02a (the WDL and MH2O writers whose form this follows)
**Blocks:** W10's acceptance line 2 for water; Test Map showing edited ground from far away

---

## Current Behavior

*As written (2026-11-05, before this issue's work):*
- W10b edits a WoW map's ground and writes its tiles back, but leaves the WDL (`<map>.wdl`) alone. The far view therefore still shows the old ground and holes after an edit (W10b decision 7).
- Water (MH2O) is read through the W client's reader, but nothing places it or removes it.
- When the ground under water is raised or lowered, the water's depth bytes stay as they were (W10b decision 12).

*Now:* see Implementation Notes.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #257 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- Redo after a save restores water depths measured from the ground before it moved, and writes them out, because the restore drops the moved-points record that triggers recalculation.
- Every undo or redo after a save marks all restored chunks' water as edited, rewriting untouched flowing magma or depth-only layers as format 0, and an unknown vertex format then blocks the whole tile's save. Marking the moved points instead would rewrite only depths.
- The WDL patcher copies the entire WDL file for every 2-byte height it changes and for every MAOF entry on an insert: about 2.5 GB per tile edit and 10 GB more on insert for a stock continent. Build the bytes in a buffer and join once.
- The in-place water depth update copies the whole MH2O block per byte written (about 1 GB per ocean tile).
- With cleanup moved after every write, a failed WDL write leaves already-renamed tiles dirty with their old save count, so a following undo restores the wrong dirty state and the undo is never written.
- With no ground at the stroke point, water is silently placed at 2 yards.
- Growing a layer's rectangle leaves corners outside both old rectangle and new cells at the reader's fill value, corrupting the layer's low and high height.
- The "needs a block" scan runs again for every MCNK; the dirty-table copy is written twice; new functions lack folds.

## Intended Behavior

- **The WDL follows the tiles.** Saving the edited tiles also changes their far view in the map's WDL: the far heights and the far hole bits.
  - A WDL patched with no edit is byte for byte the file read.
  - The WDL can also be made afresh from every tile.
- **Water is placed and taken off.** It goes on and off cells of a WoW map's chunks, at a surface level and of a kind (water, ocean, magma, slime ...).
  - The tile's MH2O is written again with the edits in it.
  - What an edit didn't touch keeps its bytes.
  - Everything reads back through the W client's reader exactly as the tools left it.
- **Depths follow the ground.** When the ground moves under water, the water's depths follow.
- **The editor's strokes work on water.** The `water` and `dry` strokes, with undo and save, work on a picked WoW map with no window.

## Suggested Implementation Steps

1. `src/editor/wowwdl.lua`: a tile's far view from its data, patched into the WDL, or made afresh.
2. `src/editor/wowwater.lua`: the water tools on wowmap's liquids, and MH2O's layout and writer.
3. `src/editor/wowterrain.lua`:
   - MH2O written in `tile_bytes`, or made for a tile with none;
   - the WDL in `save`;
   - water in undo;
   - the `water` and `dry` strokes.
4. Tests on a W02-made map, read back through the W client's reader, with WDLs and MH2Os laid out as W02a does and as stock files may.

## Acceptance Criteria

- [x] **A tile's WDL patch:** saving an edited tile patches its far heights and hole bits. Every other byte of the WDL stays as it was, and the W client's reader reads the result.
- [x] **WDL made afresh:** gives W02's own WDL back within a yard.
- [x] **Water placed and dried:** water put on and dried off reads back through the W client's reader exactly as edited.
  - Every other chunk's water stays byte for byte.
  - A tile with no water gets an MH2O block, and its placements are still found.
- [x] **Depths in place:** ground moved under water rewrites only the affected depth bytes, in place.
- [x] **Unchanged water:** W02's water written again by the water writer is byte for byte the same.
- [x] **Stock-like layouts:** water laid out as stock files may have it (grouped parts, a depth-only layer) is written correctly. An unknown vertex format refuses only its own chunk.
- [x] **Editor strokes:** the editor's `water` and `dry` strokes, undo and save work on a picked WoW map.
- [ ] **Owner's machine:** the stock client and the W client show the edited far view and water through Test Map. A stock tile and WDL are edited (see the list under decision 11).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Is the WDL patched or written afresh after an edit, and what if a map has none?
2. Which far heights change?
3. When is a chunk a hole in the far view?
4. What if a tile has no MAHO, or isn't in the WDL at all?
5. Is MH2O patched or written afresh, and in what form are edited chunks written?
6. What does a water tool take, and what level is used when none is given?
7. How do water layers grow and shrink, and what happens at a chunk's edge?
8. Where do depths come from, and what happens when the ground under water moves?
9. What are the attributes (fishable, deep) of edited water?
10. What does the writer refuse?
11. Which byte offsets come from the readers, and which are unchecked?
12. Can a tile be made, or the WDT's list changed?

## Decisions (2026-11-05; each the owner's to overturn)

1. **Patched; a map with none gets none.**
   - Patching follows W10b's rule: what an edit didn't touch keeps its bytes. A stock WDL's own heights are not replaced by values recomputed from the tiles where nothing changed. Its other blocks (low-detail buildings before MAOF) are kept too.
   - `wowwdl.make(m)` makes one afresh from every tile (W02a's layout) when asked.
   - Saving never creates a WDL. The client works without one, and adding one changes what a map shows from far away.
2. **Each far height whose chunk's heights were edited, from the new ground.**
   - The 17 x 17 corners come from each chunk's first point. The tile's south and east edges come from the last chunks' far points. The 16 x 16 middles come from each chunk's point at row 4, column 4.
   - These are rounded to whole yards, the way W02a makes them. That rule gives W02's own WDL back within a yard (tested).
   - A point shared by chunks is edited in each of them (W10b decision 8), so a corner moved by an edit next door is also made again.
3. **When all 16 of its holes are cut.**
   - MAHO has one bit for each chunk: the W client's horizon (039-horizon) leaves out a square of its coarse mesh for each bit set, lowest bit first.
   - A chunk with ground left in it still shows from far away, so only a chunk with no ground left is a hole there.
   - Only chunks whose holes were edited have their bit set or cleared. This rule is checked against neither stock file nor stock client (decision 11).
4. **A missing tile is added; a missing MAHO is put in only when a bit is needed.**
   - A tile not listed in MAOF gets its MARE and MAHO at the WDL's end, and MAOF says where. Nothing else moves.
   - A tile with no MAHO gets one after its MARE only when a hole bit is to be set. The blocks after it then move, and MAOF's offsets move with them. Each offset must point at an MARE, or the write is refused.
5. **Patched: the edited chunks' parts replaced, every other part kept; edited water written in W02a's form.**
   - A tile's MH2O is untouched without a water edit or ground moved under its water.
   - An edited chunk's parts (layers, attributes, mask, points) are replaced by its new water, in W02a's form: format 0, heights then depths, mask and points padded to 4 bytes.
   - Every other chunk's parts keep their bytes. Their offsets (heads, masks, points) move with them.
   - A chunk getting water for the first time gets its parts at MH2O's end.
   - A tile with no MH2O gets one made before its first MCNK, and MHDR's field 10 says where. The blocks after it move, as W10b moves them.
   - W02's water written again this way is byte for byte the same, so the form is W02a's exactly.
   - A layer of format 1 or 3 that is edited is written as format 0, which drops its picture positions. Those formats are for flowing magma and slime; noted for the window's step.
6. **Cells under a round brush, or the one cell at the point.**
   - `ww.water(m, x, y, { radius, level, kind })` wets the cells whose middles are under the brush and sets their corners to `level`.
   - With a radius of 0, the one cell holding the point is used.
   - The default level is 2 yards over the ground at the point, matching the editor's WC3 water, which starts a little over the ground.
   - The default kind is 1 (LiquidType.dbc's water in 3.3.5a, as W02a writes it). `ww.dry` dries the cells of one kind, or of every kind.
   - In the editor, `brush.wow_level` and `brush.wow_liquid` set them. Otherwise the level comes from the ground where the stroke began, so one stroke is one level.
7. **One layer for each kind in a chunk; its rectangle follows its wet cells; chunks stand alone.**
   - Water of a kind the chunk hasn't got makes a new layer.
   - Each layer's rectangle (first column and row, width, height) is the box round its wet cells. A layer left with none is removed.
   - MH2O keeps each chunk's water separately, so a brush sets every cell it covers. A chunk's corner at the edge isn't joined to its neighbour's unless the brush covers both.
8. **Depths come from the surface over the ground, yards x 9, at write time for moved ground.**
   - A wetted corner's depth is (level - ground) x 9, held to 0-255. This is the W client's measure, which W02a uses.
   - Corners new to a rectangle get theirs the same way.
   - When the ground moves under water, each moved point's depth is worked out again when the tile is written. For water that wasn't otherwise edited, this is done in place in its depth bytes (formats 0, 2 and 3 hold them; 1 has none). No other byte changes.
9. **Fishable = the wet cells; deep = as it was, where still wet.**
   - W02a writes fishable for every wet cell and deep for none.
   - An edited chunk keeps its old deep bits for cells still wet, so a stock chunk's deep water stays deep.
   - Neither project's reader reads these 16 bytes, so they are unchecked (decision 11).
10. **Anything it can't account for is refused, rather than guessed at.** The write is refused, saying which, when:
    - an MH2O part lies outside its data or overlaps another chunk's part;
    - an offset points inside a replaced part;
    - an edited chunk has a vertex format other than 0-3 (another chunk's water is still written; tested);
    - the file's layers for a chunk don't match the ones read;
    - a WDL has no MAOF, or MAOF points where no MARE is.
11. **Offsets confirmed by code, and the unchecked list.**
    - **Confirmed by the W client's reader (020-adt.c):**
      - MH2O's 12-byte heads, its 24-byte layers (kind, vertex format, lowest and highest height, rectangle, mask, points), the mask's bit order, and formats 0-3's point sizes and where their depths are;
      - the WDL's MAOF, MARE (1090 bytes), MAHO (32 bytes after MARE) and their index, read by both projects as row (north to south) x 64 + column. W02a writes `ty * 64 + tx`; the W client's horizon names the same index with its tx taken from world x.
    - **Written by W02a but read by neither project's code, so unchecked:**
      - MH2O's 16-byte attributes (fishable and deep cells);
      - MHDR's field 10 as MH2O's offset (this project's own reader-side code, `wowterrain`, follows W02a's order).
    - **Unchecked from W10b, still open:** MCNK header bytes 32, 88, 96 and 120.
    - **To check on the owner's machine:**
      - a stock tile's water edited (a cell wetted, a chunk dried, ground raised under a lake) and a stock WDL patched;
      - both read back by the W client;
      - both shown by the stock client and Noggit, including whether the stock client takes a chunk's far hole bit the way decision 3 sets it.
12. **No, still.** A tile can't be made, and the WDT's tile list doesn't change. Making tiles waits for the W client's WDT tile-list reader (W10a decision 2), which the custom-client side is adding.

## Implementation Notes

*(2026-11-05)*

- `src/editor/wowwdl.lua` (new):
  - `SOURCES` (each far height's chunk and point);
  - `blocks(t)` (a tile's MARE and MAHO);
  - `patch(original, tiles)` (in place; a missing MAHO put in with MAOF moved; a missing tile added at the end);
  - `make(m)` (afresh, W02a's layout).
- `src/editor/wowwater.lua` (new):
  - `water` and `dry` (the tools);
  - `layout` (each chunk's layers and parts in an MH2O);
  - `mh2o_bytes`, which writes MH2O again, with three parts:
    - the depth bytes under moved ground, in place;
    - edited chunks' parts replaced in W02a's form;
    - every other chunk's parts kept, with their offsets moved;
  - `needs_block`;
  - `copy` and `put` (for undo).
- `src/editor/wowterrain.lua`:
  - `splice` (one routine for replacing parts and moving offsets, now also under a painted chunk's MCLY and MCAL);
  - `tile_bytes`: MH2O through wowwater, made before the first MCNK when needed, MHDR's field 10 pointing at it;
  - `save` writes the WDL after the tiles whose ground or holes changed, and marks tiles saved only once every file is written;
  - set_height records which points moved (for depths);
  - undo keeps a chunk's water, and an undo after a save writes its water again;
  - the `water` and `dry` strokes on a WoW map.
- **Tests:** `src/tests/test_wow_water_and_far_view.lua` (new). It passes 58 with the W client's reader library; without it, 6 pass and 1 is skipped. It covers:
  - **No edit:** the WDL and an MH2O come back byte for byte; W02's water layout is as expected; a short MH2O is refused.
  - **The WDL:**
    - made afresh, it matches W02's within a yard, and the reader reads it;
    - raised ground and a chunk all holes, saved: only the far heights under the edit change, and the bits are as decided;
    - holes filled again;
    - a tile with no MAHO gets one, with the next tile's offset moved;
    - a tile missing from the WDL is added;
    - MAOF pointing at nothing, and a WDL with no MAOF, are refused.
  - **Water:**
    - W02's water written again by the water writer is byte for byte the same;
    - water put on: the cells, level and depths, a radius of 0, read back, the lake's bytes kept;
    - water on the tile with none: MH2O made, and the hut still found;
    - dried: a whole chunk, and part of its neighbour.
  - **Depths:** ground raised under the lake changes the file's depth bytes only (with the heights and normals).
  - **Grouped parts:**
    - the reader reads them, including a depth-only layer;
    - with no edit they come back byte for byte;
    - one chunk edited among them;
    - the depth-only layer stays format 2 with its depths;
    - raised ground under it moves its depths;
    - an unknown format refuses only its own chunk.
  - **Editor:** water and dry strokes, undo, redo, save, and undo after the save, saved again as the map was made.

  `test_wow_terrain_editor` (W10b) now expects `wt.save` to list the WDL too: 77 with the library (3 and 1 skipped without). Unchanged:

  | Test | With the library | Without |
  |---|---|---|
  | `test_wow_layer` | 50 | 34 and 2 skipped |
  | `test_mapfile` | 36 | 36 |
  | `test_editor` | 83 | 83 |
  | `test_editor_integration` | 44 | 44 |
  | `test_wow_terrain` | 161 | 70 and 14 skipped |
  | `test_wow_placements` | 89 | 71 and 5 skipped |

**Still open:**
- decision 11's checks on the owner's machine;
- flowing water's picture positions (decision 5);
- the window's water cursor;
- new tiles (decision 12).

*(2026-11-05, later)* **Decision 5's last bullet is superseded** by
`W10d-tiles-from-the-wdt-added-and-taken-off.md` decision 11. An edited
water layer of format 1 or 3 now keeps its format: points the layer had
keep their picture positions, and new points continue them (a plane fitted
to the layer's own). Flowing magma and slime therefore survive an edit.
Decision 12 is also taken up there: tiles can be added and taken off, and
the WDT's tile list is patched.
