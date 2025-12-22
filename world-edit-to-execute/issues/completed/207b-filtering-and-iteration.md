# Issue 207b: Filtering and Iteration

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 207a-core-registry-class
**Parent Issue:** 207-build-object-registry-system

---

## Current Behavior

After 207a, the registry stores objects but provides only basic lookup by
creation_id or name. No way to query subsets of objects by type or property.

---

## Intended Behavior

Implement filter methods for querying subsets of objects and iteration helpers
for processing collections.

```lua
-- Player-specific queries
local red_units = registry:get_units_for_player(0)

-- Type-specific queries
local heroes = registry:get_heroes()
local buildings = registry:get_buildings()
local waygates = registry:get_waygates()

-- Iteration callbacks
registry:each_doodad(function(doodad)
    print(doodad.id)
end)

registry:each_unit(function(unit)
    if unit.hp > 100 then
        process(unit)
    end
end)

-- Generic filter with predicate
local damaged = registry:filter("unit", function(u)
    return u.hp < u.max_hp
end)
```

---

## Suggested Implementation Steps

1. **Implement player-specific queries**
   ```lua
   function ObjectRegistry:get_units_for_player(player_id)
       local result = {}
       for _, unit in ipairs(self.units) do
           if unit.player == player_id then
               table.insert(result, unit)
           end
       end
       return result
   end
   ```

2. **Implement type-specific queries**
   - get_heroes() - units where is_hero is true
   - get_buildings() - units where is_building is true (if tracked)
   - get_waygates() - units where waygate_dest >= 0

3. **Implement iteration callbacks**
   - each_doodad(callback)
   - each_unit(callback)
   - each_region(callback)
   - each_camera(callback)
   - each_sound(callback)

4. **Implement generic filter**
   ```lua
   function ObjectRegistry:filter(object_type, predicate)
       local collection = self[object_type .. "s"]
       if not collection then
           error("Unknown object type: " .. object_type)
       end

       local result = {}
       for _, obj in ipairs(collection) do
           if predicate(obj) then
               table.insert(result, obj)
           end
       end
       return result
   end
   ```

5. **Add tests for all filter methods**

---

## Technical Notes

### Performance

Filter methods iterate the entire collection. For frequently-used filters,
consider caching results or maintaining secondary indexes. However, for
initial implementation, simple iteration is sufficient.

### Building Detection

WC3 doesn't have a simple "is_building" flag. Detection requires checking
unit type against known building type IDs, or checking unit stats (e.g.,
buildings typically can't move). For now, rely on type ID prefixes or
maintain a list of building type IDs.

---

## Related Documents

- issues/207a-core-registry-class.md (dependency)
- issues/207-build-object-registry-system.md (parent)

---

## Acceptance Criteria

- [x] get_units_for_player returns correct units
- [x] get_heroes returns only hero units
- [x] get_buildings returns only building units
- [x] get_waygates returns units with active waygate
- [x] each_doodad iterates all doodads
- [x] each_unit iterates all units
- [x] each_region iterates all regions
- [x] filter works with custom predicates
- [x] Empty results return empty tables, not nil
- [x] Unit tests for filtering methods

---

## Notes

These methods are essential for JASS/trigger compatibility. Many triggers
iterate "all units of player" or "all units in region" type queries.

---

## Implementation Notes

*Completed 2025-12-22*

### Methods Added to ObjectRegistry

All filtering and iteration methods were added to `src/registry/init.lua`:

| Method | Description |
|--------|-------------|
| `get_units_for_player(player_id)` | Returns array of units owned by specified player |
| `get_heroes()` | Returns array of hero units (using is_hero method or ID pattern) |
| `get_buildings()` | Returns array of building units (requires is_building method) |
| `get_waygates()` | Returns array of waygate units (using is_waygate or waygate_dest) |
| `each_doodad(callback)` | Iterates all doodads |
| `each_unit(callback)` | Iterates all units |
| `each_region(callback)` | Iterates all regions |
| `each_camera(callback)` | Iterates all cameras |
| `each_sound(callback)` | Iterates all sounds |
| `filter(object_type, predicate)` | Generic filter with custom predicate |

### Design Decisions

1. **Hero detection dual-strategy:** `get_heroes()` first checks for an `is_hero()` method
   (for gameobject instances), then falls back to capital-first-letter ID pattern (for raw
   parser data). This allows the registry to work with both wrapped and unwrapped objects.

2. **Waygate detection dual-strategy:** Similar to heroes, checks for `is_waygate()` method
   first, then falls back to `waygate_dest >= 0` field check.

3. **Building detection method-only:** Since WC3 lacks a simple building flag and detection
   requires checking type IDs against known building types, `get_buildings()` only returns
   units with an `is_building()` method that returns true. Raw parser data without this
   method won't be detected.

4. **Index-based iteration:** All methods use numeric index iteration (`for i = 1, #arr`)
   rather than `ipairs` for slightly better performance.

### Tests Added

15 new tests added to `src/tests/test_registry.lua`:
- get_units_for_player (player filtering)
- get_heroes with is_hero method
- get_heroes fallback to ID pattern
- get_buildings
- get_waygates with method
- get_waygates with waygate_dest field
- each_doodad, each_unit, each_region, each_camera, each_sound
- filter with predicate
- filter returns empty table not nil
- filter errors on invalid type
- filter with complex predicate

Total tests: 71/71 passing
