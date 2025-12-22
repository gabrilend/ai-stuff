# Issue 208b: Game Object Creation Tests

**Phase:** 2 - Data Model
**Type:** Test
**Priority:** Medium
**Dependencies:** 206, 208a
**Parent Issue:** 208-phase-2-integration-test

---

## Current Behavior

Game object classes (Doodad, Unit, Region, Camera, Sound) from issue 206 have
individual tests, but there's no test that validates creating objects from
actual parsed data structures.

---

## Intended Behavior

Test that game objects can be instantiated from parser output and that their
methods work correctly. This validates the interface between parsers and
game object classes.

```lua
local function test_object_creation_from_parsed_data()
    local gameobjects = require("gameobjects")

    -- Create objects using structures matching parser output
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

    assert(doodad.id == "LTlt")
    assert(doodad:is_solid())
end
```

---

## Suggested Implementation Steps

1. **Test Doodad creation**
   - Create from parsed doodad structure
   - Test is_visible(), is_solid(), get_max_life()
   - Test with various flag combinations

2. **Test Unit creation**
   - Create from parsed unit structure
   - Test is_hero(), is_building(), is_item()
   - Test is_waygate() for units with waygate_dest >= 0
   - Test hero_data access for hero units

3. **Test Region creation**
   - Create from parsed region structure
   - Test get_center(), get_size()
   - Test contains_point() with various coordinates
   - Test has_weather(), has_ambient_sound()

4. **Test Camera creation**
   - Create from parsed camera structure
   - Test get_eye_position()
   - Test has_local_rotations()

5. **Test Sound creation**
   - Create from parsed sound structure
   - Test is_looping(), is_3d(), is_music()
   - Test get_effective_volume()

6. **Test with real parsed data**
   - Load a map, parse files, create objects
   - Validate objects match source data

---

## Acceptance Criteria

- [ ] Doodad objects created and methods work
- [ ] Unit objects created with all unit types (regular, hero, building)
- [ ] Region objects created with bounds validation
- [ ] Camera objects created with position data
- [ ] Sound objects created with audio properties
- [ ] Objects created from real parsed map data
- [ ] All object methods return expected values

---

## Notes

This test bridges parsers (Phase 1/2a outputs) and game objects (206). It
ensures the data structures are compatible and the object interfaces are
correct before testing the registry system.
