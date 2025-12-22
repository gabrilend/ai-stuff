# Issue 207d: Spatial Integration

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 207a-core-registry-class, 207c-spatial-index
**Parent Issue:** 207-build-object-registry-system

---

## Current Behavior

After 207a and 207c, we have a registry and a standalone spatial index,
but they're not connected. Registry has no spatial query capability.

---

## Intended Behavior

Integrate SpatialIndex with ObjectRegistry, providing convenient spatial
query methods and automatic indexing of positioned objects.

```lua
-- Enable spatial indexing (optional, for performance)
registry:enable_spatial_index(512)  -- cell size

-- Spatial queries
local nearby = registry:get_objects_in_radius(1000, 1000, 500)
local in_region = registry:get_objects_in_region(some_region)

-- New objects automatically indexed when spatial is enabled
registry:add_unit(new_unit)  -- auto-inserted into spatial index
```

---

## Suggested Implementation Steps

1. **Add spatial field to ObjectRegistry**
   - Add `spatial = nil` to constructor
   - Spatial index is optional (not created by default)

2. **Implement enable_spatial_index(cell_size)**
   ```lua
   function ObjectRegistry:enable_spatial_index(cell_size)
       local SpatialIndex = require("registry.spatial")
       self.spatial = SpatialIndex.new(cell_size)

       -- Index existing positioned objects
       for _, doodad in ipairs(self.doodads) do
           self.spatial:insert(doodad)
       end
       for _, unit in ipairs(self.units) do
           self.spatial:insert(unit)
       end
   end
   ```

3. **Update add_doodad and add_unit to auto-insert**
   ```lua
   function ObjectRegistry:add_doodad(doodad)
       -- ... existing code ...
       if self.spatial then
           self.spatial:insert(doodad)
       end
   end
   ```

4. **Implement get_objects_in_radius(x, y, radius)**
   - Check spatial index is enabled
   - Delegate to spatial:query_radius()
   - Return combined doodads and units

5. **Implement get_objects_in_region(region)**
   - Extract bounds from region object
   - Delegate to spatial:query_rect()

6. **Add convenience methods**
   - get_units_in_radius(x, y, radius) - filter for units only
   - get_doodads_in_radius(x, y, radius) - filter for doodads only

7. **Add tests for integration**

---

## Technical Notes

### Why Optional

Spatial indexing is optional because:
- Not all use cases need spatial queries
- There's a memory overhead (~8 bytes per object)
- Some maps have few objects and don't benefit

### Region Bounds

Regions from w3r have bounds: left, bottom, right, top. These map directly
to query_rect parameters.

### Object Types in Spatial Queries

Only doodads and units are spatially indexed because:
- They have positions
- They're the most numerous
- Regions, cameras, sounds are looked up by name/ID instead

---

## Related Documents

- issues/207a-core-registry-class.md (registry to integrate with)
- issues/207c-spatial-index.md (spatial index to integrate)
- issues/207-build-object-registry-system.md (parent)

---

## Acceptance Criteria

- [ ] enable_spatial_index creates and populates spatial index
- [ ] Existing doodads indexed when spatial enabled
- [ ] Existing units indexed when spatial enabled
- [ ] New doodads auto-indexed when added after enable
- [ ] New units auto-indexed when added after enable
- [ ] get_objects_in_radius returns correct objects
- [ ] get_objects_in_region returns correct objects
- [ ] Error thrown if spatial query called before enable
- [ ] get_units_in_radius filters correctly
- [ ] get_doodads_in_radius filters correctly
- [ ] Unit tests for integration

---

## Notes

The enable_spatial_index call should typically happen after loading all
objects but before runtime queries. This avoids the overhead of index
updates during bulk loading (though it's still correct if done earlier).
