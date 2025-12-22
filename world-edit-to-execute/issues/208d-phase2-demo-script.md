# Issue 208d: Phase 2 Demo Script

**Phase:** 2 - Data Model
**Type:** Demo
**Priority:** Low
**Dependencies:** 208a, 208b, 208c
**Parent Issue:** 208-phase-2-integration-test

---

## Current Behavior

No visual demonstration exists for Phase 2 capabilities. Progress is only
visible through test pass/fail output.

---

## Intended Behavior

Create a demo script that visually demonstrates Phase 2 capabilities:
- Map loading with all parsers
- Object statistics and breakdowns
- Spatial query demonstrations
- Formatted terminal output

The demo should run quickly and produce informative output that showcases
what Phase 2 has achieved.

---

## Suggested Implementation Steps

1. **Create demo script**
   ```
   issues/completed/demos/phase2_demo.lua
   ```

2. **Implement map loading section**
   ```lua
   print("========================================")
   print("  Phase 2: Data Model - Demo")
   print("========================================")

   local Map = require("data")
   local map = Map.load(TEST_MAP_PATH)

   print("Map: " .. map:get_display_name())
   print("Author: " .. map.author)
   ```

3. **Implement object statistics**
   ```lua
   print("Object Counts:")
   print(string.format("  Doodads:  %d", map.registry.counts.doodads))
   print(string.format("  Units:    %d", map.registry.counts.units))
   print(string.format("  Regions:  %d", map.registry.counts.regions))
   print(string.format("  Cameras:  %d", map.registry.counts.cameras))
   print(string.format("  Sounds:   %d", map.registry.counts.sounds))
   ```

4. **Implement unit breakdown**
   ```lua
   print("Unit Types:")
   local heroes = map.registry:get_heroes()
   local buildings = map.registry:get_buildings()
   local waygates = map.registry:get_waygates()
   print(string.format("  Heroes:    %d", #heroes))
   print(string.format("  Buildings: %d", #buildings))
   print(string.format("  Waygates:  %d", #waygates))
   ```

5. **Implement player breakdown**
   ```lua
   print("Units by Player:")
   for player_id = 0, 11 do
       local units = map.registry:get_units_for_player(player_id)
       if #units > 0 then
           print(string.format("  Player %d: %d units", player_id + 1, #units))
       end
   end
   ```

6. **Implement ambient regions display**
   ```lua
   print("Ambient Regions:")
   for _, region in ipairs(map.registry.regions) do
       if region:has_weather() or region:has_ambient_sound() then
           local effects = {}
           if region.weather then
               table.insert(effects, "weather:" .. region.weather)
           end
           if region.ambient_sound then
               table.insert(effects, "sound:" .. region.ambient_sound)
           end
           print(string.format("  %s: %s", region.name, table.concat(effects, ", ")))
       end
   end
   ```

7. **Implement spatial query demo**
   ```lua
   print("Spatial Query Demo:")
   map.registry:enable_spatial_index(512)
   local center = map.registry.doodads[1]
   if center then
       local nearby = map.registry:get_objects_in_radius(
           center.position.x, center.position.y, 1000)
       print(string.format("  Objects within 1000 units of (%.0f, %.0f): %d",
           center.position.x, center.position.y, #nearby))
   end
   ```

8. **Create bash runner script**
   ```bash
   #!/bin/bash
   # issues/completed/demos/run_phase2.sh
   DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
   cd "$DIR"

   echo "Running Phase 2 Integration Tests..."
   if luajit src/tests/test_phase2_integration.lua; then
       echo ""
       echo "Running Phase 2 Demo..."
       luajit issues/completed/demos/phase2_demo.lua
   else
       echo "Tests failed, skipping demo"
       exit 1
   fi
   ```

9. **Update run-demo.sh**
   - Add Phase 2 option to the interactive selector
   - Ensure it calls run_phase2.sh

---

## Acceptance Criteria

- [ ] Demo script created at issues/completed/demos/phase2_demo.lua
- [ ] Bash runner created at issues/completed/demos/run_phase2.sh
- [ ] Demo displays map name and author
- [ ] Demo displays object counts for all 5 types
- [ ] Demo displays unit type breakdown (heroes, buildings, waygates)
- [ ] Demo displays units by player
- [ ] Demo displays ambient regions with effects
- [ ] Demo shows spatial query results
- [ ] Demo runs in < 5 seconds
- [ ] run-demo.sh updated with Phase 2 option

---

## Notes

The demo serves as both validation and documentation. Future developers
can run the demo to quickly understand what Phase 2 provides. Consider
adding ASCII art or color output for visual appeal.

Optional enhancements:
- HTML report generation
- ASCII map visualization showing object placements
- Performance timing breakdown
