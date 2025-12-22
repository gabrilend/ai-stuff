#!/usr/bin/env luajit
-- src/tests/test_registry.lua
-- Unit tests for ObjectRegistry class
--
-- Run with: luajit -e "package.path = package.path .. ';src/?.lua;src/?/init.lua'" src/tests/test_registry.lua

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local ObjectRegistry = require("registry")

local tests_passed = 0
local tests_total = 0

-- {{{ Helper: assert_eq
local function assert_eq(actual, expected, msg)
    tests_total = tests_total + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s", msg or "assertion failed"))
        print(string.format("    expected: %s", tostring(expected)))
        print(string.format("    actual:   %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ Helper: assert_not_nil
local function assert_not_nil(actual, msg)
    tests_total = tests_total + 1
    if actual ~= nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected non-nil)", msg or "assertion failed"))
        return false
    end
end
-- }}}

-- {{{ Helper: assert_nil
local function assert_nil(actual, msg)
    tests_total = tests_total + 1
    if actual == nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected nil, got %s)", msg or "assertion failed", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ Test: new creates empty registry
print("Test: new creates empty registry")
do
    local registry = ObjectRegistry.new()

    assert_not_nil(registry, "registry should be created")
    assert_eq(registry.counts.doodads, 0, "doodads count should be 0")
    assert_eq(registry.counts.units, 0, "units count should be 0")
    assert_eq(registry.counts.regions, 0, "regions count should be 0")
    assert_eq(registry.counts.cameras, 0, "cameras count should be 0")
    assert_eq(registry.counts.sounds, 0, "sounds count should be 0")
    assert_eq(registry:get_total_count(), 0, "total count should be 0")
    assert_eq(#registry.doodads, 0, "doodads array should be empty")
    assert_eq(#registry.units, 0, "units array should be empty")
end
print("  PASSED")
-- }}}

-- {{{ Test: add_doodad
print("Test: add_doodad stores doodad and updates indexes")
do
    local registry = ObjectRegistry.new()
    local doodad = {
        type_id = "LTlt",
        creation_id = 100,
        position = { x = 10, y = 20, z = 0 },
    }

    registry:add_doodad(doodad)

    assert_eq(registry.counts.doodads, 1, "doodads count should be 1")
    assert_eq(#registry.doodads, 1, "doodads array should have 1 element")
    assert_eq(registry.doodads[1], doodad, "doodad should be stored")
    assert_eq(registry:get_by_creation_id(100), doodad, "lookup by creation_id should work")
end
print("  PASSED")
-- }}}

-- {{{ Test: add_unit
print("Test: add_unit stores unit and updates indexes")
do
    local registry = ObjectRegistry.new()
    local unit = {
        type_id = "hfoo",
        creation_id = 200,
        player = 0,
    }

    registry:add_unit(unit)

    assert_eq(registry.counts.units, 1, "units count should be 1")
    assert_eq(#registry.units, 1, "units array should have 1 element")
    assert_eq(registry.units[1], unit, "unit should be stored")
    assert_eq(registry:get_by_creation_id(200), unit, "lookup by creation_id should work")
end
print("  PASSED")
-- }}}

-- {{{ Test: add_region
print("Test: add_region stores region and updates indexes")
do
    local registry = ObjectRegistry.new()
    local region = {
        name = "spawn_area",
        creation_id = 300,
        bounds = { left = -100, right = 100, bottom = -100, top = 100 },
    }

    registry:add_region(region)

    assert_eq(registry.counts.regions, 1, "regions count should be 1")
    assert_eq(#registry.regions, 1, "regions array should have 1 element")
    assert_eq(registry.regions[1], region, "region should be stored")
    assert_eq(registry:get_by_creation_id(300), region, "lookup by creation_id should work")
    assert_eq(registry:get_by_name("spawn_area"), region, "lookup by name should work")
end
print("  PASSED")
-- }}}

-- {{{ Test: add_camera
print("Test: add_camera stores camera and updates indexes")
do
    local registry = ObjectRegistry.new()
    local camera = {
        name = "intro_cam",
        target = { x = 0, y = 0 },
        distance = 1650,
        fov = 70,
    }

    registry:add_camera(camera)

    assert_eq(registry.counts.cameras, 1, "cameras count should be 1")
    assert_eq(#registry.cameras, 1, "cameras array should have 1 element")
    assert_eq(registry.cameras[1], camera, "camera should be stored")
    assert_eq(registry:get_by_name("intro_cam"), camera, "lookup by name should work")
end
print("  PASSED")
-- }}}

-- {{{ Test: add_sound
print("Test: add_sound stores sound and updates indexes")
do
    local registry = ObjectRegistry.new()
    local sound = {
        name = "battle_music",
        file = "Sound/Music/battle.mp3",
        volume = 100,
    }

    registry:add_sound(sound)

    assert_eq(registry.counts.sounds, 1, "sounds count should be 1")
    assert_eq(#registry.sounds, 1, "sounds array should have 1 element")
    assert_eq(registry.sounds[1], sound, "sound should be stored")
    assert_eq(registry:get_by_name("battle_music"), sound, "lookup by name should work")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_by_creation_id returns nil for unknown id
print("Test: get_by_creation_id returns nil for unknown id")
do
    local registry = ObjectRegistry.new()

    assert_nil(registry:get_by_creation_id(9999), "should return nil for unknown id")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_by_name returns nil for unknown name
print("Test: get_by_name returns nil for unknown name")
do
    local registry = ObjectRegistry.new()

    assert_nil(registry:get_by_name("nonexistent"), "should return nil for unknown name")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_total_count
print("Test: get_total_count sums all types")
do
    local registry = ObjectRegistry.new()

    registry:add_doodad({ creation_id = 1 })
    registry:add_doodad({ creation_id = 2 })
    registry:add_unit({ creation_id = 3 })
    registry:add_region({ creation_id = 4, name = "r1" })
    registry:add_camera({ name = "c1" })
    registry:add_sound({ name = "s1" })

    assert_eq(registry.counts.doodads, 2, "doodads count should be 2")
    assert_eq(registry.counts.units, 1, "units count should be 1")
    assert_eq(registry.counts.regions, 1, "regions count should be 1")
    assert_eq(registry.counts.cameras, 1, "cameras count should be 1")
    assert_eq(registry.counts.sounds, 1, "sounds count should be 1")
    assert_eq(registry:get_total_count(), 6, "total count should be 6")
end
print("  PASSED")
-- }}}

-- {{{ Test: creation_number field works (parser output compatibility)
print("Test: creation_number field works (parser output compatibility)")
do
    local registry = ObjectRegistry.new()
    -- Parsers use creation_number, not creation_id
    local unit = {
        type_id = "hfoo",
        creation_number = 500,
    }

    registry:add_unit(unit)

    assert_eq(registry:get_by_creation_id(500), unit, "creation_number should be indexed as creation_id")
end
print("  PASSED")
-- }}}

-- {{{ Test: empty name not indexed
print("Test: empty name is not indexed")
do
    local registry = ObjectRegistry.new()
    local obj = {
        creation_id = 600,
        name = "",
    }

    registry:add_camera(obj)

    assert_nil(registry:get_by_name(""), "empty name should not be indexed")
end
print("  PASSED")
-- }}}

-- {{{ Test: creation_id collision (later wins)
print("Test: creation_id collision - later registration wins")
do
    local registry = ObjectRegistry.new()
    local doodad = { creation_id = 700, type_id = "LTlt" }
    local unit = { creation_id = 700, type_id = "hfoo" }

    registry:add_doodad(doodad)
    registry:add_unit(unit)

    -- Later registration wins
    assert_eq(registry:get_by_creation_id(700), unit, "later registration should win")
    -- But both are still in their respective arrays
    assert_eq(#registry.doodads, 1, "doodad still in array")
    assert_eq(#registry.units, 1, "unit still in array")
end
print("  PASSED")
-- }}}

-- {{{ Test: __tostring
print("Test: __tostring works")
do
    local registry = ObjectRegistry.new()
    registry:add_doodad({ creation_id = 1 })
    registry:add_unit({ creation_id = 2 })

    local str = tostring(registry)
    assert_not_nil(str:match("ObjectRegistry"), "__tostring should contain ObjectRegistry")
    assert_not_nil(str:match("doodads=1"), "__tostring should contain doodads count")
    assert_not_nil(str:match("units=1"), "__tostring should contain units count")
end
print("  PASSED")
-- }}}

-- {{{ Test: multiple objects can have same name (last wins)
print("Test: name collision - later registration wins")
do
    local registry = ObjectRegistry.new()
    local cam1 = { name = "cam" }
    local cam2 = { name = "cam" }

    registry:add_camera(cam1)
    registry:add_camera(cam2)

    assert_eq(registry:get_by_name("cam"), cam2, "later registration should win")
    assert_eq(#registry.cameras, 2, "both cameras still in array")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- 207b: Filtering and Iteration Tests
-- ============================================================================

-- {{{ Test: get_units_for_player
print("Test: get_units_for_player returns correct units")
do
    local registry = ObjectRegistry.new()
    registry:add_unit({ id = "hfoo", player = 0 })
    registry:add_unit({ id = "hkni", player = 0 })
    registry:add_unit({ id = "ogru", player = 1 })
    registry:add_unit({ id = "hpea", player = 2 })

    local p0_units = registry:get_units_for_player(0)
    local p1_units = registry:get_units_for_player(1)
    local p3_units = registry:get_units_for_player(3)

    assert_eq(#p0_units, 2, "player 0 should have 2 units")
    assert_eq(#p1_units, 1, "player 1 should have 1 unit")
    assert_eq(#p3_units, 0, "player 3 should have 0 units")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_heroes with is_hero method
print("Test: get_heroes returns only hero units (using is_hero method)")
do
    local registry = ObjectRegistry.new()
    -- Unit with is_hero method (gameobject pattern)
    local hero = { id = "Hpal", is_hero = function(self) return true end }
    local unit = { id = "hfoo", is_hero = function(self) return false end }

    registry:add_unit(hero)
    registry:add_unit(unit)

    local heroes = registry:get_heroes()
    assert_eq(#heroes, 1, "should return 1 hero")
    assert_eq(heroes[1], hero, "hero should be the returned unit")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_heroes fallback to ID pattern
print("Test: get_heroes uses ID pattern fallback for plain tables")
do
    local registry = ObjectRegistry.new()
    -- Plain tables without is_hero method (raw parser data)
    registry:add_unit({ id = "Hpal" })  -- Capital = hero
    registry:add_unit({ id = "Edem" })  -- Capital = hero
    registry:add_unit({ id = "hfoo" })  -- lowercase = unit
    registry:add_unit({ id = "ogru" })  -- lowercase = unit

    local heroes = registry:get_heroes()
    assert_eq(#heroes, 2, "should detect 2 heroes by ID pattern")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_buildings
print("Test: get_buildings returns only building units")
do
    local registry = ObjectRegistry.new()
    local building = { id = "htow", is_building = function(self) return true end }
    local unit = { id = "hfoo", is_building = function(self) return false end }
    local no_method = { id = "hpea" }  -- no is_building method

    registry:add_unit(building)
    registry:add_unit(unit)
    registry:add_unit(no_method)

    local buildings = registry:get_buildings()
    assert_eq(#buildings, 1, "should return 1 building")
    assert_eq(buildings[1], building, "building should be the returned unit")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_waygates with method
print("Test: get_waygates returns units with is_waygate() method")
do
    local registry = ObjectRegistry.new()
    local waygate = { id = "nwgt", is_waygate = function(self) return true end }
    local unit = { id = "hfoo", is_waygate = function(self) return false end }

    registry:add_unit(waygate)
    registry:add_unit(unit)

    local waygates = registry:get_waygates()
    assert_eq(#waygates, 1, "should return 1 waygate")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_waygates with waygate_dest field
print("Test: get_waygates detects waygate_dest field")
do
    local registry = ObjectRegistry.new()
    registry:add_unit({ id = "nwgt", waygate_dest = 5 })  -- active waygate
    registry:add_unit({ id = "nwg2", waygate_dest = 0 })  -- active (dest=0 is valid)
    registry:add_unit({ id = "nwg3", waygate_dest = -1 }) -- inactive
    registry:add_unit({ id = "hfoo" })  -- regular unit

    local waygates = registry:get_waygates()
    assert_eq(#waygates, 2, "should return 2 waygates (5 and 0 are valid)")
end
print("  PASSED")
-- }}}

-- {{{ Test: each_doodad
print("Test: each_doodad iterates all doodads")
do
    local registry = ObjectRegistry.new()
    registry:add_doodad({ id = "LTlt" })
    registry:add_doodad({ id = "LTex" })
    registry:add_doodad({ id = "NTtw" })

    local count = 0
    registry:each_doodad(function(d)
        count = count + 1
    end)

    assert_eq(count, 3, "should iterate 3 doodads")
end
print("  PASSED")
-- }}}

-- {{{ Test: each_unit
print("Test: each_unit iterates all units")
do
    local registry = ObjectRegistry.new()
    registry:add_unit({ id = "hfoo" })
    registry:add_unit({ id = "hkni" })

    local ids = {}
    registry:each_unit(function(u)
        ids[#ids + 1] = u.id
    end)

    assert_eq(#ids, 2, "should iterate 2 units")
    assert_eq(ids[1], "hfoo", "first unit should be hfoo")
    assert_eq(ids[2], "hkni", "second unit should be hkni")
end
print("  PASSED")
-- }}}

-- {{{ Test: each_region
print("Test: each_region iterates all regions")
do
    local registry = ObjectRegistry.new()
    registry:add_region({ name = "r1" })
    registry:add_region({ name = "r2" })

    local count = 0
    registry:each_region(function(r)
        count = count + 1
    end)

    assert_eq(count, 2, "should iterate 2 regions")
end
print("  PASSED")
-- }}}

-- {{{ Test: each_camera
print("Test: each_camera iterates all cameras")
do
    local registry = ObjectRegistry.new()
    registry:add_camera({ name = "cam1" })

    local count = 0
    registry:each_camera(function(c)
        count = count + 1
    end)

    assert_eq(count, 1, "should iterate 1 camera")
end
print("  PASSED")
-- }}}

-- {{{ Test: each_sound
print("Test: each_sound iterates all sounds")
do
    local registry = ObjectRegistry.new()
    registry:add_sound({ name = "snd1" })
    registry:add_sound({ name = "snd2" })
    registry:add_sound({ name = "snd3" })

    local count = 0
    registry:each_sound(function(s)
        count = count + 1
    end)

    assert_eq(count, 3, "should iterate 3 sounds")
end
print("  PASSED")
-- }}}

-- {{{ Test: filter with predicate
print("Test: filter with predicate returns matching objects")
do
    local registry = ObjectRegistry.new()
    registry:add_unit({ id = "hfoo", hp = 100 })
    registry:add_unit({ id = "hkni", hp = 50 })
    registry:add_unit({ id = "hpea", hp = 200 })
    registry:add_unit({ id = "ogru", hp = 80 })

    local high_hp = registry:filter("unit", function(u)
        return u.hp >= 100
    end)

    assert_eq(#high_hp, 2, "should return 2 units with hp >= 100")
end
print("  PASSED")
-- }}}

-- {{{ Test: filter empty results
print("Test: filter returns empty table, not nil")
do
    local registry = ObjectRegistry.new()
    registry:add_doodad({ id = "LTlt" })

    local result = registry:filter("doodad", function(d)
        return false  -- Match nothing
    end)

    assert_not_nil(result, "result should not be nil")
    assert_eq(#result, 0, "result should be empty table")
end
print("  PASSED")
-- }}}

-- {{{ Test: filter errors on invalid type
print("Test: filter errors on invalid object type")
do
    local registry = ObjectRegistry.new()

    local ok, err = pcall(function()
        registry:filter("invalid", function(x) return true end)
    end)

    assert_eq(ok, false, "should error on invalid type")
    assert_not_nil(err:match("Unknown object type"), "error should mention unknown type")
end
print("  PASSED")
-- }}}

-- {{{ Test: filter with complex predicate
print("Test: filter with complex predicate")
do
    local registry = ObjectRegistry.new()
    registry:add_region({ name = "spawn", bounds = { left = 0, right = 100, bottom = 0, top = 100 } })
    registry:add_region({ name = "big", bounds = { left = 0, right = 500, bottom = 0, top = 500 } })
    registry:add_region({ name = "tiny", bounds = { left = 0, right = 10, bottom = 0, top = 10 } })

    local large_regions = registry:filter("region", function(r)
        local w = r.bounds.right - r.bounds.left
        local h = r.bounds.top - r.bounds.bottom
        return w * h >= 10000  -- 100x100 or larger
    end)

    assert_eq(#large_regions, 2, "should return 2 large regions")
end
print("  PASSED")
-- }}}

-- {{{ Summary
print("")
print(string.format("========================================"))
print(string.format("Tests passed: %d / %d", tests_passed, tests_total))
if tests_passed == tests_total then
    print("All tests PASSED!")
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}
