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

- A unit, building, doodad or item whose model can't be found is drawn by
  the fallback (`has_model` says which).
- A key in the viewer and the editor turns forced wire-frame and the
  debug overlay on and off.
- A blank new map in the editor (911b) shows the fallback's grid.
- Regions and cameras in the editor (904b) can be shown the fallback way.

## Suggested Implementation Steps

1. Give the map viewer's scene a fallback, fed from its units and doodads.
2. A key for forced wire-frame and one for the overlay.
3. The editor's blank map and its region and camera layers.
4. Look at it on a screen.

## Acceptance Criteria

- [ ] A map with a missing model shows the wire-frame box in its place
- [ ] Forced wire-frame and the overlay toggle in the viewer and the editor
- [ ] A blank new map in the editor shows the grid
