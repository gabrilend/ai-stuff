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
