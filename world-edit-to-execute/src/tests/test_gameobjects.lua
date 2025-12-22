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
    target = { x = 0, y = 0 },
    distance = 1650,
    fov = 70,
})
assert_eq(camera.name, "test_camera", "camera.name")
assert_not_nil(camera.get_eye_position, "camera should have get_eye_position()")
assert_not_nil(camera.has_local_rotations, "camera should have has_local_rotations()")
print("  PASSED")
-- }}}

-- ============================================================================
-- 206e: Camera Class Detailed Tests
-- ============================================================================

-- {{{ Test: Camera constructor copies all fields
print("Test: Camera constructor copies all fields")
do
    local c = Camera.new({
        name = "intro_cam",
        target = { x = 1000, y = 2000 },
        z_offset = 100,
        rotation = 45,
        aoa = 60,
        distance = 2000,
        roll = 5,
        fov = 90,
        far_clip = 6000,
        near_clip = 50,
        local_pitch = 10,
        local_yaw = 20,
        local_roll = 30,
    })
    assert_eq(c.name, "intro_cam", "name")
    assert_eq(c.target.x, 1000, "target.x")
    assert_eq(c.target.y, 2000, "target.y")
    assert_eq(c.z_offset, 100, "z_offset")
    assert_eq(c.rotation, 45, "rotation")
    assert_eq(c.aoa, 60, "aoa")
    assert_eq(c.distance, 2000, "distance")
    assert_eq(c.roll, 5, "roll")
    assert_eq(c.fov, 90, "fov")
    assert_eq(c.far_clip, 6000, "far_clip")
    assert_eq(c.near_clip, 50, "near_clip")
    assert_eq(c.local_pitch, 10, "local_pitch")
    assert_eq(c.local_yaw, 20, "local_yaw")
    assert_eq(c.local_roll, 30, "local_roll")
end
print("  PASSED")
-- }}}

