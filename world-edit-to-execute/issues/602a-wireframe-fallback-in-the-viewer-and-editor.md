# Issue 602a: Wire-frame Fallback in the Map Viewer and the Editor

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 602 (wire-frame fallback)

---

## Current Behavior

`src/assets/fallback.lua` (602) builds wire-frame shapes and labels for
any object, region, camera and the terrain, and a demo scene shows them.
The map viewer (`src/demo/wc3map/`) and the editor still draw a unit
with no model as 503's placeholder shapes, and a new blank map shows the
plain ground.

## Intended Behavior

**The editor's part only (2026-11-04).** The owner settled that the editor
keeps this project's Lua renderer and that playing a map happens in the W
client, which Test Map opens (issue 913); the player's wire-frames are the
W client's (its 105a, step 4). So this project's map viewer
(`src/demo/wc3map/`), which gives way to Test Map, needs no wire-frames of
its own; the items below that name the viewer are kept as written, and
only the editor's are still wanted (602, "Where wire-frames are drawn").

- A unit, building, doodad or item whose model can't be found is drawn by
  the fallback (`has_model` says which).
- A key in the viewer and the editor turns forced wire-frame and the
  debug overlay on and off.
- A blank new map in the editor (911b) shows the fallback's grid.
- Regions and cameras in the editor (904b) can be shown the fallback way.

## Suggested Implementation Steps

1. ~~Give the map viewer's scene a fallback, fed from its units and doodads.~~ (unseen; taken out again 2026-11-04, see the notes)
2. ~~A key for forced wire-frame and one for the overlay.~~ F6 and F7 (unseen)
3. ~~The editor's blank map and its region and camera layers.~~ (unseen)
4. Look at it on a screen.

## Acceptance Criteria

- [ ] A map with a missing model shows the wire-frame box in its place
- [ ] Forced wire-frame and the overlay toggle in the viewer and the editor
- [ ] A blank new map in the editor shows the grid

## Progress Notes

### Steps 1 to 3 (2026-11-03), unseen

Built and tested without a window. The viewer and editor wiring is
compiled but has not been seen on a screen; step 4 is still to do.

- `src/assets/fallback_view.lua`: the viewer's units and doodads and the
  editor's objects, regions and cameras as fallback objects; the F6/F7
  keys; the overlay's labels; the grid from a w3e terrain; `is_blank`.
- `src/demo/wc3map/main.lua`: F6 draws every unit and doodad near the
  camera wire-frame (the baked doodads and buildings are taken off, and
  baked again when it is turned off); F7 labels them.
- `src/editor/main.lua`: the same, plus every region and camera in
  wire-frame, and the grid (group 50) on a blank new map or in wire-frame.
- `src/tests/test_fallback_view.lua`: 38 tests, one of them on a new map
  made and opened in the editor.

After the editor-and-client split (2026-11-04): the editor's half
(`src/editor/main.lua`) is what 602 now asks for. The viewer's half
(`src/demo/wc3map/main.lua`) was for a play mode that gives way to Test
Map (913, PR #239), and the player's wire-frames are the W client's (its
105a, step 4), so with the owner's yes it was taken out in a commit of
its own:

- **Removed:** the map viewer's F6 and F7 (`demo/wc3map/main.lua` is back
  as it was before this issue), and `fallback_view.lua`'s converters for
  the viewer's records, `fv.unit` and `fv.doodad`, which nothing else
  used. Their tests went with them (a footman, barracks, gryphon rider
  and paladin from the viewer's game, and three viewer doodads).
- **Kept:** the editor's wiring (F6/F7, regions and cameras, the
  blank-map grid) and everything of `fallback_view.lua` it uses
  (`editor_object`, `region`, `camera`, `terrain`, `is_blank`, `new` and
  `V`'s methods). The tests of the labels and of building a forced
  scene now use the editor's records (and the fallback's own objects for
  a building and a flyer, which an editor record doesn't mark), and two
  checks of `editor_object`'s doodads were added: 35 tests.

Decisions made while building:

1. **A unit with no model keeps its geometry design** (544) in the viewer
   and the editor. The design is already drawn from our own geometry for
   anything without a model, and it shows more than a box. The wire box
   is what F6 shows. So the first acceptance line is met under F6, not by
   default. If Ritz wants boxes by default, the change is a few lines.
2. **F6 and F7.** No existing key uses them (F5 tests the map in the
   editor; F8 to F12 are the HUD's).
3. **The overlay labels what is drawn for real too**, not only the
   fallback's boxes, through `V:labels`. Otherwise F7 alone would show
   nothing.
4. **Wire-frame takes the baked designs off** (every object block in the
   editor; until 2026-11-04 also the viewer's doodads and buildings)
   rather than drawing over them, and bakes them again when turned off.
5. **Blank means nothing placed.** A new map's gold mines are made by
   its script, so they don't count. Placing anything ends the grid, which
   F6 brings back.
6. **The grid is baked**, not drawn each frame, and thinned to at most
   20000 lines on a large map.
7. **A camera's eye** is placed from its distance, rotation, angle of
   attack and z offset, as WC3 places it. The fallback draws a line from
   the eye to what it looks at.

