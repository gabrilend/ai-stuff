-- Game Objects Module Tests
-- Tests the gameobjects module structure and basic functionality.
-- Part of issue 206a - validates module loads and exports are correct.

-- {{{ Test setup
-- Get project root directory
local DIR = debug.getinfo(1, "S").source:match("@(.*/)") or "./"
DIR = DIR:match("(.-)/src/tests/$") or DIR:match("(.-)/src/tests/") or "."
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local tests_run = 0
local tests_passed = 0

local function assert_true(condition, message)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
    else
        print("  FAILED: " .. (message or "assertion failed"))
    end
end

local function assert_eq(actual, expected, message)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
    else
        print(string.format("  FAILED: %s (expected %s, got %s)",
            message or "equality", tostring(expected), tostring(actual)))
    end
end

local function assert_not_nil(value, message)
    tests_run = tests_run + 1
    if value ~= nil then
        tests_passed = tests_passed + 1
    else
        print("  FAILED: " .. (message or "value is nil"))
    end
end
-- }}}

-- {{{ Test: module loads
print("Test: gameobjects module loads")
local ok, gameobjects = pcall(require, "gameobjects")
assert_true(ok, "module should load without error: " .. tostring(gameobjects))
if ok then
    print("  PASSED")
else
    print("  FAILED: " .. tostring(gameobjects))
    os.exit(1)
end
-- }}}

-- {{{ Test: module exports all classes
print("Test: module exports all classes")
assert_not_nil(gameobjects.Doodad, "should export Doodad")
assert_not_nil(gameobjects.Unit, "should export Unit")
assert_not_nil(gameobjects.Region, "should export Region")
assert_not_nil(gameobjects.Camera, "should export Camera")
assert_not_nil(gameobjects.Sound, "should export Sound")
print("  PASSED")
-- }}}

-- {{{ Test: Doodad class structure
print("Test: Doodad class structure")
local Doodad = gameobjects.Doodad
assert_not_nil(Doodad.new, "Doodad should have new()")
local doodad = Doodad.new({
    id = "LTlt",
    position = { x = 100, y = 200, z = 0 },
    creation_number = 1,
})
assert_eq(doodad.id, "LTlt", "doodad.id")
assert_not_nil(doodad.is_visible, "doodad should have is_visible()")
assert_not_nil(doodad.is_solid, "doodad should have is_solid()")
assert_not_nil(doodad.get_max_life, "doodad should have get_max_life()")
print("  PASSED")
-- }}}

-- {{{ Test: Unit class structure
print("Test: Unit class structure")
local Unit = gameobjects.Unit
assert_not_nil(Unit.new, "Unit should have new()")
local unit = Unit.new({
    id = "hfoo",
    position = { x = 100, y = 200, z = 0 },
    player = 0,
    creation_number = 2,
})
assert_eq(unit.id, "hfoo", "unit.id")
assert_not_nil(unit.is_hero, "unit should have is_hero()")
assert_not_nil(unit.is_building, "unit should have is_building()")
assert_not_nil(unit.is_waygate, "unit should have is_waygate()")
print("  PASSED")
-- }}}

-- {{{ Test: Region class structure
print("Test: Region class structure")
local Region = gameobjects.Region
assert_not_nil(Region.new, "Region should have new()")
local region = Region.new({
    name = "test_region",
    creation_number = 0,
    bounds = { left = -100, bottom = -100, right = 100, top = 100 },
})
assert_eq(region.name, "test_region", "region.name")
assert_not_nil(region.get_center, "region should have get_center()")
assert_not_nil(region.contains_point, "region should have contains_point()")
print("  PASSED")
-- }}}

-- {{{ Test: Camera class structure
print("Test: Camera class structure")
local Camera = gameobjects.Camera
assert_not_nil(Camera.new, "Camera should have new()")
local camera = Camera.new({
    name = "test_camera",
    target = { x = 0, y = 0, z = 0 },
    distance = 1650,
    fov = 70,
})
assert_eq(camera.name, "test_camera", "camera.name")
assert_not_nil(camera.get_eye_position, "camera should have get_eye_position()")
assert_not_nil(camera.has_local_rotations, "camera should have has_local_rotations()")
print("  PASSED")
-- }}}

-- {{{ Test: Sound class structure
print("Test: Sound class structure")
local Sound = gameobjects.Sound
assert_not_nil(Sound.new, "Sound should have new()")
local sound = Sound.new({
    name = "test_sound",
    file = "Sound\\test.wav",
    volume = 80,
    flags = 3,  -- looping + 3D
})
assert_eq(sound.name, "test_sound", "sound.name")
assert_not_nil(sound.is_looping, "sound should have is_looping()")
assert_not_nil(sound.is_3d, "sound should have is_3d()")
assert_not_nil(sound.get_effective_volume, "sound should have get_effective_volume()")
print("  PASSED")
-- }}}

-- {{{ Test: __tostring metamethods
print("Test: __tostring metamethods")
local doodad_str = tostring(doodad)
assert_true(doodad_str:find("Doodad"), "__tostring should contain 'Doodad'")
local unit_str = tostring(unit)
assert_true(unit_str:find("Unit"), "__tostring should contain 'Unit'")
local region_str = tostring(region)
assert_true(region_str:find("Region"), "__tostring should contain 'Region'")
local camera_str = tostring(camera)
assert_true(camera_str:find("Camera"), "__tostring should contain 'Camera'")
local sound_str = tostring(sound)
assert_true(sound_str:find("Sound"), "__tostring should contain 'Sound'")
print("  PASSED")
-- }}}

-- {{{ Summary
print("")
print("========================================")
print(string.format("Tests passed: %d / %d", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests PASSED!")
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}
