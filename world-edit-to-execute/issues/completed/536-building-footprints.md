# Issue 536: Building Footprints

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 531 (construction)

---

## Current Behavior

- **Shapes:** where a building fits is a circle by its size class (64 to 192 units), a stand-in. Its pathing texture (upat) isn't read.
- **Ground checks:** the map's pathing map (war3map.wpm), which says where building is allowed, isn't read either. Placement samples the coarse 128-unit walk grid instead.
- **Snapping:** positions snap to 64 units whatever the building.

## Intended Behavior

- **Shape:** a building covers the cells of its pathing texture. Each pixel is a 32-unit cell, centred on the building, top row north. Red keeps walkers off, green fliers, blue builders.
- **Where the shape comes from:**
  1. the texture itself, through the map and the owner's install;
  2. else the texture's name ("8x8SimpleSolid"; "...Unbuildable" keeps builders off only);
  3. else a stand-in by size.
- **Snapping:** buildings snap so their texture lines up with the 32-unit cells.
- **Placing:** checked cell by cell.
  - **The pathing map:** no building on cells marked no-build or no-walk; water is refused as water.
  - **The ground:** one cliff level, not too steep.
  - **Other buildings:** clear of the cells they keep (no-build or no-walk).
- **The placement preview** shows each cell, green where it fits and red where it doesn't.

## Suggested Implementation Steps

1. `demo/wc3map/footprint.lua`: `parse_wpm`, `map_flags`, `shape`, `radius`, `snap`, `each`, `check`.
2. `construction.lua`: `g.placeable` and `g.snap(x, y, id)` through it; distances by the footprint's radius.
3. `main.lua`: hands the game the asset reader; draws the cells.
4. Tests.

## Acceptance Criteria

- [x] war3map.wpm read (DAoW: 1920 × 1920 cells; its water agrees with the terrain's at 92% of sampled points, 64% if flipped, so the rows run south to north)
- [x] Shapes from a texture's pixels, from its name, or a stand-in; DAoW's own path textures (238 of its unit types set one) give real sizes
- [x] Even footprints centre on cell corners, odd ones on cell middles
- [x] Refused on water, on no-build cells, and over another building's cells; side by side fits; the marks say which cells fail
- [x] Tests: test_footprint (25); test_construction, test_repair, test_shops, test_items, test_wc3_interface still pass

## Notes

- **Buildings don't block movement yet.** The route grid is 128 units a cell, and stamping 32-unit footprints into it is left for a later issue.
- **Not checked yet:** blight (undead buildings needing it, the upap field), and units standing in the way.
- **From memory, to check against the install:** the pixel colour meanings and the wpm flag bits (0x02 no walk, 0x04 no fly, 0x08 no build, 0x20 blight, 0x40 land). The DAoW flag counts are consistent with those bits.
