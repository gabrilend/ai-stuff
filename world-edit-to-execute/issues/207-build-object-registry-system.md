# Issue 207: Build Object Registry System

**Phase:** 2 - Data Model
**Type:** Architecture
**Priority:** High
**Dependencies:** 206-design-game-object-types

---

## Current Behavior

No centralized system for storing and accessing game objects. Each parser
returns arrays of objects with no unified lookup mechanism.

---

## Intended Behavior

An object registry system that:
- Stores all game objects by type and ID
- Provides efficient lookup by creation ID
- Provides spatial queries for nearby objects
- Supports iteration by type or filter
- Integrates with the Map class from Phase 1

---

## Suggested Implementation Steps

1. **Create registry module**
   ```
   src/
   ├── gameobjects/     (from 206)
   └── registry/
       ├── init.lua     (ObjectRegistry class)
       └── spatial.lua  (spatial indexing)
   ```

2. **Implement ObjectRegistry class**
   ```lua
   -- src/registry/init.lua
   local ObjectRegistry = {}
   ObjectRegistry.__index = ObjectRegistry

   function ObjectRegistry.new()
       return setmetatable({
           -- By type
           doodads = {},
           units = {},
           regions = {},
           cameras = {},
           sounds = {},

           -- By creation ID (cross-type)
           by_creation_id = {},

           -- By name (for named objects)
           by_name = {},

           -- Spatial index (for doodads and units)
           spatial = nil,

           -- Statistics
           counts = {
               doodads = 0,
               units = 0,
               regions = 0,
               cameras = 0,
               sounds = 0,
           },
       }, ObjectRegistry)
   end
   ```

3. **Implement registration methods**
   ```lua
   function ObjectRegistry:add_doodad(doodad)
       table.insert(self.doodads, doodad)
       self.counts.doodads = self.counts.doodads + 1

       if doodad.creation_id then
           self.by_creation_id[doodad.creation_id] = doodad
       end

       if self.spatial then
           self.spatial:insert(doodad)
       end
   end

   function ObjectRegistry:add_unit(unit)
       table.insert(self.units, unit)
       self.counts.units = self.counts.units + 1

       if unit.creation_id then
           self.by_creation_id[unit.creation_id] = unit
       end

       if self.spatial then
           self.spatial:insert(unit)
       end
   end

   function ObjectRegistry:add_region(region)
       table.insert(self.regions, region)
       self.counts.regions = self.counts.regions + 1

       if region.creation_id then
           self.by_creation_id[region.creation_id] = region
       end

       if region.name then
           self.by_name[region.name] = region
       end
   end

   function ObjectRegistry:add_camera(camera)
       table.insert(self.cameras, camera)
       self.counts.cameras = self.counts.cameras + 1

       if camera.name then
           self.by_name[camera.name] = camera
       end
   end

   function ObjectRegistry:add_sound(sound)
       table.insert(self.sounds, sound)
       self.counts.sounds = self.counts.sounds + 1

       if sound.name then
           self.by_name[sound.name] = sound
       end
   end
   ```

4. **Implement lookup methods**
   ```lua
   function ObjectRegistry:get_by_creation_id(id)
       return self.by_creation_id[id]
   end

   function ObjectRegistry:get_by_name(name)
       return self.by_name[name]
   end

   function ObjectRegistry:get_region_by_id(id)
       for _, region in ipairs(self.regions) do
           if region.creation_id == id then
               return region
           end
       end
       return nil
   end

   function ObjectRegistry:get_sound_by_name(name)
       for _, sound in ipairs(self.sounds) do
           if sound.name == name then
               return sound
           end
       end
       return nil
   end

   function ObjectRegistry:get_camera_by_name(name)
       for _, camera in ipairs(self.cameras) do
           if camera.name == name then
               return camera
           end
       end
       return nil
   end
   ```

