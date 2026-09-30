# Issue 541: Buildings Block Movement

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 519a (pathing), 536 (footprints)

---

## Current Behavior

Buildings only block placement: routes, chases and walks go straight through them. The route grid (one cell per 128-unit tilepoint) knows only the terrain: cliffs, deep water and the map's edge.

## Intended Behavior

- **Building cells:** each building's footprint cells that keep walkers out (pathing texture red, 32 units a cell) form a fine layer over the route grid. Buildings going up count; hidden, dead and removed ones don't.
- **Routes:**
  - a route cell half or more covered by building cells is closed, and regions are labelled again only when the set of closed cells changes;
  - so a base walled in with no gap is a region of its own, and an order to leave ends on its own side;
  - each leg of a route that crosses a building's cells is led round it by a fine search (A* in a window around the leg, then smoothed);
  - an order onto a building ends at its edge facing the walker.
- **Moving:**
  - units never step into a building's cells: they slide along the wall, else stop;
  - a unit making no headway for 1.5 s ends that walk;
  - a building put down where units stand pushes them to the nearest open ground.
- **Keeping up:** the layer is rebuilt at once when a building comes, goes, is hidden or shown, or changes type (`g.blockers_stale`). A signature of the standing buildings is also checked twice a second. Walks a new building cuts across are planned again.
- **Reach from the edge:** being beside a building (gold mines, halls taking resources, building and repairing, melee on buildings) is measured from its footprint's edge (`footprint.gap`), not its centre. A unit stopped at a big building's corner is beside it.

## Suggested Implementation Steps

1. `pathing.lua`: `set_blockers`, `blocked`, `fine_open`, `fine_clear`, `fine_detour`, `refine`, `free_spot`, `ground_walkable`; route ends at the facing edge; routes refined.
2. `game.lua`: `g.update_blockers`, the stale flag at the places buildings change, collision and stuck-ending in the movement step.
3. `footprint.lua`: `gap`, `gap_at`. `economy.lua`, `construction.lua`, `combat.lua`: reach from the edge.
4. Tests.

## Acceptance Criteria

- [x] A building's cells block and its route cells close; its body is half its side
- [x] Routes round a building never cross its cells; units get there and are never inside on the way
- [x] A move onto a building stops beside it and the order ends
- [x] Units under a new building step out
- [x] A ring of buildings: out and back through its gap; plugged, the inside is its own region and the unit stays in
- [x] Hidden and removed buildings don't block
- [x] A walk a new building cuts across is planned again, and arrives
- [x] Tests: test_building_blocks (21). Tests that walk across DAoW's own base get more time: test_economy (45 s for the mine trips), test_abilities (9 s to walk into range)

## Notes

- **Cost on DAoW (1,733 buildings):**
  - the first build of the layer takes 0.3 s, reading every shape once;
  - after that, a rebuild takes 20 ms when no route cell changes, and about 80 ms when regions have to be labelled again;
  - a minute of game with every computer player running costs about what it did before.
- **Units don't block one another**, as before.
- **Narrow gaps:** a gap narrower than a route cell passes only through the fine search inside a leg. A* on the route grid may close it when half or more of the cell is covered.
