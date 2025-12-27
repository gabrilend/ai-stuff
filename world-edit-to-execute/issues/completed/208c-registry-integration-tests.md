# Issue 208c: Registry Integration Tests

**Phase:** 2 - Data Model
**Type:** Test
**Priority:** Medium
**Dependencies:** 207, 208b
**Parent Issue:** 208-phase-2-integration-test

---

## Current Behavior

The ObjectRegistry system (207) has unit tests, but there's no test that
validates the full integration: loading a map, populating the registry,
and performing cross-reference validation.

---

## Intended Behavior

Test the complete registry workflow including:
- Populating registry from parsed/created objects
- Lookup operations (by creation ID, by name)
- Filtering operations (get_heroes, get_buildings, etc.)
- Spatial indexing and queries
- Cross-reference validation (waygates → regions, regions → sounds)

```lua
local function test_registry_integration()
    local ObjectRegistry = require("registry")
    local gameobjects = require("gameobjects")

    local registry = ObjectRegistry.new()

    -- Populate with test objects
    for i = 1, 100 do
        registry:add_doodad(gameobjects.Doodad.new({
            id = "LTlt",
            position = { x = i * 100, y = i * 100, z = 0 },
            creation_number = i,
            -- ... other fields
        }))
    end

    -- Test lookups
    assert(registry.counts.doodads == 100)
    assert(registry:get_by_creation_id(50) ~= nil)

    -- Test spatial queries
    registry:enable_spatial_index(512)
    local nearby = registry:get_objects_in_radius(5000, 5000, 1000)
    assert(#nearby > 0)
end
```

---

## Suggested Implementation Steps

1. **Test registry population**
   - Add objects of each type
   - Verify counts are correct
   - Verify indexes are built

2. **Test lookup operations**
   - get_by_creation_id for various IDs
   - get_by_name for named objects
   - get_region_by_id for waygate targets
   - Handle missing objects gracefully

3. **Test filtering operations**
   - get_units_for_player with various player IDs
   - get_heroes returns only hero units
   - get_buildings returns only buildings
   - get_waygates returns units with valid waygate_dest

4. **Test spatial indexing**
   - enable_spatial_index with various cell sizes
   - get_objects_in_radius accuracy
   - get_objects_in_region accuracy
   - Edge cases (objects on cell boundaries)

5. **Test cross-reference validation**
   ```lua
   -- Waygate → Region references
   local waygates = registry:get_waygates()
   for _, waygate in ipairs(waygates) do
       if waygate.waygate_dest >= 0 then
           local dest = registry:get_region_by_id(waygate.waygate_dest)
           assert(dest ~= nil, "Waygate destination not found")
       end
   end

   -- Region → Sound references
   for _, region in ipairs(registry.regions) do
       if region.ambient_sound then
           local sound = registry:get_sound_by_name(region.ambient_sound)
           -- Sound may be external, just log if missing
       end
   end
   ```

6. **Test with real map data**
   - Load Map using Map.load()
   - Verify registry is populated
   - Run cross-reference checks on real data

---

## Acceptance Criteria

- [x] Registry populates correctly with all object types
- [x] Lookup by creation ID works
- [x] Lookup by name works for named objects
- [x] Filter methods return correct subsets
- [x] Spatial index builds and queries work
- [x] Radius queries return objects within range
- [x] Region queries return objects in bounds
- [x] Waygate → Region cross-references validate
- [x] Tests pass on real map data

---

## Notes

This is the core integration test for Phase 2. It validates that all the
pieces (parsers → objects → registry) work together correctly. The cross-
reference validation is particularly important for runtime correctness.

---

## Implementation Notes

*Completed 2025-12-27*

Created `src/tests/test_208c_registry_integration.lua` with comprehensive tests:

**Test Coverage:**
1. **Registry Population** - Creation, add_* methods, counts tracking
2. **Lookup Operations** - get_by_creation_id, get_by_name, missing lookups
3. **Filtering** - get_units_for_player, get_heroes, get_buildings, get_waygates
4. **Custom Filtering** - filter() with predicates, iteration methods (each_*)
5. **Spatial Indexing** - enable_spatial_index, has_spatial_index
6. **Spatial Queries** - get_objects_in_radius, get_objects_in_rect, get_objects_in_region
7. **Cross-References** - Waygate→Region validation, Region→Sound validation
8. **Real Map Integration** - Map.load(), player distribution, spatial queries

**Key Findings:**
- Same `is_building()` heuristic issue as 208b (tests updated to use "hpea")
- Test map validates waygate→region cross-reference (1 waygate, 1 valid ref)
- Spatial queries work correctly (167 objects found within 2000 units of reference)

**Test Statistics:**
- 69 assertions
- All tests pass with LuaJIT

**Run with:** `luajit src/tests/test_208c_registry_integration.lua`
