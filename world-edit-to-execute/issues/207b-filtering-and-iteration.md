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

- [ ] get_units_for_player returns correct units
- [ ] get_heroes returns only hero units
- [ ] get_buildings returns only building units
- [ ] get_waygates returns units with active waygate
- [ ] each_doodad iterates all doodads
- [ ] each_unit iterates all units
- [ ] each_region iterates all regions
- [ ] filter works with custom predicates
- [ ] Empty results return empty tables, not nil
- [ ] Unit tests for filtering methods

---

## Notes

These methods are essential for JASS/trigger compatibility. Many triggers
iterate "all units of player" or "all units in region" type queries.
