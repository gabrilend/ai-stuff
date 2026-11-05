# Issue W10b: The Terrain Editor on WoW Tiles

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W10 (its step 2 without the window, and the ground half of step 8)
**Priority:** High (the first editor that changes a WoW map)
**Dependencies:** W10a (a project's WoW layer, read through the W client's reader), W02a (the ADT writer: its block form, the normals rule, the blend maps' form), 902 (the editor's terrain brushes)
**Blocks:** W10's acceptance line 2 (ground edited in a WoW map, saved, shown by Test Map)

---

## Current Behavior

*As written (2026-11-05, before this issue's work):* W10a reads every
tile of a project's WoW map into plain Lua data (chunks, 145 heights,
holes, layers with 64 x 64 blend maps, placements, water), and keeps the
files byte for byte. Nothing changes that data, and nothing writes a
tile back: W02a's writer writes only the tiles W02 converts from a WC3
map. The editor's terrain tools (902) work on the WC3 map's tile points
only.

*Now:* see Implementation Notes.

## Intended Behavior

The ground tools work on a WoW map's tiles as they do on a WC3 map's
tile points, and an edited tile is written back into its file:

- raise, lower, smooth and flatten the heights under a round brush;
- paint a texture over the chunks' blend maps (a new layer, or a new
  texture in the tile's list, when needed);
- cut and fill holes;
- a tile written without an edit is byte for byte the file read (W10's
  acceptance line 3), and an edited tile reads back through the W
  client's reader with exactly the heights, holes and blend maps the
  tools left;
- the editor's own strokes (stroke_begin, stroke, stroke_end, undo,
  save) do this on a WoW map of the project, with no window needed.

## Suggested Implementation Steps

1. `src/editor/wowterrain.lua`: the tools on wowmap's tile data, a
   grid of points shared between chunks and tiles, normals by W02a's
   rule.
2. The writer: the tile's own bytes, patched where the edits are; the
   blocks after a resized one moved along, with the offsets that point
   at them.
3. The editor's hook: its strokes on a WoW map, undo, and the project's
   save writing the edited tiles.
4. Tests on a WoW map W02's converter makes (no WC3 or WoW install), read
   back through the W client's reader.

## Acceptance Criteria

- [x] A tile written without an edit is byte for byte the file read
      (W02's tiles, and a chunk laid out as the original game's are:
      packed blend maps, MCNR's padding outside its size).
- [x] Raise, lower, smooth, flatten, paint and holes change the tile
      data; written and read back through the W client's reader, every
      height, hole, layer and blend map is as the tools left it.
- [x] Height and hole edits are written in place: only those bytes
      change.
- [x] A new layer or texture grows the tile; its other blocks
      (placements, water) are still found where its offsets say.
- [x] The editor's strokes, undo and save do this on a project's WoW
      map, with no window.
- [ ] Shown by the W client through Test Map (W10's acceptance line 2:
      needs the owner's machine), and a real tile from the stock client
      edited and read back (needs a WoW install; see decision 11).

## Open Questions (each answered 2026-11-05, as decisions below; the owner's to overturn)

1. Is an edited tile written afresh by W02a's writer, or are its own
   bytes patched?
2. What units and positions do the tools take?
3. Which normals change when heights do, and by what rule?
4. Does a chunk's base height move when its ground is raised?
5. How is a texture painted, and in what form are painted blend maps
   written?
6. What happens to a fifth texture in a chunk that has four?
7. How are holes numbered, and does the far-off view (WDL) follow?
8. What happens at a tile's edge?
9. How do the editor's own tools reach a WoW map, and how does undo
   work across a save?
10. Where does an edited tile go, and what of the layer's record?
11. Which bytes may be moved when a chunk grows, and what if one can't
    be?
12. Can a tool reach past the map's tiles, or change its water?

## Decisions (2026-11-05; each the owner's to overturn)

1. **Its own bytes, patched.** W02a's writer writes what W02 makes and
   no more: no shadows (MCSH), tints (MCCV), packed blend maps, MFBO,
   MTXF, area numbers, ground effects or sound emitters, all of which a
   tile from the stock client or Noggit has. Written afresh, such a tile
   would lose them and could never come back byte for byte. So the
   writer keeps the file and changes only what an edit touched, and an
   unedited tile is the identity (tested on W02's tiles and on a chunk
   laid out as the original's). What it takes from W02a: the block form
   (`adt.block`), MCNK's header layout, MCLY's flags, the 8-bit and
   4-bit blend maps' form, flag 0x8000, the low-quality map's bit order
   and the normals rule.
2. **World yards, as the reader gives them.** A tool takes a point
   (x north, y west) and a radius in yards (W10a decision 7); amounts
   are yards. In the editor, a WoW stroke's brush is the WC3 brush read
   in WoW's measure: `brush.size` tile points (one WC3 tile is one WoW
   cell, 4.17 yards, as W02 places it), `brush.strength` WC3 units
   (1/30.72 yard each), unless `brush.wow_radius` / `brush.wow_amount`
   say yards. The falloff is linear (full at the middle, none at the
   edge), as 902's brushes; flatten's is flat.
3. **Only the normals that depend on a changed point, by W02a's
   rule.** A corner's normal from the corners either side of it (one
   sided where the map has none), a middle's from the four corners round
   it. The rule gives W02's own normals back within 1 (rounding) at
   every point of the test map, nearly all exactly. A Blizzard tile's
   other normals are its own and are left alone, so an edit doesn't
   restyle the light of ground it didn't touch.
4. **No: heights move, the base stays.** A chunk's 145 heights are
   above its base (header position z); a tool changes the heights and
   leaves z, so the edit is in place (MCVT only). A height may go below
   the base. Moving the base would rewrite all 145 for nothing the
   reader or W client needs; if the stock client culls a chunk by its
   base, that is to check on the owner's machine (decision 11's list).
