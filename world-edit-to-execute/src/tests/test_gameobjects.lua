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

-- ============================================================================
-- 206b: Doodad Class Detailed Tests
-- ============================================================================

-- {{{ Test: Doodad constructor copies all fields
print("Test: Doodad constructor copies all fields")
do
    local d = Doodad.new({
        id = "LTlt",
        name = "Lordaeron Summer Tree",
        variation = 3,
        position = { x = 100, y = 200, z = 50 },
        angle = 1.57,
        scale = { x = 1.5, y = 1.5, z = 2.0 },
        flags = 2,
        life = 75,
        creation_number = 42,
        item_table_pointer = 5,
        item_sets_count = 2,
    })
    assert_eq(d.id, "LTlt", "id")
    assert_eq(d.name, "Lordaeron Summer Tree", "name")
    assert_eq(d.variation, 3, "variation")
    assert_eq(d.position.x, 100, "position.x")
    assert_eq(d.position.y, 200, "position.y")
    assert_eq(d.position.z, 50, "position.z")
    assert_eq(d.angle, 1.57, "angle")
    assert_eq(d.scale.x, 1.5, "scale.x")
    assert_eq(d.scale.y, 1.5, "scale.y")
    assert_eq(d.scale.z, 2.0, "scale.z")
    assert_eq(d.flags, 2, "flags")
    assert_eq(d.life, 75, "life")
    assert_eq(d.creation_number, 42, "creation_number")
    assert_eq(d.item_table_pointer, 5, "item_table_pointer")
    assert_eq(d.item_sets_count, 2, "item_sets_count")
end
print("  PASSED")
-- }}}

-- {{{ Test: Doodad default values
print("Test: Doodad default values when fields missing")
do
    local d = Doodad.new({ id = "test" })
    assert_eq(d.variation, 0, "default variation")
    assert_eq(d.position.x, 0, "default position.x")
    assert_eq(d.position.y, 0, "default position.y")
    assert_eq(d.position.z, 0, "default position.z")
    assert_eq(d.angle, 0, "default angle")
    assert_eq(d.scale.x, 1, "default scale.x")
    assert_eq(d.scale.y, 1, "default scale.y")
    assert_eq(d.scale.z, 1, "default scale.z")
    assert_eq(d.flags, 2, "default flags (normal)")
    assert_eq(d.life, 100, "default life")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_visible with different flags
print("Test: is_visible() with different flags")
do
    local invisible = Doodad.new({ id = "test", flags = 0 })
    local visible_nonsolid = Doodad.new({ id = "test", flags = 1 })
    local normal = Doodad.new({ id = "test", flags = 2 })

    assert_eq(invisible:is_visible(), false, "flags=0 should be invisible")
    assert_eq(visible_nonsolid:is_visible(), true, "flags=1 should be visible")
    assert_eq(normal:is_visible(), true, "flags=2 should be visible")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_solid with different flags
print("Test: is_solid() with different flags")
do
    local invisible = Doodad.new({ id = "test", flags = 0 })
    local visible_nonsolid = Doodad.new({ id = "test", flags = 1 })
    local normal = Doodad.new({ id = "test", flags = 2 })

    assert_eq(invisible:is_solid(), false, "flags=0 should be non-solid")
    assert_eq(visible_nonsolid:is_solid(), false, "flags=1 should be non-solid")
    assert_eq(normal:is_solid(), true, "flags=2 should be solid")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_max_life
print("Test: get_max_life() returns life value")
do
    local d1 = Doodad.new({ id = "test", life = 50 })
    local d2 = Doodad.new({ id = "test", life = 100 })
    local d3 = Doodad.new({ id = "test" })  -- default

    assert_eq(d1:get_max_life(), 50, "life=50")
    assert_eq(d2:get_max_life(), 100, "life=100")
    assert_eq(d3:get_max_life(), 100, "default life=100")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_item_drops
print("Test: has_item_drops() checks item_table_pointer")
do
    local no_drops = Doodad.new({ id = "test" })
    local no_pointer = Doodad.new({ id = "test", item_table_pointer = -1 })
    local has_drops = Doodad.new({ id = "test", item_table_pointer = 0 })
    local has_drops2 = Doodad.new({ id = "test", item_table_pointer = 5 })

    assert_eq(no_drops:has_item_drops(), false, "nil pointer = no drops")
    assert_eq(no_pointer:has_item_drops(), false, "-1 pointer = no drops")
    assert_eq(has_drops:has_item_drops(), true, "0 pointer = has drops")
    assert_eq(has_drops2:has_item_drops(), true, "5 pointer = has drops")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_angle_degrees
print("Test: get_angle_degrees() converts radians")
do
    local d1 = Doodad.new({ id = "test", angle = 0 })
    local d2 = Doodad.new({ id = "test", angle = math.pi })
    local d3 = Doodad.new({ id = "test", angle = math.pi / 2 })

    assert_eq(d1:get_angle_degrees(), 0, "0 rad = 0 deg")
    -- Use approximate comparison for floating point
    local deg180 = d2:get_angle_degrees()
    assert_true(deg180 > 179.9 and deg180 < 180.1, "pi rad = 180 deg")
    local deg90 = d3:get_angle_degrees()
    assert_true(deg90 > 89.9 and deg90 < 90.1, "pi/2 rad = 90 deg")
end
print("  PASSED")
-- }}}

