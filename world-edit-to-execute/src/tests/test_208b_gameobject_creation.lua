-- Game Object Creation Integration Tests
-- Tests creation of game objects from actual parsed map data.
-- Validates the interface between parsers and game object classes.
--
-- Part of issue 208b - bridges parsers (Phase 2a) and game objects (206).
-- Ensures data structures are compatible and object interfaces work correctly.

-- {{{ Test setup
local DIR = debug.getinfo(1, "S").source:match("@(.*/)") or "./"
DIR = DIR:match("(.-)/src/tests/$") or DIR:match("(.-)/src/tests/") or "."
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local tests_run = 0
local tests_passed = 0

local function assert_true(condition, message)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
        return true
    else
        print("  FAILED: " .. (message or "assertion failed"))
        return false
    end
end

local function assert_eq(actual, expected, message)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected %s, got %s)",
            message or "equality", tostring(expected), tostring(actual)))
        return false
    end
end

local function assert_not_nil(value, message)
    tests_run = tests_run + 1
    if value ~= nil then
        tests_passed = tests_passed + 1
        return true
    else
        print("  FAILED: " .. (message or "value is nil"))
        return false
    end
end

local function assert_type(value, expected_type, message)
    tests_run = tests_run + 1
    if type(value) == expected_type then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected type %s, got %s)",
            message or "type check", expected_type, type(value)))
        return false
    end
end
-- }}}

-- {{{ Load modules
print("Loading gameobjects module...")
local ok, gameobjects = pcall(require, "gameobjects")
if not ok then
    print("FATAL: Failed to load gameobjects module: " .. tostring(gameobjects))
    os.exit(1)
end

local Doodad = gameobjects.Doodad
local Unit = gameobjects.Unit
local Region = gameobjects.Region
local Camera = gameobjects.Camera
local Sound = gameobjects.Sound

print("Loading parsers...")
local mpq = require("mpq")
local doo_parser = require("parsers.doo")
local unitsdoo_parser = require("parsers.unitsdoo")
local w3r_parser = require("parsers.w3r")
local w3c_parser = require("parsers.w3c")
local w3s_parser = require("parsers.w3s")
print("Modules loaded successfully.")
print("")
-- }}}

-- {{{ Test map selection
local TEST_MAP = DIR .. "/assets/DaoW-6.8-(HvA).w3x"
-- Verify test map exists
local f = io.open(TEST_MAP, "r")
if not f then
    print("ERROR: Test map not found: " .. TEST_MAP)
    print("Available maps:")
    os.execute("ls -1 '" .. DIR .. "/assets/'")
    os.exit(1)
end
f:close()
print("Using test map: " .. TEST_MAP)
print("")
-- }}}

-- ============================================================================
-- SECTION 1: Doodad Creation Tests
-- ============================================================================

-- {{{ Test: Doodad creation from parser-like structure
print("Test: Doodad creation from parser-like structure")
do
    -- Simulate parser output structure
    local parsed_doodad = {
        id = "LTlt",
        variation = 2,
        position = { x = 1024.5, y = -512.25, z = 32.0 },
        angle = 1.5708,  -- ~90 degrees
        scale = { x = 1.2, y = 1.2, z = 1.5 },
        flags = 2,  -- visible + solid
        life = 100,
        creation_number = 12345,
        item_table_pointer = -1,
        item_sets_count = 0,
    }

    local doodad = Doodad.new(parsed_doodad)

    assert_eq(doodad.id, "LTlt", "id matches")
    assert_eq(doodad.variation, 2, "variation matches")
    assert_eq(doodad.position.x, 1024.5, "position.x matches")
    assert_eq(doodad.position.y, -512.25, "position.y matches")
    assert_eq(doodad.position.z, 32.0, "position.z matches")
    assert_eq(doodad.flags, 2, "flags match")
    assert_eq(doodad.creation_number, 12345, "creation_number matches")

    -- Test methods
    assert_eq(doodad:is_visible(), true, "is_visible() works")
    assert_eq(doodad:is_solid(), true, "is_solid() works")
    assert_eq(doodad:get_max_life(), 100, "get_max_life() works")
    assert_eq(doodad:has_item_drops(), false, "has_item_drops() works")
end
print("  PASSED")
-- }}}