5. **Implement filtering methods**
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

   function ObjectRegistry:get_heroes()
       local result = {}
       for _, unit in ipairs(self.units) do
           if unit:is_hero() then
               table.insert(result, unit)
           end
       end
       return result
   end

   function ObjectRegistry:get_buildings()
       local result = {}
       for _, unit in ipairs(self.units) do
           if unit:is_building() then
               table.insert(result, unit)
           end
       end
       return result
   end

   function ObjectRegistry:get_waygates()
       local result = {}
       for _, unit in ipairs(self.units) do
           if unit:is_waygate() then
               table.insert(result, unit)
           end
       end
       return result
   end
   ```

6. **Implement spatial index**
   ```lua
   -- src/registry/spatial.lua
   local SpatialIndex = {}
   SpatialIndex.__index = SpatialIndex

   -- Simple grid-based spatial index
   function SpatialIndex.new(cell_size)
       return setmetatable({
           cell_size = cell_size or 512,  -- Default 512 game units
           cells = {},
       }, SpatialIndex)
   end

   function SpatialIndex:_cell_key(x, y)
       local cx = math.floor(x / self.cell_size)
       local cy = math.floor(y / self.cell_size)
       return cx .. "," .. cy
   end

   function SpatialIndex:insert(object)
       local key = self:_cell_key(object.position.x, object.position.y)
       if not self.cells[key] then
           self.cells[key] = {}
       end
       table.insert(self.cells[key], object)
   end

   function SpatialIndex:query_radius(x, y, radius)
       local result = {}
       local radius_sq = radius * radius

       -- Check cells that might contain objects in radius
       local min_cx = math.floor((x - radius) / self.cell_size)
       local max_cx = math.floor((x + radius) / self.cell_size)
       local min_cy = math.floor((y - radius) / self.cell_size)
       local max_cy = math.floor((y + radius) / self.cell_size)

       for cx = min_cx, max_cx do
           for cy = min_cy, max_cy do
               local key = cx .. "," .. cy
               local cell = self.cells[key]
               if cell then
                   for _, obj in ipairs(cell) do
                       local dx = obj.position.x - x
                       local dy = obj.position.y - y
                       if dx*dx + dy*dy <= radius_sq then
                           table.insert(result, obj)
                       end
                   end
               end
           end
       end

       return result
   end

   function SpatialIndex:query_rect(left, bottom, right, top)
       local result = {}

       local min_cx = math.floor(left / self.cell_size)
       local max_cx = math.floor(right / self.cell_size)
       local min_cy = math.floor(bottom / self.cell_size)
       local max_cy = math.floor(top / self.cell_size)

       for cx = min_cx, max_cx do
           for cy = min_cy, max_cy do
               local key = cx .. "," .. cy
               local cell = self.cells[key]
               if cell then
                   for _, obj in ipairs(cell) do
                       local px, py = obj.position.x, obj.position.y
                       if px >= left and px <= right and py >= bottom and py <= top then
                           table.insert(result, obj)
                       end
                   end
               end
           end
       end

       return result
   end

   return SpatialIndex
   ```

7. **Implement spatial query methods**
   ```lua
   function ObjectRegistry:enable_spatial_index(cell_size)
       local SpatialIndex = require("registry.spatial")
       self.spatial = SpatialIndex.new(cell_size)

       -- Index existing objects
       for _, doodad in ipairs(self.doodads) do
           self.spatial:insert(doodad)
       end
       for _, unit in ipairs(self.units) do
           self.spatial:insert(unit)
       end
   end

   function ObjectRegistry:get_objects_in_radius(x, y, radius)
       if not self.spatial then
           error("Spatial index not enabled. Call enable_spatial_index() first.")
       end
       return self.spatial:query_radius(x, y, radius)
   end

   function ObjectRegistry:get_objects_in_region(region)
       if not self.spatial then
           error("Spatial index not enabled. Call enable_spatial_index() first.")
       end
       return self.spatial:query_rect(
           region.bounds.left,
           region.bounds.bottom,
           region.bounds.right,
           region.bounds.top
       )
   end
   ```

8. **Implement iteration helpers**
   ```lua
   function ObjectRegistry:each_doodad(callback)
       for _, doodad in ipairs(self.doodads) do
           callback(doodad)
       end
   end

   function ObjectRegistry:each_unit(callback)
       for _, unit in ipairs(self.units) do
           callback(unit)
       end
   end

   function ObjectRegistry:each_region(callback)
       for _, region in ipairs(self.regions) do
           callback(region)
       end
   end

   -- Generic filter iteration
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

9. **Integration with Map class**
   ```lua
   -- Update src/data/init.lua to use registry
   local ObjectRegistry = require("registry")

   function Map.load(w3x_path)
       local map = Map.new()
       map.source_path = w3x_path
       map.registry = ObjectRegistry.new()

       local archive = mpq.open(w3x_path)

       -- ... existing loading code ...

       -- Load doodads
       local doo_data = archive:extract("war3map.doo")
       if doo_data then
           local parsed = doo_parser.parse(doo_data)
           for _, d in ipairs(parsed.doodads) do
               map.registry:add_doodad(Doodad.new(d))
           end
       end

       -- Load units
       local units_data = archive:extract("war3mapUnits.doo")
       if units_data then
           local parsed = unitsdoo_parser.parse(units_data)
           for _, u in ipairs(parsed.units) do
               map.registry:add_unit(Unit.new(u))
           end
       end

       -- Similar for regions, cameras, sounds...

       archive:close()
       return map
   end
   ```

---

## Technical Notes

### Creation ID Scope

Creation IDs are unique within their own file:
- Doodad creation IDs from war3map.doo
- Unit creation IDs from war3mapUnits.doo
- Region creation IDs from war3map.w3r

Waygates reference region creation IDs specifically.

### Spatial Index Performance

The grid-based spatial index is O(1) for insertion and O(k) for queries
where k is the number of objects in checked cells. For most maps this
is sufficient. More advanced structures (quadtree, R-tree) can be
added later if needed.

### Memory Considerations

Large maps may have thousands of doodads. The registry stores references,
not copies, so memory overhead is minimal. The spatial index adds
approximately 8 bytes per indexed object (pointer + cell overhead).

---

## Related Documents

- issues/206-design-game-object-types.md (object types stored in registry)
- issues/106-design-internal-data-structures.md (Map class integration)

---

## Acceptance Criteria

- [ ] ObjectRegistry stores all five object types
- [ ] Lookup by creation ID works correctly
- [ ] Lookup by name works for named objects
- [ ] Filter methods (get_heroes, get_buildings, etc.) work
- [ ] Spatial index optional but functional
- [ ] Radius queries return correct objects
- [ ] Rectangle queries return correct objects
- [ ] Integration with Map.load() works
- [ ] Unit tests for registry operations
- [ ] Unit tests for spatial queries

---

## Notes

The registry is the central access point for game objects during runtime.
JASS/Lua scripts will query the registry to find units, check regions,
play sounds, etc.

Consider adding events/callbacks for object addition/removal to support
future features like object lifecycle management.