-- {{{ Test: Camera default values
print("Test: Camera default values when fields missing")
do
    local c = Camera.new({ name = "test" })
    assert_eq(c.target.x, 0, "default target.x")
    assert_eq(c.target.y, 0, "default target.y")
    assert_eq(c.z_offset, 0, "default z_offset")
    assert_eq(c.rotation, 90, "default rotation")
    assert_eq(c.aoa, 304, "default aoa")
    assert_eq(c.distance, 1650, "default distance")
    assert_eq(c.roll, 0, "default roll")
    assert_eq(c.fov, 70, "default fov")
    assert_eq(c.far_clip, 5000, "default far_clip")
    assert_eq(c.near_clip, 100, "default near_clip")
    assert_eq(c.local_pitch, nil, "local_pitch should be nil by default")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_target_position
print("Test: get_target_position() returns correct values")
do
    local c = Camera.new({
        name = "test",
        target = { x = 500, y = 600 },
        z_offset = 150,
    })
    local pos = c:get_target_position()
    assert_eq(pos.x, 500, "target x")
    assert_eq(pos.y, 600, "target y")
    assert_eq(pos.z, 150, "target z = z_offset")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_eye_position with simple case (rotation=0, aoa=0)
print("Test: get_eye_position() rotation=0, aoa=0 (horizontal, facing north)")
do
    -- rotation=0 means North, aoa=0 means horizontal
    -- Camera should be at target - (0, distance, 0)
    local c = Camera.new({
        name = "test",
        target = { x = 0, y = 0 },
        z_offset = 0,
        rotation = 0,
        aoa = 0,
        distance = 1000,
    })
    local eye = c:get_eye_position()
    -- With rotation=0 (North), horizontal distance=1000, camera is South of target
    -- eye.x = 0 - 1000*sin(0) = 0
    -- eye.y = 0 - 1000*cos(0) = -1000
    -- eye.z = 0 + 1000*sin(0) = 0
    assert_true(math.abs(eye.x - 0) < 0.01, "eye.x should be 0")
    assert_true(math.abs(eye.y - (-1000)) < 0.01, "eye.y should be -1000")
    assert_true(math.abs(eye.z - 0) < 0.01, "eye.z should be 0")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_eye_position with rotation=90 (facing east)
print("Test: get_eye_position() rotation=90 (facing east)")
do
    local c = Camera.new({
        name = "test",
        target = { x = 0, y = 0 },
        z_offset = 0,
        rotation = 90,
        aoa = 0,
        distance = 1000,
    })
    local eye = c:get_eye_position()
    -- With rotation=90 (East), horizontal distance=1000, camera is West of target
    -- eye.x = 0 - 1000*sin(90) = -1000
    -- eye.y = 0 - 1000*cos(90) = 0
    assert_true(math.abs(eye.x - (-1000)) < 0.01, "eye.x should be -1000")
    assert_true(math.abs(eye.y - 0) < 0.01, "eye.y should be 0")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_eye_position with aoa=90 (looking straight down)
print("Test: get_eye_position() aoa=90 (looking straight down)")
do
    local c = Camera.new({
        name = "test",
        target = { x = 0, y = 0 },
        z_offset = 0,
        rotation = 0,
        aoa = 90,
        distance = 1000,
    })
    local eye = c:get_eye_position()
    -- With aoa=90, all distance goes vertical
    -- horizontal = 1000 * cos(90) = 0
    -- vertical = 1000 * sin(90) = 1000
    -- eye.x = 0 - 0*sin(0) = 0
    -- eye.y = 0 - 0*cos(0) = 0
    -- eye.z = 0 + 1000 = 1000
    assert_true(math.abs(eye.x - 0) < 0.01, "eye.x should be 0")
    assert_true(math.abs(eye.y - 0) < 0.01, "eye.y should be 0")
    assert_true(math.abs(eye.z - 1000) < 0.01, "eye.z should be 1000")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_eye_position with typical RTS angle
print("Test: get_eye_position() typical RTS setup")
do
    -- Default WC3 camera: distance=1650, aoa=304, rotation=90
    local c = Camera.new({
        name = "test",
        target = { x = 1000, y = 2000 },
        z_offset = 100,
        rotation = 90,
        aoa = 304,
        distance = 1650,
    })
    local eye = c:get_eye_position()
    -- Just verify it's a reasonable position (camera above ground, offset from target)
    assert_true(eye.z > 0 or eye.z < 0, "eye.z should exist")
    assert_true(eye.x ~= c.target.x or eye.y ~= c.target.y, "eye should be offset from target")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_fov_radians
print("Test: get_fov_radians() converts correctly")
do
    local c = Camera.new({ name = "test", fov = 90 })
    local fov_rad = c:get_fov_radians()
    -- 90 degrees = pi/2 radians = 1.5708...
    assert_true(math.abs(fov_rad - math.pi/2) < 0.0001, "90 deg = pi/2 rad")

    local c2 = Camera.new({ name = "test", fov = 70 })
    local fov70 = c2:get_fov_radians()
    assert_true(fov70 > 1.2 and fov70 < 1.25, "70 deg ~= 1.22 rad")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_rotation_radians and get_aoa_radians
print("Test: get_rotation_radians() and get_aoa_radians()")
do
    local c = Camera.new({ name = "test", rotation = 180, aoa = 45 })
    local rot_rad = c:get_rotation_radians()
    local aoa_rad = c:get_aoa_radians()
    assert_true(math.abs(rot_rad - math.pi) < 0.0001, "180 deg = pi rad")
    assert_true(math.abs(aoa_rad - math.pi/4) < 0.0001, "45 deg = pi/4 rad")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_local_rotations
print("Test: has_local_rotations() detects 1.31+ format")
do
    local c_old = Camera.new({ name = "test" })
    local c_new = Camera.new({
        name = "test",
        local_pitch = 0,
        local_yaw = 0,
        local_roll = 0,
    })
    assert_eq(c_old:has_local_rotations(), false, "old format has no local rotations")
    assert_eq(c_new:has_local_rotations(), true, "1.31+ format has local rotations")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_look_direction
print("Test: get_look_direction() returns normalized vector")
do
    local c = Camera.new({
        name = "test",
        target = { x = 0, y = 0 },
        z_offset = 0,
        rotation = 0,
        aoa = 0,
        distance = 1000,
    })
    local dir = c:get_look_direction()
    -- Direction should be normalized (length ~= 1)
    local length = math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
    assert_true(math.abs(length - 1) < 0.0001, "direction should be normalized")
    -- With rotation=0, aoa=0, camera is at (0, -1000, 0), looking at (0, 0, 0)
    -- Direction should be (0, 1, 0)
    assert_true(math.abs(dir.x - 0) < 0.01, "dir.x should be ~0")
    assert_true(math.abs(dir.y - 1) < 0.01, "dir.y should be ~1")
    assert_true(math.abs(dir.z - 0) < 0.01, "dir.z should be ~0")
end
print("  PASSED")
-- }}}