5. **Layer over layer; painted chunks written plain.** Each layer above
   the first covers what is under it by 0-255. Painting layer L by w:
   L covers (255 - a) * w more, every layer above L covers w less, so L
   shows; painting the first layer uncovers it. A painted chunk's
   blend maps are all written again, uncompressed: 8 bits a point when
   the map's WDT says so, else 4 (the nearest of 16 steps, as the reader
   scales them). Its flag 0x8000 is set (every row and column of the
   maps is real) and its low-quality map is made again: per 8 x 8 cell,
   the layer that shows most. Unpainted chunks keep their bytes, packed
   or not. Writing runs (packed maps) saves only space; the W client's
   reader reads both.
6. **It takes the place of a layer that covers nothing; else none.** A
   layer above the first whose blend map is all 0 is replaced; with
   none, the chunk is left as it is and named in the tool's `full`
   list (the editor says how many). The fifth texture's name is still
   added to the tile's list (MTEX holds names the chunks don't use, as
   Blizzard's do).
7. **4 x 4 a chunk, bit row * 4 + column; the WDL not yet.** MCNK's
   low-resolution holes (header byte 60), each hiding 2 x 2 cells,
   numbered as the W client's ground (its 033-ground-prep) reads them.
   The WDL's far-off heights (MARE) and holes (MAHO) are left as they
   were: W02a writes the WDL from a WC3 map, not from tiles, so after an
   edit the far-off view shows the old ground until a WDL is made from
   the tiles (a later step of W10's step 8, noted under Still open).
8. **One ground: every copy of a point moves.** A chunk's border
   points are also its neighbours' (in the tile, and across a tile's
   edge in the next tile). The tools work on points by their place on
   the map, read the tiles under the brush (and a cell beyond, for the
   normals), and change every copy, so chunks and tiles stay joined
   (tested on the two tiles' shared edge).
9. **The same strokes, on the map picked by `E:wow_edit(dir)`.** The
   editor's `stroke_begin`, `stroke` and `stroke_end` pass to the WoW
   map while one is picked, so the window's existing calls will edit it
   unchanged (x and y in that map's yards: the window's conversion is
   W10's drawing step). `hole` and `unhole` join the editor's tools;
   they are terrain tools only on a WoW map. A stroke is one step to
   undo: each chunk it may change is kept as it was first touched,
   with its tile's texture names. Undone after a save, the file no
   longer holds what the snapshot does, so the chunk is written whole
   again (heights, holes, layers) and its normals worked out again.
10. **Over its file in the project's `wow/`; the record as it was.**
    `E:save()` on a project writes the WoW layer's edited tiles first
    (then the WC3 part, then packs a `.wex`); `wt.save(m)` does it for
    any map folder, through a temporary file renamed over the tile.
    `wow/layer.lua` keeps recording what was added, so validation says
    a tile changed since then, as information (W10a decision 4).
11. **Only what points at a block; else refused, not guessed.** When a
    chunk's layers grow, the sub-blocks after them move: a header field
    (bytes 20, 24, 28, 32, 36, 44, 88, 96, 116, 120: MCVT, MCNR, MCLY,
    MCRF, MCAL, MCSH, MCSE, MCLQ, MCCV, MCLV) is moved only when it
    points at a block's tag; one pointing anywhere else past the layers
    refuses the write, saying which byte. When a tile's blocks move,
    MHDR's 11 offsets and MCIN's 256 entries are moved, and each must
    point at a block's start, or the write is refused. MCAL's extent is
    the larger of its own size and the header's (byte 40, which counts
    its head), as the W client's reader takes it. The W client's reader
    checks bytes 20, 28, 36, 44 and 116; 24 is W02a's; 32, 88, 96 and
    120 are from WoW's format as remembered, unchecked against a real
    tile here (no WoW install). To check on the owner's machine: a stock
    tile edited (a height, a hole, a painted chunk, a new texture), read
    back by the W client and shown by the stock client and Noggit.
12. **No, to both, here.** The tools stop at the map's tiles: making a
    tile needs the WDT's tile list written (MAIN), which waits on the
    W client's tile-list reader (W10a decision 2; being added on the
    custom-client side). Water (MH2O) is W10's "place liquids", a later
    sub-issue; until then raising ground under water leaves the water's
    depth bytes as they were.

