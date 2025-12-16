# Issue 208: Phase 2 Integration Test

**Phase:** 2 - Data Model
**Type:** Test
**Priority:** Medium
**Dependencies:** 201, 202, 203, 204, 205, 206, 207

---

## Current Behavior

No integration test exists that validates all Phase 2 components working
together. Individual parsers and types are tested in isolation.

---

## Intended Behavior

A comprehensive integration test that:
- Loads a complete map using all Phase 2 parsers
- Creates game objects from parsed data
- Populates the object registry
- Validates cross-references (waygates to regions, sounds to regions)
- Produces a visual demo of Phase 2 capabilities

---

## Suggested Implementation Steps

1. **Create integration test script**
   ```
   src/tests/
   └── test_phase2_integration.lua
   ```

2. **Test parser integration**
   ```lua
   local function test_all_parsers()
       local mpq = require("mpq")
       local doo_parser = require("parsers.doo")
       local unitsdoo_parser = require("parsers.unitsdoo")
       local w3r_parser = require("parsers.w3r")
       local w3c_parser = require("parsers.w3c")
       local w3s_parser = require("parsers.w3s")

       local archive = mpq.open(TEST_MAP_PATH)

       -- Test each parser
       local doo = doo_parser.parse(archive:extract("war3map.doo"))
       assert(#doo.doodads > 0, "No doodads parsed")

       local units = unitsdoo_parser.parse(archive:extract("war3mapUnits.doo"))
       assert(#units.units > 0, "No units parsed")

       local regions = w3r_parser.parse(archive:extract("war3map.w3r"))
       -- Regions may be empty in some maps

       local cameras = w3c_parser.parse(archive:extract("war3map.w3c"))
       -- Cameras may be empty in some maps

       local sounds = w3s_parser.parse(archive:extract("war3map.w3s"))
       -- Sounds may be empty in some maps

       archive:close()

       return {
           doodads = #doo.doodads,
           units = #units.units,
           regions = #regions.regions,
           cameras = #cameras.cameras,
           sounds = #sounds.sounds,
       }
   end
   ```

3. **Test game object creation**
   ```lua
   local function test_object_creation()
       local gameobjects = require("gameobjects")

       -- Test Doodad
       local doodad = gameobjects.Doodad.new({
           id = "LTlt",
           variation = 0,
           position = { x = 100, y = 200, z = 0 },
           angle = 1.57,
           scale = { x = 1, y = 1, z = 1 },
           flags = 2,
           life = 100,
           creation_number = 1,
       })
       assert(doodad:is_solid(), "Doodad should be solid")

       -- Test Unit
       local unit = gameobjects.Unit.new({
           id = "hfoo",
           variation = 0,
           position = { x = 100, y = 200, z = 0 },
           angle = 0,
           scale = { x = 1, y = 1, z = 1 },
           player = 0,
           hp = -1,
           mp = -1,
           creation_number = 2,
       })
       assert(not unit:is_hero(), "Footman is not a hero")

       -- Test Region
       local region = gameobjects.Region.new({
           name = "test_region",
           creation_number = 0,
           bounds = { left = -100, bottom = -100, right = 100, top = 100 },
       })
       assert(region:contains_point(0, 0), "Region should contain origin")
       assert(not region:contains_point(200, 200), "Region should not contain (200,200)")

       return true
   end
   ```

4. **Test registry system**
   ```lua
   local function test_registry()
       local ObjectRegistry = require("registry")
       local gameobjects = require("gameobjects")

       local registry = ObjectRegistry.new()

       -- Add objects
       for i = 1, 100 do
           registry:add_doodad(gameobjects.Doodad.new({
               id = "LTlt",
               position = { x = i * 100, y = i * 100, z = 0 },
               creation_number = i,
               variation = 0,
               angle = 0,
               scale = { x = 1, y = 1, z = 1 },
               flags = 2,
               life = 100,
           }))
       end

       assert(registry.counts.doodads == 100, "Should have 100 doodads")

       -- Test lookup
       local found = registry:get_by_creation_id(50)
       assert(found ~= nil, "Should find doodad by creation ID")

       -- Test spatial queries
       registry:enable_spatial_index(512)
       local nearby = registry:get_objects_in_radius(5000, 5000, 1000)
       assert(#nearby > 0, "Should find nearby objects")

       return true
   end
   ```