-- {{{ Test: Camera target table is copied
print("Test: Camera target table is copied (no external mutation)")
do
    local target = { x = 500, y = 600 }
    local c = Camera.new({ name = "test", target = target })

    -- Modify original
    target.x = 999

    -- Camera should be unaffected
    assert_eq(c.target.x, 500, "target should be copied, not referenced")
end
print("  PASSED")
-- }}}

-- {{{ Test: Camera __tostring shows format indicator
print("Test: Camera __tostring shows format indicator")
do
    local c_old = Camera.new({ name = "intro_cam", distance = 1650, fov = 70 })
    local c_new = Camera.new({
        name = "intro_cam",
        distance = 1650,
        fov = 70,
        local_pitch = 0,
    })

    local str_old = tostring(c_old)
    local str_new = tostring(c_new)

    assert_true(str_old:find("Camera"), "should contain 'Camera'")
    assert_true(str_old:find("intro_cam"), "should contain name")
    assert_true(not str_old:find("1.31"), "old format should NOT show 1.31")
    assert_true(str_new:find("1.31"), "new format should show 1.31")
end
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
    flags = 3,  -- looping + 3D (numeric legacy format)
})
assert_eq(sound.name, "test_sound", "sound.name")
assert_not_nil(sound.is_looping, "sound should have is_looping()")
assert_not_nil(sound.is_3d, "sound should have is_3d()")
assert_not_nil(sound.get_effective_volume, "sound should have get_effective_volume()")
print("  PASSED")
-- }}}

-- ============================================================================
-- 206f: Sound Class Detailed Tests
-- ============================================================================

-- {{{ Test: Sound constructor copies all fields (table flags)
print("Test: Sound constructor with table flags")
do
    local s = Sound.new({
        name = "battle_music",
        file = "Sound\\Music\\battle.mp3",
        eax = "DefaultEAXON",
        eax_name = "Default",
        flags = {
            raw = 11,
            looping = true,
            sound_3d = true,
            stop_out_range = false,
            music = true,
        },
        fade_in = 500,
        fade_out = 1000,
        volume = 75,
        pitch = 1.2,
        channel = 7,
        channel_name = "Music",
        distance = { min = 100, max = 5000, cutoff = 2000 },
        cone = { inside_angle = 90, outside_angle = 180, outside_volume = 50 },
    })
    assert_eq(s.name, "battle_music", "name")
    assert_eq(s.file, "Sound\\Music\\battle.mp3", "file")
    assert_eq(s.eax, "DefaultEAXON", "eax")
    assert_eq(s.flags.looping, true, "flags.looping")
    assert_eq(s.flags.sound_3d, true, "flags.sound_3d")
    assert_eq(s.flags.music, true, "flags.music")
    assert_eq(s.fade_in, 500, "fade_in")
    assert_eq(s.fade_out, 1000, "fade_out")
    assert_eq(s.volume, 75, "volume")
    assert_eq(s.pitch, 1.2, "pitch")
    assert_eq(s.channel, 7, "channel")
    assert_eq(s.distance.min, 100, "distance.min")
    assert_eq(s.distance.max, 5000, "distance.max")
    assert_eq(s.distance.cutoff, 2000, "distance.cutoff")
end
print("  PASSED")
-- }}}