## Implementation Notes

*(2026-11-05)*

- `src/editor/wowterrain.lua` (new): the tools (`raise`, `lower`,
  `smooth`, `flatten`, `paint`, `holes`, and `ground` to read the
  ground at a point); the shared grid of points (half cells, every copy
  of a point); normals by W02a's rule; the writer `tile_bytes`
  (patching heights, normals and holes in place; a painted chunk's MCLY
  and MCAL again, the sub-blocks after them moved; MTEX grown, MHDR and
  MCIN made to follow); `save`, `edited`, `snapshot`, `restore`;
  `attach` gives the editor `E:wow_edit`, `E:wow_stroke_begin`,
  `E:wow_stroke`, `E:wow_stroke_end` and `E:wow_save`.
- `src/editor/terrain.lua`: the strokes pass to the WoW map while one
  is picked; `hole` and `unhole` are terrain tools there.
- `src/editor/init.lua`: `hole` and `unhole` in the tool list; the WoW
  terrain tools attached to every opened map.
- `src/editor/save.lua`: saving a project writes its WoW layer's
  edited tiles first.
- **Tests:** `src/tests/test_wow_terrain_editor.lua` (new): 77 with the
  W client's reader library and StormLib, 3 and 1 skipped without the
  library. On a WoW map W02's converter makes (two tiles, a lake, a
  tree, a hut, two textures):
  - unedited, written again: byte for byte (with and without reading);
    a cut-off tile refused; saving with no edit writes nothing;
  - the tools' grid where the reader puts every chunk; W02's normals
    given back by the rule, within 1;
  - raise (amount at the middle, less by distance, none past the edge),
    lower undoing it, smooth bringing a spike down, flatten (to a height
    and to the ground), a raise on the tiles' shared edge moving both
    tiles' copies; written in place (only heights and normals differ),
    read back exactly, placements and water as they were, normals
    changed only near the edit;
  - holes cut (the bit the W client draws), across chunks, written in
    place, read back, filled;
  - paint: a new layer, falloff, half strength, the first texture
    uncovering, a new texture in the tile's list, four layers then a
    fifth refused and then taking an uncovered layer's place; written
    (the tile grown, MHDR and MCIN followed) and read back exactly, the
    low-quality map made;
  - a 4-bit map's chunks written and read back as 4-bit;
  - a chunk laid out as the original's (packed map, MCNR's padding
    outside its size): read, written unedited byte for byte, raised
    with its packed map kept, painted (written plain, the reader
    agreeing), and a header offset pointing inside the layers refused;
  - the editor's strokes on a stand-in editor: raise twice, undo, redo,
    paint a new texture (undone, redone), cut a hole, a WC3-only tool
    refused, saved and read back, undone after the save and saved again
    back to the map as made;
  - a project exported from Daow 4.4: `hole` and `unhole` are tools but
    not on its WC3 map, a stroke on its WoW map, `E:save()` writing the
    tile, validation saying it changed, the project opened again with
    the ground as edited.

  Unchanged: `test_wow_layer` 50 (34 and 2 skipped without the
  library), `test_mapfile` 36, `test_editor` 83,
  `test_editor_integration` 44, `test_wow_terrain` 161,
  `test_wow_placements` 89 (on this branch's base).

**Still open:** the W client showing an edited map through Test Map
and a stock tile edited (decision 11's check, the owner's machine); the
WDL made from the edited tiles (decision 7); water (decision 12); new
tiles (decision 12, after the WDT tile-list reader); the window's
brush cursor and its conversion to a WoW map's yards (W10's drawing
step).
