# Issue 531: Construction

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 527 (economy), 528 (limits), 521a (production), 523 (animation)

---

## Current Behavior

Workers have a Build menu listing their structures (ubui), but choosing
one says "not simulated". There is no placement, no construction,
nothing for the script's build orders (IssueBuildOrder) or construction
events, and UnitSetConstructionProgress is a no-op.

## Intended Behavior

Workers build as in WC3:

- **Placing:** pick a structure and place it where it fits: walkable, dry, level ground, clear of buildings. Requirements, limits and cost are checked.
- **Starting:** the worker walks there; on arrival the cost is paid and the structure appears.
- **Rising:** it rises over its build time, its hit points with it, the worker taking part in its race's way.
- **Cancel:** refunds most of the cost.
- **The script:** its build orders and construction events work.

## Suggested Implementation Steps

1. `demo/wc3map/construction.lua`: placement, can_build, build order, start, progress, race styles, cancel.
2. The game, production (no training while going up), natives, events.
3. HUD: placing with a footprint preview; Cancel on a rising building; Birth animation by progress.
4. Tests.

## Acceptance Criteria

- [x] Placement: inside the map, walkable, no water, one cliff level, not too steep, clear of buildings; positions snap to 64
- [x] can_build: in the worker's ubui list, requirements, tech and type limits, gold and lumber, placement
- [x] The worker walks to the site; on arrival the cost is paid, the structure appears at 10% hit points (building_up), CONSTRUCT_START fires with GetConstructingStructure
- [x] It rises over its build time (ubld), hit points with it; food made and training only once finished; CONSTRUCT_FINISH, the "built" score
- [x] Race styles by the builder's race (urac): human (works on it; it waits without its worker), orc (inside until done), undead (free at once), night elf (used up)
- [x] Cancel: 75% back, the structure gone, the worker free, CONSTRUCT_CANCEL with GetCancelledStructure
- [x] Natives: IssueBuildOrder / ById / ByIdLoc, UnitSetConstructionProgress
- [x] HUD: a structure from the Build menu enters placing, with a green / red footprint ring under the pointer; a rising building's card is Cancel; models play Birth held at their progress
- [x] `test_construction.lua`: 33 tests; related suites pass

## Implementation Notes

**Date:** 2026-09-30

- **`demo/wc3map/construction.lua`:**
  - `g.placeable(id, x, y)` samples the footprint every 64 units:
    - pathing (the pathing grid's walkable cells);
    - water;
    - the w3e cliff level (one level);
    - the height range (under 96);
    - other buildings' footprints.
  - Footprints are stand-ins by building size (small 96 … hall 192); the pathing textures (upat) aren't read yet.
  - `g.build(worker, id, x, y)` snaps the position, checks `g.can_build`, and sets the worker walking (order "build"). On arrival `construction.start` pays, spawns the structure (`building_up`, `progress`, `build_time`, 10% hit points) and applies the race style.
  - `construction.update` raises every rising building. A human-style building only while its worker is at it; other orders take the worker off it (`g.order` wrapper).
  - Finished buildings fire the made listener ("built": economy's score) and CONSTRUCT_FINISH.
  - `g.cancel_build` refunds 75%.
- **Game:**
  - `g.unit_spec(id)`, a type's design spec without making one.
  - `g.can_train` refuses buildings under construction.
  - Food made already skipped `building_up` buildings (issue 527).
- **Natives:**
  - Build orders by id (or the id as a four-character string).
  - `UnitSetConstructionProgress`, which was a no-op.
  - GetConstructingStructure and GetCancelledStructure.
- **HUD:**
  - A structure button places it (targeting "place"); clicking the ground orders the selected workers to build it there.
  - The map viewer rings the snapped footprint green where it fits, red where it doesn't.
  - A building going up shows only Cancel.
- **Animation:** a rising building plays Birth, held at the frame its progress reaches (`animate.lua`).

### Not yet

- **Footprints:** the real ones (pathing textures), and units standing in the way.
- **Building together:** several workers building one structure (power build) and resuming a paused one by right-clicking it.
- **Repair.**
- **Upgrades** (Town Hall to Keep: morphs in place).
- **Blight:** undead buildings need blight; night elf ancients uproot.
- **Computer players** don't build.