-- {{{ Test: runtime state fields
print("Test: runtime state fields initialized")
do
    local d = Doodad.new({ id = "test" })
    assert_eq(d.current_life, nil, "current_life starts nil")
    assert_eq(d.destroyed, false, "destroyed starts false")
    assert_eq(d:get_current_life(), nil, "get_current_life() returns nil")
    assert_eq(d:is_destroyed(), false, "is_destroyed() returns false")
end
print("  PASSED")
-- }}}

-- {{{ Test: position table is copied
print("Test: position table is copied (no external mutation)")
do
    local pos = { x = 100, y = 200, z = 0 }
    local d = Doodad.new({ id = "test", position = pos })

    -- Modify original
    pos.x = 999

    -- Doodad should be unaffected
    assert_eq(d.position.x, 100, "position should be copied, not referenced")
end
print("  PASSED")
-- }}}

-- {{{ Test: __tostring shows visibility
print("Test: __tostring shows visibility state")
do
    local invisible = Doodad.new({ id = "LTlt", flags = 0, position = { x = 0, y = 0, z = 0 } })
    local nonsolid = Doodad.new({ id = "LTlt", flags = 1, position = { x = 0, y = 0, z = 0 } })
    local normal = Doodad.new({ id = "LTlt", flags = 2, position = { x = 0, y = 0, z = 0 } })

    local inv_str = tostring(invisible)
    local non_str = tostring(nonsolid)
    local norm_str = tostring(normal)

    assert_true(inv_str:find("invisible"), "invisible doodad shows [invisible]")
    assert_true(non_str:find("non%-solid"), "non-solid doodad shows [non-solid]")
    -- Normal doodad should NOT show visibility marker
    assert_true(not norm_str:find("invisible") and not norm_str:find("non%-solid"),
        "normal doodad has no visibility marker")
end
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

-- ============================================================================
-- 206d: Region Class Detailed Tests
-- ============================================================================

-- {{{ Test: Region constructor copies all fields
print("Test: Region constructor copies all fields")
do
    local r = Region.new({
        name = "spawn_area",
        creation_number = 42,
        bounds = { left = -512, bottom = -256, right = 512, top = 256 },
        weather_id = "RAhr",
        weather = "ashenvale_rain_heavy",
        ambient_sound = "rain_loop",
        color = { r = 255, g = 128, b = 64, a = 200 },
    })
    assert_eq(r.name, "spawn_area", "name")
    assert_eq(r.creation_number, 42, "creation_number")
    assert_eq(r.bounds.left, -512, "bounds.left")
    assert_eq(r.bounds.bottom, -256, "bounds.bottom")
    assert_eq(r.bounds.right, 512, "bounds.right")
    assert_eq(r.bounds.top, 256, "bounds.top")
    assert_eq(r.weather_id, "RAhr", "weather_id")
    assert_eq(r.weather, "ashenvale_rain_heavy", "weather")
    assert_eq(r.ambient_sound, "rain_loop", "ambient_sound")
    assert_eq(r.color.r, 255, "color.r")
    assert_eq(r.color.g, 128, "color.g")
    assert_eq(r.color.b, 64, "color.b")
    assert_eq(r.color.a, 200, "color.a")
end
print("  PASSED")
-- }}}

-- {{{ Test: Region default values
print("Test: Region default values when fields missing")
do
    local r = Region.new({ name = "minimal" })
    assert_eq(r.name, "minimal", "name")
    assert_eq(r.bounds.left, 0, "default bounds.left")
    assert_eq(r.bounds.bottom, 0, "default bounds.bottom")
    assert_eq(r.bounds.right, 0, "default bounds.right")
    assert_eq(r.bounds.top, 0, "default bounds.top")
    assert_eq(r.color.r, 255, "default color.r")
    assert_eq(r.color.g, 255, "default color.g")
    assert_eq(r.color.b, 255, "default color.b")
    assert_eq(r.color.a, 255, "default color.a")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_center
print("Test: get_center() calculates center point")
do
    local r = Region.new({
        bounds = { left = 0, bottom = 0, right = 100, top = 200 },
    })
    local center = r:get_center()
    assert_eq(center.x, 50, "center.x = (0+100)/2")
    assert_eq(center.y, 100, "center.y = (0+200)/2")

    -- Negative bounds
    local r2 = Region.new({
        bounds = { left = -100, bottom = -50, right = 100, top = 50 },
    })
    local center2 = r2:get_center()
    assert_eq(center2.x, 0, "center.x with negative bounds")
    assert_eq(center2.y, 0, "center.y with negative bounds")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_size
print("Test: get_size() calculates dimensions")
do
    local r = Region.new({
        bounds = { left = 0, bottom = 0, right = 100, top = 200 },
    })
    local size = r:get_size()
    assert_eq(size.width, 100, "width = 100-0")
    assert_eq(size.height, 200, "height = 200-0")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_area
print("Test: get_area() calculates area")
do
    local r = Region.new({
        bounds = { left = 0, bottom = 0, right = 100, top = 200 },
    })
    assert_eq(r:get_area(), 20000, "area = 100*200")

    local r2 = Region.new({
        bounds = { left = -50, bottom = -50, right = 50, top = 50 },
    })
    assert_eq(r2:get_area(), 10000, "area = 100*100")
end
print("  PASSED")
-- }}}

-- {{{ Test: contains_point
print("Test: contains_point() checks point in region")
do
    local r = Region.new({
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
    })

    -- Inside
    assert_eq(r:contains_point(50, 50), true, "center inside")
    assert_eq(r:contains_point(1, 1), true, "near corner inside")

    -- On edges (inclusive)
    assert_eq(r:contains_point(0, 50), true, "left edge")
    assert_eq(r:contains_point(100, 50), true, "right edge")
    assert_eq(r:contains_point(50, 0), true, "bottom edge")
    assert_eq(r:contains_point(50, 100), true, "top edge")
    assert_eq(r:contains_point(0, 0), true, "corner")

    -- Outside
    assert_eq(r:contains_point(-1, 50), false, "left of region")
    assert_eq(r:contains_point(101, 50), false, "right of region")
    assert_eq(r:contains_point(50, -1), false, "below region")
    assert_eq(r:contains_point(50, 101), false, "above region")
end
print("  PASSED")
-- }}}

-- {{{ Test: overlaps_region
print("Test: overlaps_region() checks region overlap")
do
    local r1 = Region.new({
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
    })
    local r2 = Region.new({
        bounds = { left = 50, bottom = 50, right = 150, top = 150 },
    })
    local r3 = Region.new({
        bounds = { left = 200, bottom = 0, right = 300, top = 100 },
    })
    local r4 = Region.new({
        bounds = { left = 0, bottom = 200, right = 100, top = 300 },
    })

    assert_eq(r1:overlaps_region(r2), true, "overlapping regions")
    assert_eq(r2:overlaps_region(r1), true, "overlap is symmetric")
    assert_eq(r1:overlaps_region(r3), false, "non-overlapping (right)")
    assert_eq(r1:overlaps_region(r4), false, "non-overlapping (above)")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_weather
print("Test: has_weather() checks weather presence")
do
    local with_weather = Region.new({
        weather_id = "RAhr",
    })
    local no_weather = Region.new({})
    local empty_weather = Region.new({ weather_id = "" })

    assert_eq(with_weather:has_weather(), true, "has weather")
    assert_eq(no_weather:has_weather(), false, "no weather (nil)")
    assert_eq(empty_weather:has_weather(), false, "no weather (empty)")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_ambient_sound
print("Test: has_ambient_sound() checks sound presence")
do
    local with_sound = Region.new({
        ambient_sound = "rain_loop",
    })
    local no_sound = Region.new({})
    local empty_sound = Region.new({ ambient_sound = "" })

    assert_eq(with_sound:has_ambient_sound(), true, "has sound")
    assert_eq(no_sound:has_ambient_sound(), false, "no sound (nil)")
    assert_eq(empty_sound:has_ambient_sound(), false, "no sound (empty)")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_color
print("Test: get_color() returns RGB values")
do
    local r = Region.new({
        color = { r = 128, g = 64, b = 32, a = 200 },
    })
    local color = r:get_color()
    assert_eq(color.r, 128, "color.r")
    assert_eq(color.g, 64, "color.g")
    assert_eq(color.b, 32, "color.b")
    -- get_color should NOT include alpha
    assert_eq(color.a, nil, "get_color has no alpha")

    local rgba = r:get_color_rgba()
    assert_eq(rgba.a, 200, "get_color_rgba has alpha")
end
print("  PASSED")
-- }}}

-- {{{ Test: bounds table is copied
print("Test: bounds table is copied (no external mutation)")
do
    local bounds = { left = 0, bottom = 0, right = 100, top = 100 }
    local r = Region.new({ bounds = bounds })

    -- Modify original
    bounds.left = 999

    -- Region should be unaffected
    assert_eq(r.bounds.left, 0, "bounds should be copied")
end
print("  PASSED")
-- }}}

-- {{{ Test: __tostring shows features
print("Test: __tostring shows weather/sound indicators")
do
    local plain = Region.new({
        name = "plain",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
    })
    local with_weather = Region.new({
        name = "rainy",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
        weather_id = "RAhr",
    })
    local with_sound = Region.new({
        name = "noisy",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
        ambient_sound = "loop",
    })
    local with_both = Region.new({
        name = "full",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
        weather_id = "RAhr",
        ambient_sound = "loop",
    })

    local plain_str = tostring(plain)
    local weather_str = tostring(with_weather)
    local sound_str = tostring(with_sound)
    local both_str = tostring(with_both)

    assert_true(not plain_str:find("%["), "plain region has no indicators")
    assert_true(weather_str:find("weather"), "weather region shows [weather]")
    assert_true(sound_str:find("sound"), "sound region shows [sound]")
    assert_true(both_str:find("weather") and both_str:find("sound"),
        "both region shows [weather+sound]")
end
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
