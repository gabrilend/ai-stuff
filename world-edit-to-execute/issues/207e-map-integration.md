# Issue 207e: Map Integration

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** High
**Dependencies:** 207a-core-registry-class, 201-205 (parsers)
**Parent Issue:** 207-build-object-registry-system

---

## Current Behavior

The Map class from Phase 1 (src/data/init.lua) loads w3i, wts, and w3e data
but doesn't integrate with the object registry. Parsed doodads, units, regions,
cameras, and sounds from Phase 2 parsers aren't accessible through Map.

---

## Intended Behavior

Integrate ObjectRegistry with the Map class, automatically populating the
registry when a map is loaded.

```lua
local Map = require("data")

local map = Map.load("path/to/map.w3x")

-- Access registry through map
local all_units = map.registry.units
local hero = map.registry:get_heroes()[1]

-- Spatial queries (if enabled)
map.registry:enable_spatial_index()
local nearby = map.registry:get_objects_in_radius(1000, 1000, 500)

-- Existing Map API still works
print(map.info.name)
print(map.terrain:width())
```

---

## Suggested Implementation Steps

1. **Add registry field to Map**
   - In Map.new(), create ObjectRegistry instance
   - Make it accessible as map.registry

2. **Update Map.load() to populate registry**
   ```lua
   function Map.load(w3x_path)
       local map = Map.new()
       map.source_path = w3x_path
       map.registry = ObjectRegistry.new()

       local archive = mpq.open(w3x_path)

       -- Existing loading (w3i, wts, w3e)
       -- ...

       -- Load doodads (war3map.doo)
       if archive:has("war3map.doo") then
           local data = archive:extract("war3map.doo")
           local parsed = doo.parse(data)
           for _, d in ipairs(parsed.doodads) do
               map.registry:add_doodad(d)
           end
       end

       -- Load units (war3mapUnits.doo)
       if archive:has("war3mapUnits.doo") then
           local data = archive:extract("war3mapUnits.doo")
           local parsed = unitsdoo.parse(data)
           for _, u in ipairs(parsed.units) do
               map.registry:add_unit(u)
           end
       end

       -- Load regions (war3map.w3r)
       if archive:has("war3map.w3r") then
           local data = archive:extract("war3map.w3r")
           local parsed = w3r.parse(data)
           for _, r in ipairs(parsed.regions) do
               map.registry:add_region(r)
           end
       end

       -- Load cameras (war3map.w3c)
       if archive:has("war3map.w3c") then
           local data = archive:extract("war3map.w3c")
           local parsed = w3c.parse(data)
           for _, c in ipairs(parsed.cameras) do
               map.registry:add_camera(c)
           end
       end

       -- Load sounds (war3map.w3s)
       if archive:has("war3map.w3s") then
           local data = archive:extract("war3map.w3s")
           local parsed = w3s.parse(data)
           for _, s in ipairs(parsed.sounds) do
               map.registry:add_sound(s)
           end
       end

       archive:close()
       return map
   end
   ```

3. **Add requires for Phase 2 parsers**
   - doo (war3map.doo)
   - unitsdoo (war3mapUnits.doo)
   - w3r (war3map.w3r)
   - w3c (war3map.w3c)
   - w3s (war3map.w3s)

4. **Add Map methods for registry access**
   - map:get_unit(creation_id)
   - map:get_region(creation_id)
   - map:get_doodad(creation_id)
   - These delegate to registry:get_by_creation_id

5. **Update Map.format() to show registry stats**

6. **Add integration tests**
   - Load real map and verify registry populated
   - Verify counts match parser output
   - Verify lookups work

---

## Technical Notes

### Error Handling

If a parser fails, log a warning but continue loading other components.
Maps may be missing optional files (e.g., no cameras defined).

### Object Identity

The registry stores the same objects returned by parsers (by reference).
No conversion or wrapping is done at this stage. Issue 206 may define
wrapper classes, which would be integrated here.

### Lazy Loading Option

For very large maps, consider adding lazy loading support where the
registry is populated on-demand. However, for initial implementation,
eager loading is simpler and sufficient.

---

## Related Documents

- issues/207a-core-registry-class.md (registry being integrated)
- issues/106-design-internal-data-structures.md (Map class)
- issues/201-205 (Phase 2 parsers)
- issues/207-build-object-registry-system.md (parent)

---

## Acceptance Criteria

- [ ] Map.new() creates registry
- [ ] Map.load() populates registry with doodads
- [ ] Map.load() populates registry with units
- [ ] Map.load() populates registry with regions
- [ ] Map.load() populates registry with cameras
- [ ] Map.load() populates registry with sounds
- [ ] Missing files don't cause errors (graceful handling)
- [ ] map:get_unit(id) delegates to registry
- [ ] map:get_region(id) delegates to registry
- [ ] Map.format() shows registry counts
- [ ] Integration test with real map file

---

## Notes

This is the glue that brings Phase 1 (Map loading) and Phase 2 (object
parsing) together into a unified API. After this issue, callers can use
Map.load() to get complete map data including all game objects.