-- {{{ Test: Sound constructor with numeric flags (legacy)
print("Test: Sound constructor with numeric flags (legacy)")
do
    -- flags=11 = 1+2+8 = looping + 3d + music
    local s = Sound.new({
        name = "test",
        flags = 11,
    })
    assert_eq(s:is_looping(), true, "bit 0 = looping")
    assert_eq(s:is_3d(), true, "bit 1 = 3d")
    assert_eq(s:stops_out_of_range(), false, "bit 2 = stop_out_range")
    assert_eq(s:is_music(), true, "bit 3 = music")
end
print("  PASSED")
-- }}}

-- {{{ Test: Sound default values
print("Test: Sound default values when fields missing")
do
    local s = Sound.new({ name = "minimal" })
    assert_eq(s.name, "minimal", "name")
    assert_eq(s.file, "", "default file")
    assert_eq(s.flags.looping, false, "default looping")
    assert_eq(s.flags.sound_3d, false, "default sound_3d")
    assert_eq(s.fade_in, 10, "default fade_in")
    assert_eq(s.fade_out, 10, "default fade_out")
    assert_eq(s.volume, -1, "default volume (-1)")
    assert_eq(s.pitch, 1.0, "default pitch")
    assert_eq(s.channel, 0, "default channel")
    assert_eq(s.distance.min, 0, "default distance.min")
    assert_eq(s.distance.max, 10000, "default distance.max")
    assert_eq(s.distance.cutoff, 3000, "default distance.cutoff")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_looping
print("Test: is_looping() returns correct value")
do
    local looping = Sound.new({ flags = { looping = true } })
    local not_looping = Sound.new({ flags = { looping = false } })
    local no_flags = Sound.new({})

    assert_eq(looping:is_looping(), true, "looping=true")
    assert_eq(not_looping:is_looping(), false, "looping=false")
    assert_eq(no_flags:is_looping(), false, "no flags = not looping")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_3d
print("Test: is_3d() returns correct value")
do
    local is_3d = Sound.new({ flags = { sound_3d = true } })
    local not_3d = Sound.new({ flags = { sound_3d = false } })

    assert_eq(is_3d:is_3d(), true, "sound_3d=true")
    assert_eq(not_3d:is_3d(), false, "sound_3d=false")
end
print("  PASSED")
-- }}}

-- {{{ Test: is_music
print("Test: is_music() returns correct value")
do
    local music = Sound.new({ flags = { music = true } })
    local not_music = Sound.new({ flags = { music = false } })

    assert_eq(music:is_music(), true, "music=true")
    assert_eq(not_music:is_music(), false, "music=false")
end
print("  PASSED")
-- }}}

-- {{{ Test: stops_out_of_range
print("Test: stops_out_of_range() returns correct value")
do
    local stops = Sound.new({ flags = { stop_out_range = true } })
    local not_stops = Sound.new({ flags = { stop_out_range = false } })

    assert_eq(stops:stops_out_of_range(), true, "stop_out_range=true")
    assert_eq(not_stops:stops_out_of_range(), false, "stop_out_range=false")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_effective_volume
print("Test: get_effective_volume() handles -1 default")
do
    local default_vol = Sound.new({ volume = -1 })
    local custom_vol = Sound.new({ volume = 50 })
    local zero_vol = Sound.new({ volume = 0 })

    assert_eq(default_vol:get_effective_volume(), 100, "-1 = 100%")
    assert_eq(custom_vol:get_effective_volume(), 50, "50 = 50%")
    assert_eq(zero_vol:get_effective_volume(), 0, "0 = 0%")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_effective_pitch
print("Test: get_effective_pitch() handles -1 default")
do
    local default_pitch = Sound.new({ pitch = -1 })
    local custom_pitch = Sound.new({ pitch = 1.5 })
    local normal_pitch = Sound.new({ pitch = 1.0 })

    assert_eq(default_pitch:get_effective_pitch(), 1.0, "-1 = 1.0")
    assert_eq(custom_pitch:get_effective_pitch(), 1.5, "1.5 = 1.5")
    assert_eq(normal_pitch:get_effective_pitch(), 1.0, "1.0 = 1.0")
end
print("  PASSED")
-- }}}

