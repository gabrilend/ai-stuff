# Issue 207f: Registry Tests

**Phase:** 2 - Data Model
**Type:** Test
**Priority:** Medium
**Dependencies:** 207a-207e (all registry sub-issues)
**Parent Issue:** 207-build-object-registry-system

---

## Current Behavior

Individual sub-issues (207a-207e) include basic unit tests, but comprehensive
integration testing and edge case coverage is incomplete.

---

## Intended Behavior

Comprehensive test suite for the entire registry system, covering all
functionality from 207a-207e plus edge cases and integration scenarios.

```
src/tests/
├── test_registry.lua        (core registry tests)
├── test_spatial.lua         (spatial index tests)
└── test_registry_integration.lua  (Map integration tests)
```

---

## Suggested Implementation Steps

1. **Create test_registry.lua**
   - Test ObjectRegistry.new()
   - Test all add_* methods
   - Test get_by_creation_id with various scenarios
   - Test get_by_name with various scenarios
   - Test counts tracking
   - Test get_units_for_player
   - Test get_heroes, get_buildings, get_waygates
   - Test each_* iteration methods
   - Test filter() with custom predicates

2. **Create test_spatial.lua**
   - Test SpatialIndex.new() with various cell sizes
   - Test insert at various positions
   - Test query_radius accuracy
   - Test query_rect accuracy
   - Test edge cases: origin, negative coords, large values
   - Test empty queries
   - Test overlapping cells

3. **Create test_registry_integration.lua**
   - Test enable_spatial_index
   - Test auto-indexing of new objects
   - Test get_objects_in_radius
   - Test get_objects_in_region
   - Test Map.load() populates registry
   - Test real map files
   - Test maps with various content combinations

4. **Edge cases to cover**
   - Empty registry operations
   - Duplicate creation IDs (same and different types)
   - Missing optional fields (no name, no position)
   - Very large numbers of objects
   - Negative coordinates
   - Zero-size regions
   - Objects exactly on cell boundaries

5. **Performance benchmarks (optional)**
   - Bulk insertion timing
   - Spatial query timing with various densities
   - Memory usage estimation

---

## Technical Notes

### Test Data Generation

Use helper functions to create test objects:
```lua
local function make_unit(id, x, y, player)
    return {
        id = id,
        position = { x = x, y = y },
        player = player,
        creation_number = math.random(1, 100000),
    }
end

local function make_doodad(id, x, y)
    return {
        id = id,
        position = { x = x, y = y, z = 0 },
        creation_number = math.random(1, 100000),
    }
end
```

### Test Organization

Use vimfold markers for test grouping:
```lua
-- {{{ Test: registry creation
-- {{{ Test: add and lookup
-- {{{ Test: spatial queries
```

### Real Map Testing

Reuse test maps from assets/ directory to verify real-world data loads
correctly into the registry.

---

## Related Documents

- issues/207a-207e (functionality being tested)
- issues/207-build-object-registry-system.md (parent)
- src/tests/ (existing test patterns)

---

## Acceptance Criteria

- [ ] test_registry.lua covers all core registry methods
- [ ] test_spatial.lua covers all spatial index methods
- [ ] test_registry_integration.lua covers Map integration
- [ ] Edge cases documented and tested
- [ ] Tests pass with synthetic data
- [ ] Tests pass with real map data
- [ ] All 207 acceptance criteria verified by tests
- [ ] Test output shows pass/fail counts
- [ ] Tests can be run standalone or via unified runner

---

## Notes

This is a dedicated test issue because the parent issue (207) lists extensive
testing requirements in its acceptance criteria. Having a separate issue
ensures testing gets proper attention and isn't rushed at the end.

Consider this issue complete only when running tests provides confidence
that the registry system is production-ready.