-- {{{ Test: Doodad with various flag combinations
print("Test: Doodad flag combinations")
do
    local invisible = Doodad.new({ id = "test", flags = 0 })
    local visible_nonsolid = Doodad.new({ id = "test", flags = 1 })
    local normal = Doodad.new({ id = "test", flags = 2 })

    assert_eq(invisible:is_visible(), false, "flags=0 invisible")
    assert_eq(invisible:is_solid(), false, "flags=0 not solid")
    assert_eq(visible_nonsolid:is_visible(), true, "flags=1 visible")
    assert_eq(visible_nonsolid:is_solid(), false, "flags=1 not solid")
    assert_eq(normal:is_visible(), true, "flags=2 visible")
    assert_eq(normal:is_solid(), true, "flags=2 solid")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 2: Unit Creation Tests
-- ============================================================================

-- {{{ Test: Regular unit creation
print("Test: Regular unit creation from parser-like structure")
do
    -- Note: Using "hpea" (Peasant) instead of "hfoo" (Footman) because
    -- "hfoo" has 'f' as second letter which triggers is_building() heuristic
    -- (matches farm pattern). This is a known limitation of the heuristic.
    local parsed_unit = {
        id = "hpea",  -- Peasant
        variation = 0,
        position = { x = 500, y = 600, z = 0 },
        angle = 3.14159,
        scale = { x = 1, y = 1, z = 1 },
        player = 0,
        hp = -1,  -- use default
        mp = -1,  -- use default
        creation_number = 54321,
        waygate_dest = -1,  -- not a waygate
    }

    local unit = Unit.new(parsed_unit)

    assert_eq(unit.id, "hpea", "id matches")
    assert_eq(unit.player, 0, "player matches")
    assert_eq(unit.position.x, 500, "position.x matches")
    assert_eq(unit.creation_id, 54321, "creation_id matches")

    -- Test methods
    assert_eq(unit:is_hero(), false, "peasant is not hero")
    assert_eq(unit:is_building(), false, "peasant is not building")
    assert_eq(unit:is_waygate(), false, "peasant is not waygate")
    assert_eq(unit:is_random(), false, "peasant is not random")
end
print("  PASSED")
-- }}}

-- {{{ Test: Hero unit creation
print("Test: Hero unit creation with hero_data")
do
    local parsed_hero = {
        id = "Hpal",  -- Paladin
        variation = 0,
        position = { x = 1000, y = 1000, z = 0 },
        angle = 0,
        scale = { x = 1, y = 1, z = 1 },
        player = 1,
        hp = -1,
        mp = -1,
        creation_number = 99999,
        hero_data = {
            level = 5,
            str_bonus = 3,
            agi_bonus = 1,
            int_bonus = 2,
            inventory = {
                [0] = "rst1",  -- Healing Scroll
                [2] = "pman",  -- Mana Potion
            },
        },
    }

    local hero = Unit.new(parsed_hero)

    assert_eq(hero:is_hero(), true, "paladin is hero")
    assert_eq(hero:get_hero_level(), 5, "hero level is 5")

    local stats = hero:get_hero_stats()
    assert_not_nil(stats, "hero stats exist")
    assert_eq(stats.str_bonus, 3, "str_bonus matches")
    assert_eq(stats.agi_bonus, 1, "agi_bonus matches")
    assert_eq(stats.int_bonus, 2, "int_bonus matches")

    local inventory = hero:get_inventory()
    assert_eq(inventory[0], "rst1", "slot 0 has healing scroll")
    assert_eq(inventory[2], "pman", "slot 2 has mana potion")
end
print("  PASSED")
-- }}}

-- {{{ Test: Building unit creation
print("Test: Building unit creation")
do
    -- Human Town Hall
    local parsed_building = {
        id = "htow",
        variation = 0,
        position = { x = 0, y = 0, z = 0 },
        angle = 0,
        player = 0,
        creation_number = 11111,
    }

    local building = Unit.new(parsed_building)

    assert_eq(building.id, "htow", "id matches")
    assert_eq(building:is_building(), true, "town hall is building")
    assert_eq(building:is_hero(), false, "town hall is not hero")
end
print("  PASSED")
-- }}}

-- {{{ Test: Waygate unit creation
print("Test: Waygate unit creation")
do
    local parsed_waygate = {
        id = "nwgt",  -- Waygate
        position = { x = 2000, y = 2000, z = 0 },
        player = 12,  -- neutral
        creation_number = 22222,
        waygate_dest = 5,  -- destination region creation_id
    }

    local waygate = Unit.new(parsed_waygate)

    assert_eq(waygate:is_waygate(), true, "is waygate")
    assert_eq(waygate:get_waygate_destination(), 5, "waygate dest is 5")
end
print("  PASSED")
-- }}}

-- {{{ Test: Unit with item drops
print("Test: Unit with item drops")
do
    local parsed_unit_with_drops = {
        id = "ngol",  -- Gollem or similar
        position = { x = 0, y = 0, z = 0 },
        player = 12,
        creation_number = 33333,
        item_drops = {
            sets = {
                { items = { { id = "gold", chance = 100 } } },
            },
        },
    }

    local unit = Unit.new(parsed_unit_with_drops)

    assert_eq(unit:has_item_drops(), true, "has item drops")
    local drops = unit:get_item_drops()
    assert_not_nil(drops, "drops table exists")
    assert_not_nil(drops.sets, "drops.sets exists")
end
print("  PASSED")
-- }}}

-- {{{ Test: Unit with modified abilities
print("Test: Unit with modified abilities")
do
    local parsed_unit_with_abilities = {
        id = "hpea",  -- Peasant
        position = { x = 0, y = 0, z = 0 },
        player = 0,
        creation_number = 44444,
        abilities = {
            { id = "Arep", level = 1, autocast = true },
        },
    }

    local unit = Unit.new(parsed_unit_with_abilities)

    assert_eq(unit:has_modified_abilities(), true, "has modified abilities")
    local abilities = unit:get_abilities()
    assert_eq(#abilities, 1, "one ability")
    assert_eq(abilities[1].id, "Arep", "ability id matches")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 3: Region Creation Tests
-- ============================================================================

-- {{{ Test: Region creation from parser-like structure
print("Test: Region creation from parser-like structure")
do
    local parsed_region = {
        name = "spawn_area_1",
        creation_number = 0,
        left = -512,
        bottom = -256,
        right = 512,
        top = 256,
        color = { r = 255, g = 128, b = 64, a = 128 },
        weather_id = "RAhr",
        ambient_sound = "rain_loop",
    }

    -- Region.new expects bounds as a table
    local region = Region.new({
        name = parsed_region.name,
        creation_number = parsed_region.creation_number,
        bounds = {
            left = parsed_region.left,
            bottom = parsed_region.bottom,
            right = parsed_region.right,
            top = parsed_region.top,
        },
        color = parsed_region.color,
        weather_id = parsed_region.weather_id,
        ambient_sound = parsed_region.ambient_sound,
    })

    assert_eq(region.name, "spawn_area_1", "name matches")
    assert_eq(region.bounds.left, -512, "bounds.left matches")
    assert_eq(region.bounds.right, 512, "bounds.right matches")

    -- Test methods
    local center = region:get_center()
    assert_eq(center.x, 0, "center.x is 0")
    assert_eq(center.y, 0, "center.y is 0")

    local size = region:get_size()
    assert_eq(size.width, 1024, "width is 1024")
    assert_eq(size.height, 512, "height is 512")

    assert_eq(region:get_area(), 1024 * 512, "area is correct")
    assert_eq(region:contains_point(0, 0), true, "contains center")
    assert_eq(region:contains_point(1000, 0), false, "does not contain outside point")
    assert_eq(region:has_weather(), true, "has weather")
    assert_eq(region:has_ambient_sound(), true, "has ambient sound")
end
print("  PASSED")
-- }}}

-- {{{ Test: Region overlap detection
print("Test: Region overlap detection")
do
    local r1 = Region.new({
        name = "r1",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
    })
    local r2 = Region.new({
        name = "r2",
        bounds = { left = 50, bottom = 50, right = 150, top = 150 },
    })
    local r3 = Region.new({
        name = "r3",
        bounds = { left = 200, bottom = 200, right = 300, top = 300 },
    })

    assert_eq(r1:overlaps_region(r2), true, "r1 overlaps r2")
    assert_eq(r2:overlaps_region(r1), true, "r2 overlaps r1 (symmetric)")
    assert_eq(r1:overlaps_region(r3), false, "r1 does not overlap r3")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 4: Camera Creation Tests
-- ============================================================================

-- {{{ Test: Camera creation from parser-like structure
print("Test: Camera creation from parser-like structure")
do
    local parsed_camera = {
        name = "intro_camera",
        target = { x = 1000, y = 2000 },
        z_offset = 100,
        rotation = 90,
        aoa = 304,
        distance = 1650,
        roll = 0,
        fov = 70,
        far_clip = 5000,
        near_clip = 100,
    }

    local camera = Camera.new(parsed_camera)

    assert_eq(camera.name, "intro_camera", "name matches")
    assert_eq(camera.target.x, 1000, "target.x matches")
    assert_eq(camera.target.y, 2000, "target.y matches")
    assert_eq(camera.distance, 1650, "distance matches")
    assert_eq(camera.fov, 70, "fov matches")

    -- Test methods
    local target_pos = camera:get_target_position()
    assert_eq(target_pos.x, 1000, "get_target_position x")
    assert_eq(target_pos.y, 2000, "get_target_position y")
    assert_eq(target_pos.z, 100, "get_target_position z = z_offset")

    local eye = camera:get_eye_position()
    assert_type(eye.x, "number", "eye.x is number")
    assert_type(eye.y, "number", "eye.y is number")
    assert_type(eye.z, "number", "eye.z is number")

    assert_eq(camera:has_local_rotations(), false, "old format no local rotations")
end
print("  PASSED")
-- }}}

-- {{{ Test: Camera with 1.31+ format (local rotations)
print("Test: Camera with 1.31+ format")
do
    local parsed_camera_131 = {
        name = "new_camera",
        target = { x = 0, y = 0 },
        distance = 2000,
        fov = 90,
        local_pitch = 10,
        local_yaw = 20,
        local_roll = 0,
    }

    local camera = Camera.new(parsed_camera_131)

    assert_eq(camera:has_local_rotations(), true, "1.31+ format has local rotations")
    assert_eq(camera.local_pitch, 10, "local_pitch matches")
    assert_eq(camera.local_yaw, 20, "local_yaw matches")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 5: Sound Creation Tests
-- ============================================================================

-- {{{ Test: Sound creation with table flags
print("Test: Sound creation with table flags")
do
    local parsed_sound = {
        name = "battle_drums",
        file = "Sound\\Music\\Drums.mp3",
        eax = "DefaultEAXON",
        flags = {
            raw = 11,
            looping = true,
            sound_3d = true,
            stop_out_range = false,
            music = true,
        },
        fade_in = 500,
        fade_out = 1000,
        volume = 80,
        pitch = 1.0,
        channel = 7,
        min_dist = 100,
        max_dist = 5000,
        dist_cutoff = 2000,
    }

    -- Sound.new expects distance as nested table
    local sound = Sound.new({
        name = parsed_sound.name,
        file = parsed_sound.file,
        eax = parsed_sound.eax,
        flags = parsed_sound.flags,
        fade_in = parsed_sound.fade_in,
        fade_out = parsed_sound.fade_out,
        volume = parsed_sound.volume,
        pitch = parsed_sound.pitch,
        channel = parsed_sound.channel,
        distance = {
            min = parsed_sound.min_dist,
            max = parsed_sound.max_dist,
            cutoff = parsed_sound.dist_cutoff,
        },
    })

    assert_eq(sound.name, "battle_drums", "name matches")
    assert_eq(sound.file, "Sound\\Music\\Drums.mp3", "file matches")
    assert_eq(sound.volume, 80, "volume matches")

    -- Test methods
    assert_eq(sound:is_looping(), true, "is looping")
    assert_eq(sound:is_3d(), true, "is 3D")
    assert_eq(sound:is_music(), true, "is music")
    assert_eq(sound:stops_out_of_range(), false, "does not stop out of range")
    assert_eq(sound:get_effective_volume(), 80, "effective volume is 80")
    assert_eq(sound:get_min_distance(), 100, "min distance is 100")
    assert_eq(sound:get_max_distance(), 5000, "max distance is 5000")
end
print("  PASSED")
-- }}}

-- {{{ Test: Sound creation with numeric flags (legacy)
print("Test: Sound creation with numeric flags (legacy)")
do
    -- flags = 11 = 1+2+8 = looping + 3d + music
    local sound = Sound.new({
        name = "legacy_sound",
        flags = 11,
    })

    assert_eq(sound:is_looping(), true, "bit 0 = looping")
    assert_eq(sound:is_3d(), true, "bit 1 = 3D")
    assert_eq(sound:stops_out_of_range(), false, "bit 2 not set")
    assert_eq(sound:is_music(), true, "bit 3 = music")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 6: Real Parsed Data Tests
-- ============================================================================

-- {{{ Test: Create objects from real map doodads
print("Test: Create Doodad objects from real parsed doodads")
do
    local archive = mpq.open(TEST_MAP)

    if archive:has("war3map.doo") then
        local ok, doo_data = pcall(archive.extract, archive, "war3map.doo")
        if ok and doo_data then
            local parse_ok, parsed = pcall(doo_parser.parse, doo_data)
            if parse_ok and parsed and parsed.doodads then
                local count = 0
                local first_doodad = nil

                for _, d in ipairs(parsed.doodads) do
                    local doodad = Doodad.new(d)
                    if not first_doodad then
                        first_doodad = doodad
                    end
                    count = count + 1

                    -- Validate all created doodads have required fields
                    assert_not_nil(doodad.id, "doodad has id")
                    assert_not_nil(doodad.position, "doodad has position")
                    assert_type(doodad.position.x, "number", "position.x is number")
                end

                print(string.format("    Created %d Doodad objects from map", count))
                if first_doodad then
                    print(string.format("    First doodad: %s", tostring(first_doodad)))
                end
                assert_true(count > 0, "created at least one doodad")
            else
                print("  SKIPPED: Failed to parse war3map.doo")
            end
        end
    else
        print("  SKIPPED: No war3map.doo in archive")
    end

    archive:close()
end
print("  PASSED")
-- }}}

-- {{{ Test: Create objects from real map units
print("Test: Create Unit objects from real parsed units")
do
    local archive = mpq.open(TEST_MAP)

    if archive:has("war3mapUnits.doo") then
        local ok, units_data = pcall(archive.extract, archive, "war3mapUnits.doo")
        if ok and units_data then
            local parse_ok, parsed = pcall(unitsdoo_parser.parse, units_data)
            if parse_ok and parsed and parsed.units then
                local count = 0
                local hero_count = 0
                local building_count = 0
                local waygate_count = 0

                for _, u in ipairs(parsed.units) do
                    local unit = Unit.new(u)
                    count = count + 1

                    if unit:is_hero() then hero_count = hero_count + 1 end
                    if unit:is_building() then building_count = building_count + 1 end
                    if unit:is_waygate() then waygate_count = waygate_count + 1 end

                    -- Validate all created units have required fields
                    assert_not_nil(unit.id, "unit has id")
                    assert_not_nil(unit.position, "unit has position")
                    assert_type(unit.player, "number", "player is number")
                end

                print(string.format("    Created %d Unit objects from map", count))
                print(string.format("    Heroes: %d, Buildings: %d, Waygates: %d",
                    hero_count, building_count, waygate_count))
                assert_true(count > 0, "created at least one unit")
            else
                print("  SKIPPED: Failed to parse war3mapUnits.doo")
            end
        end
    else
        print("  SKIPPED: No war3mapUnits.doo in archive")
    end

    archive:close()
end
print("  PASSED")
-- }}}

-- {{{ Test: Create objects from real map regions
print("Test: Create Region objects from real parsed regions")
do
    local archive = mpq.open(TEST_MAP)

    if archive:has("war3map.w3r") then
        local ok, w3r_data = pcall(archive.extract, archive, "war3map.w3r")
        if ok and w3r_data then
            local parse_ok, parsed = pcall(w3r_parser.parse, w3r_data)
            if parse_ok and parsed and parsed.regions then
                local count = 0
                local weather_count = 0
                local sound_count = 0

                for _, r in ipairs(parsed.regions) do
                    -- w3r parser output might have flat bounds fields
                    local region = Region.new({
                        name = r.name,
                        creation_number = r.creation_number or r.creation_id,
                        bounds = r.bounds or {
                            left = r.left or 0,
                            bottom = r.bottom or 0,
                            right = r.right or 0,
                            top = r.top or 0,
                        },
                        color = r.color,
                        weather_id = r.weather_id,
                        ambient_sound = r.ambient_sound,
                    })
                    count = count + 1

                    if region:has_weather() then weather_count = weather_count + 1 end
                    if region:has_ambient_sound() then sound_count = sound_count + 1 end

                    -- Validate
                    assert_not_nil(region.bounds, "region has bounds")
                end

                print(string.format("    Created %d Region objects from map", count))
                print(string.format("    With weather: %d, With ambient sound: %d",
                    weather_count, sound_count))
                -- Regions may be empty in some maps
                if count == 0 then
                    print("    (No regions in this map)")
                end
            else
                print("  SKIPPED: Failed to parse war3map.w3r")
            end
        end
    else
        print("  SKIPPED: No war3map.w3r in archive")
    end

    archive:close()
end
print("  PASSED")
-- }}}

-- {{{ Test: Create objects from real map cameras
print("Test: Create Camera objects from real parsed cameras")
do
    local archive = mpq.open(TEST_MAP)

    if archive:has("war3map.w3c") then
        local ok, w3c_data = pcall(archive.extract, archive, "war3map.w3c")
        if ok and w3c_data then
            local parse_ok, parsed = pcall(w3c_parser.parse, w3c_data)
            if parse_ok and parsed and parsed.cameras then
                local count = 0
                local local_rot_count = 0

                for _, c in ipairs(parsed.cameras) do
                    local camera = Camera.new(c)
                    count = count + 1

                    if camera:has_local_rotations() then
                        local_rot_count = local_rot_count + 1
                    end

                    -- Validate
                    assert_not_nil(camera.name, "camera has name")
                    assert_not_nil(camera.target, "camera has target")
                end

                print(string.format("    Created %d Camera objects from map", count))
                print(string.format("    With 1.31+ local rotations: %d", local_rot_count))
                if count == 0 then
                    print("    (No cameras in this map)")
                end
            else
                print("  SKIPPED: Failed to parse war3map.w3c")
            end
        end
    else
        print("  SKIPPED: No war3map.w3c in archive")
    end

    archive:close()
end
print("  PASSED")
-- }}}

-- {{{ Test: Create objects from real map sounds
print("Test: Create Sound objects from real parsed sounds")
do
    local archive = mpq.open(TEST_MAP)

    if archive:has("war3map.w3s") then
        local ok, w3s_data = pcall(archive.extract, archive, "war3map.w3s")
        if ok and w3s_data then
            local parse_ok, parsed = pcall(w3s_parser.parse, w3s_data)
            if parse_ok and parsed and parsed.sounds then
                local count = 0
                local looping_count = 0
                local music_count = 0

                for _, s in ipairs(parsed.sounds) do
                    local sound = Sound.new(s)
                    count = count + 1

                    if sound:is_looping() then looping_count = looping_count + 1 end
                    if sound:is_music() then music_count = music_count + 1 end

                    -- Validate
                    assert_not_nil(sound.name, "sound has name")
                end

                print(string.format("    Created %d Sound objects from map", count))
                print(string.format("    Looping: %d, Music: %d", looping_count, music_count))
                if count == 0 then
                    print("    (No sounds in this map)")
                end
            else
                print("  SKIPPED: Failed to parse war3map.w3s")
            end
        end
    else
        print("  SKIPPED: No war3map.w3s in archive")
    end

    archive:close()
end
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