-- {{{ Test: distance methods
print("Test: get_min/max/cutoff_distance()")
do
    local s = Sound.new({
        distance = { min = 200, max = 8000, cutoff = 4000 },
    })

    assert_eq(s:get_min_distance(), 200, "min_distance")
    assert_eq(s:get_max_distance(), 8000, "max_distance")
    assert_eq(s:get_cutoff_distance(), 4000, "cutoff_distance")
end
print("  PASSED")
-- }}}

-- {{{ Test: fade methods
print("Test: get_fade_in() and get_fade_out()")
do
    local s = Sound.new({ fade_in = 250, fade_out = 500 })

    assert_eq(s:get_fade_in(), 250, "fade_in")
    assert_eq(s:get_fade_out(), 500, "fade_out")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_channel
print("Test: get_channel() returns number and name")
do
    local s = Sound.new({ channel = 7, channel_name = "Music" })
    local ch_num, ch_name = s:get_channel()

    assert_eq(ch_num, 7, "channel number")
    assert_eq(ch_name, "Music", "channel name")
end
print("  PASSED")
-- }}}

-- {{{ Test: has_cone
print("Test: has_cone() detects cone parameters")
do
    local with_cone = Sound.new({
        cone = { inside_angle = 90, outside_angle = 180, outside_volume = 50 },
    })
    local no_cone = Sound.new({
        cone = { inside_angle = 0, outside_angle = 0, outside_volume = 0 },
    })
    local default_cone = Sound.new({})

    assert_eq(with_cone:has_cone(), true, "has cone parameters")
    assert_eq(no_cone:has_cone(), false, "zero angles = no cone")
    assert_eq(default_cone:has_cone(), false, "default = no cone")
end
print("  PASSED")
-- }}}

-- {{{ Test: distance table is copied
print("Test: distance table is copied (no external mutation)")
do
    local dist = { min = 100, max = 5000, cutoff = 2000 }
    local s = Sound.new({ distance = dist })

    -- Modify original
    dist.min = 999

    -- Sound should be unaffected
    assert_eq(s.distance.min, 100, "distance should be copied")
end
print("  PASSED")
-- }}}

-- {{{ Test: __tostring shows flags
print("Test: __tostring shows flag indicators")
do
    local plain = Sound.new({ name = "plain" })
    local looping = Sound.new({ name = "loop", flags = { looping = true } })
    local music_3d = Sound.new({
        name = "music_3d",
        flags = { music = true, sound_3d = true },
    })
    local quiet = Sound.new({ name = "quiet", volume = 50 })

    local plain_str = tostring(plain)
    local loop_str = tostring(looping)
    local music_str = tostring(music_3d)
    local quiet_str = tostring(quiet)

    assert_true(plain_str:find("Sound"), "should contain 'Sound'")
    assert_true(not plain_str:find("%["), "plain has no flags")
    assert_true(loop_str:find("loop"), "looping shows [loop]")
    assert_true(music_str:find("music"), "music shows [music]")
    assert_true(music_str:find("3D"), "3D shows [3D]")
    assert_true(quiet_str:find("vol=50"), "non-100 volume shown")
end
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