5. **Test cross-references**
   ```lua
   local function test_cross_references()
       local mpq = require("mpq")
       local Map = require("data")

       local map = Map.load(TEST_MAP_PATH)

       -- Test waygate -> region references
       local waygates = map.registry:get_waygates()
       for _, waygate in ipairs(waygates) do
           local dest_region = map.registry:get_region_by_id(waygate.waygate_dest)
           if waygate.waygate_dest >= 0 then
               assert(dest_region ~= nil,
                   "Waygate destination region not found: " .. waygate.waygate_dest)
           end
       end

       -- Test region -> sound references
       for _, region in ipairs(map.registry.regions) do
           if region.ambient_sound then
               local sound = map.registry:get_sound_by_name(region.ambient_sound)
               -- Sound might be referenced but defined externally
           end
       end

       return true
   end
   ```

6. **Create phase demo script**
   ```lua
   -- issues/completed/demos/phase2_demo.lua

   local function run_demo()
       local mpq = require("mpq")
       local Map = require("data")

       print("========================================")
       print("  Phase 2: Data Model - Demo")
       print("========================================")
       print()

       -- Load map
       local map = Map.load(TEST_MAP_PATH)

       -- Report statistics
       print("Map: " .. map:get_display_name())
       print("Author: " .. map.author)
       print()

       print("Object Counts:")
       print(string.format("  Doodads:  %d", map.registry.counts.doodads))
       print(string.format("  Units:    %d", map.registry.counts.units))
       print(string.format("  Regions:  %d", map.registry.counts.regions))
       print(string.format("  Cameras:  %d", map.registry.counts.cameras))
       print(string.format("  Sounds:   %d", map.registry.counts.sounds))
       print()

       -- Show unit breakdown
       print("Unit Types:")
       local heroes = map.registry:get_heroes()
       local buildings = map.registry:get_buildings()
       local waygates = map.registry:get_waygates()
       print(string.format("  Heroes:    %d", #heroes))
       print(string.format("  Buildings: %d", #buildings))
       print(string.format("  Waygates:  %d", #waygates))
       print()

       -- Show player unit counts
       print("Units by Player:")
       for player_id = 0, 11 do
           local player_units = map.registry:get_units_for_player(player_id)
           if #player_units > 0 then
               print(string.format("  Player %d: %d units", player_id + 1, #player_units))
           end
       end
       print()

       -- Show regions with weather/sounds
       print("Ambient Regions:")
       for _, region in ipairs(map.registry.regions) do
           if region:has_weather() or region:has_ambient_sound() then
               local effects = {}
               if region.weather then table.insert(effects, "weather:" .. region.weather) end
               if region.ambient_sound then table.insert(effects, "sound:" .. region.ambient_sound) end
               print(string.format("  %s: %s", region.name, table.concat(effects, ", ")))
           end
       end
       print()

       -- Spatial query demo
       print("Spatial Query Demo:")
       map.registry:enable_spatial_index(512)
       local center = map.registry.doodads[1]
       if center then
           local nearby = map.registry:get_objects_in_radius(
               center.position.x, center.position.y, 1000)
           print(string.format("  Objects within 1000 units of (%.0f, %.0f): %d",
               center.position.x, center.position.y, #nearby))
       end

       print()
       print("========================================")
       print("  Phase 2 Demo Complete!")
       print("========================================")
   end

   run_demo()
   ```

7. **Create demo runner**
   ```bash
   #!/bin/bash
   # issues/completed/demos/run_phase2.sh
   cd "$(dirname "$0")/../../.."
   lua src/tests/test_phase2_integration.lua && lua issues/completed/demos/phase2_demo.lua
   ```

---

## Technical Notes

### Test Map Selection

Use the same test maps from Phase 1 (stored in assets/test_maps/).
Choose maps with diverse content:
- Multiple player setups
- Various unit types (heroes, buildings, waygates)
- Regions with weather and sounds
- Cameras for cinematics

### Error Handling

Tests should distinguish between:
- **Hard failures**: Parser crashes, missing required files
- **Soft failures**: Optional content missing (empty cameras, no sounds)

### Performance Metrics

Include timing for:
- Full map load time
- Spatial index construction
- Query response times

---

## Related Documents

- issues/108-phase-1-integration-test.md (similar structure)
- All Phase 2 issues (201-207)

---

## Acceptance Criteria

- [ ] All parsers load successfully on test maps
- [ ] Game objects created from all parser outputs
- [ ] Registry populated with all objects
- [ ] Cross-reference validation passes
- [ ] Spatial queries return correct results
- [ ] Demo script runs and produces output
- [ ] Performance acceptable (< 5s full load)
- [ ] Tests pass on all 16 test maps

---

## Notes

This integration test ensures Phase 2 components work together before
moving to Phase 3 (Logic Layer). The demo script provides visual
confirmation of progress and serves as documentation of Phase 2
capabilities.

Consider generating an HTML report or ASCII map visualization
showing object placements.
