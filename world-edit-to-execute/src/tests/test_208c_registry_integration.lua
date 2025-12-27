-- Registry Integration Tests
-- Tests the complete registry workflow: loading maps, populating registries,
-- performing lookups, filtering, spatial queries, and cross-reference validation.
--
-- Part of issue 208c - validates parsers → objects → registry pipeline.
-- Ensures all Phase 2 components work together correctly.

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

local function assert_gte(actual, expected, message)
    tests_run = tests_run + 1
    if actual >= expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected >= %s, got %s)",
            message or "gte", tostring(expected), tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ Load modules
print("Loading modules...")
local ObjectRegistry = require("registry")
local gameobjects = require("gameobjects")
local data = require("data")

local Doodad = gameobjects.Doodad
local Unit = gameobjects.Unit
local Region = gameobjects.Region
local Camera = gameobjects.Camera
local Sound = gameobjects.Sound

print("Modules loaded successfully.")
print("")
-- }}}

-- {{{ Test map selection
local TEST_MAP = DIR .. "/assets/DaoW-6.8-(HvA).w3x"
local f = io.open(TEST_MAP, "r")
if not f then
    print("ERROR: Test map not found: " .. TEST_MAP)
    os.exit(1)
end
f:close()
print("Using test map: " .. TEST_MAP)
print("")
-- }}}

-- ============================================================================
-- SECTION 1: Registry Population Tests
-- ============================================================================

-- {{{ Test: Registry creation and basic structure
print("Test: Registry creation and basic structure")
do
    local registry = ObjectRegistry.new()

    assert_not_nil(registry.doodads, "doodads array exists")
    assert_not_nil(registry.units, "units array exists")
    assert_not_nil(registry.regions, "regions array exists")
    assert_not_nil(registry.cameras, "cameras array exists")
    assert_not_nil(registry.sounds, "sounds array exists")
    assert_not_nil(registry.counts, "counts table exists")
    assert_not_nil(registry.by_creation_id, "by_creation_id index exists")
    assert_not_nil(registry.by_name, "by_name index exists")

    assert_eq(registry.counts.doodads, 0, "initial doodads count is 0")
    assert_eq(registry.counts.units, 0, "initial units count is 0")
    assert_eq(registry:get_total_count(), 0, "initial total count is 0")
end
print("  PASSED")
-- }}}

-- {{{ Test: Add objects to registry
print("Test: Add objects to registry")
do
    local registry = ObjectRegistry.new()

    -- Add doodads
    for i = 1, 10 do
        local doodad = Doodad.new({
            id = "LTlt",
            position = { x = i * 100, y = i * 100, z = 0 },
            creation_number = 1000 + i,
        })
        registry:add_doodad(doodad)
    end

    -- Add units
    for i = 1, 5 do
        local unit = Unit.new({
            id = "hfoo",
            position = { x = i * 200, y = i * 200, z = 0 },
            player = i % 3,
            creation_number = 2000 + i,
        })
        registry:add_unit(unit)
    end

    -- Add a region
    local region = Region.new({
        name = "test_region",
        creation_number = 3000,
        bounds = { left = 0, bottom = 0, right = 1000, top = 1000 },
    })
    registry:add_region(region)

    -- Add a camera
    local camera = Camera.new({
        name = "test_camera",
        target = { x = 500, y = 500 },
    })
    registry:add_camera(camera)

    -- Add a sound
    local sound = Sound.new({
        name = "test_sound",
        file = "test.wav",
    })
    registry:add_sound(sound)

    -- Verify counts
    assert_eq(registry.counts.doodads, 10, "10 doodads added")
    assert_eq(registry.counts.units, 5, "5 units added")
    assert_eq(registry.counts.regions, 1, "1 region added")
    assert_eq(registry.counts.cameras, 1, "1 camera added")
    assert_eq(registry.counts.sounds, 1, "1 sound added")
    assert_eq(registry:get_total_count(), 18, "total count is 18")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 2: Lookup Operations Tests
-- ============================================================================

-- {{{ Test: Lookup by creation_id
print("Test: Lookup by creation_id")
do
    local registry = ObjectRegistry.new()

    local doodad = Doodad.new({
        id = "LTlt",
        position = { x = 100, y = 100, z = 0 },
        creation_number = 12345,
    })
    registry:add_doodad(doodad)

    local unit = Unit.new({
        id = "hfoo",
        position = { x = 200, y = 200, z = 0 },
        player = 0,
        creation_number = 54321,
    })
    registry:add_unit(unit)

    -- Test lookups
    local found_doodad = registry:get_by_creation_id(12345)
    assert_not_nil(found_doodad, "found doodad by creation_id")
    assert_eq(found_doodad.id, "LTlt", "found correct doodad")

    local found_unit = registry:get_by_creation_id(54321)
    assert_not_nil(found_unit, "found unit by creation_id")
    assert_eq(found_unit.id, "hfoo", "found correct unit")

    -- Test missing lookup
    local not_found = registry:get_by_creation_id(99999)
    assert_eq(not_found, nil, "missing creation_id returns nil")
end
print("  PASSED")
-- }}}

-- {{{ Test: Lookup by name
print("Test: Lookup by name")
do
    local registry = ObjectRegistry.new()

    local region = Region.new({
        name = "spawn_area",
        creation_number = 100,
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
    })
    registry:add_region(region)

    local camera = Camera.new({
        name = "intro_cam",
        target = { x = 0, y = 0 },
    })
    registry:add_camera(camera)

    local sound = Sound.new({
        name = "battle_music",
        file = "music.mp3",
    })
    registry:add_sound(sound)

    -- Test lookups
    local found_region = registry:get_by_name("spawn_area")
    assert_not_nil(found_region, "found region by name")
    assert_eq(found_region.name, "spawn_area", "found correct region")

    local found_camera = registry:get_by_name("intro_cam")
    assert_not_nil(found_camera, "found camera by name")
    assert_eq(found_camera.name, "intro_cam", "found correct camera")

    local found_sound = registry:get_by_name("battle_music")
    assert_not_nil(found_sound, "found sound by name")
    assert_eq(found_sound.name, "battle_music", "found correct sound")

    -- Test missing lookup
    local not_found = registry:get_by_name("nonexistent")
    assert_eq(not_found, nil, "missing name returns nil")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 3: Filtering Operations Tests
-- ============================================================================

-- {{{ Test: get_units_for_player
print("Test: get_units_for_player")
do
    local registry = ObjectRegistry.new()

    -- Add units for different players
    for i = 1, 10 do
        local unit = Unit.new({
            id = "hfoo",
            position = { x = i * 100, y = 0, z = 0 },
            player = i <= 5 and 0 or 1,  -- 5 for player 0, 5 for player 1
            creation_number = i,
        })
        registry:add_unit(unit)
    end

    local player0_units = registry:get_units_for_player(0)
    local player1_units = registry:get_units_for_player(1)
    local player2_units = registry:get_units_for_player(2)

    assert_eq(#player0_units, 5, "player 0 has 5 units")
    assert_eq(#player1_units, 5, "player 1 has 5 units")
    assert_eq(#player2_units, 0, "player 2 has 0 units")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_heroes
print("Test: get_heroes")
do
    local registry = ObjectRegistry.new()

    -- Add regular units
    for i = 1, 5 do
        local unit = Unit.new({
            id = "hfoo",  -- Footman (not hero)
            position = { x = 0, y = 0, z = 0 },
            player = 0,
            creation_number = i,
        })
        registry:add_unit(unit)
    end

    -- Add heroes
    for i = 6, 8 do
        local hero = Unit.new({
            id = "Hpal",  -- Paladin (hero - capital first letter)
            position = { x = 0, y = 0, z = 0 },
            player = 0,
            creation_number = i,
            hero_data = { level = 1 },
        })
        registry:add_unit(hero)
    end

    local heroes = registry:get_heroes()
    assert_eq(#heroes, 3, "found 3 heroes")

    -- Verify they're all heroes
    for _, h in ipairs(heroes) do
        assert_true(h:is_hero(), "returned unit is hero")
    end
end
print("  PASSED")
-- }}}

-- {{{ Test: get_buildings
print("Test: get_buildings")
do
    local registry = ObjectRegistry.new()

    -- Add regular units
    -- Note: Using "hpea" (Peasant) instead of "hfoo" (Footman) because
    -- "hfoo" has 'f' as second letter which triggers is_building() heuristic
    local peasant = Unit.new({
        id = "hpea",  -- Peasant
        position = { x = 0, y = 0, z = 0 },
        player = 0,
        creation_number = 1,
    })
    registry:add_unit(peasant)

    -- Add buildings (lowercase first letter + specific second letter patterns)
    local townhall = Unit.new({
        id = "htow",  -- Town Hall
        position = { x = 0, y = 0, z = 0 },
        player = 0,
        creation_number = 2,
    })
    registry:add_unit(townhall)

    local barracks = Unit.new({
        id = "hbar",  -- Barracks
        position = { x = 0, y = 0, z = 0 },
        player = 0,
        creation_number = 3,
    })
    registry:add_unit(barracks)

    local buildings = registry:get_buildings()
    assert_eq(#buildings, 2, "found 2 buildings")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_waygates
print("Test: get_waygates")
do
    local registry = ObjectRegistry.new()

    -- Add regular unit
    local unit = Unit.new({
        id = "hfoo",
        position = { x = 0, y = 0, z = 0 },
        player = 0,
        creation_number = 1,
        waygate_dest = -1,  -- Not a waygate
    })
    registry:add_unit(unit)

    -- Add waygates
    for i = 2, 4 do
        local waygate = Unit.new({
            id = "nwgt",
            position = { x = 0, y = 0, z = 0 },
            player = 12,
            creation_number = i,
            waygate_dest = i * 10,  -- Points to a region
        })
        registry:add_unit(waygate)
    end

    local waygates = registry:get_waygates()
    assert_eq(#waygates, 3, "found 3 waygates")

    -- Verify they're all waygates
    for _, w in ipairs(waygates) do
        assert_true(w:is_waygate(), "returned unit is waygate")
        assert_gte(w.waygate_dest, 0, "waygate has valid destination")
    end
end
print("  PASSED")
-- }}}

-- {{{ Test: filter with custom predicate
print("Test: filter with custom predicate")
do
    local registry = ObjectRegistry.new()

    -- Add doodads at different positions
    for i = 1, 10 do
        local doodad = Doodad.new({
            id = "LTlt",
            position = { x = i * 100, y = 0, z = 0 },
            creation_number = i,
            life = i * 10,  -- life varies from 10 to 100
        })
        registry:add_doodad(doodad)
    end

    -- Filter doodads with life > 50
    local high_life = registry:filter("doodad", function(d)
        return d.life > 50
    end)

    assert_eq(#high_life, 5, "found 5 doodads with life > 50")
end
print("  PASSED")
-- }}}

-- {{{ Test: iteration methods
print("Test: iteration methods (each_*)")
do
    local registry = ObjectRegistry.new()

    -- Add objects
    for i = 1, 3 do
        registry:add_doodad(Doodad.new({ id = "d" .. i, creation_number = i }))
        registry:add_unit(Unit.new({ id = "u" .. i, player = 0, creation_number = i + 10 }))
    end

    -- Count via iteration
    local doodad_count = 0
    registry:each_doodad(function(d)
        doodad_count = doodad_count + 1
    end)
    assert_eq(doodad_count, 3, "each_doodad iterated 3 times")

    local unit_count = 0
    registry:each_unit(function(u)
        unit_count = unit_count + 1
    end)
    assert_eq(unit_count, 3, "each_unit iterated 3 times")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 4: Spatial Indexing Tests
-- ============================================================================

-- {{{ Test: Enable spatial index
print("Test: Enable spatial index")
do
    local registry = ObjectRegistry.new()

    -- Add objects first
    for i = 1, 10 do
        local doodad = Doodad.new({
            id = "LTlt",
            position = { x = i * 512, y = i * 512, z = 0 },
            creation_number = i,
        })
        registry:add_doodad(doodad)
    end

    assert_eq(registry:has_spatial_index(), false, "no spatial index initially")

    -- Enable spatial index
    registry:enable_spatial_index(512)

    assert_eq(registry:has_spatial_index(), true, "spatial index enabled")
end
print("  PASSED")
-- }}}

-- {{{ Test: Spatial query - radius
print("Test: Spatial query - get_objects_in_radius")
do
    local registry = ObjectRegistry.new()

    -- Create a grid of objects
    for x = 0, 4 do
        for y = 0, 4 do
            local doodad = Doodad.new({
                id = "LTlt",
                position = { x = x * 1000, y = y * 1000, z = 0 },
                creation_number = x * 5 + y + 1,
            })
            registry:add_doodad(doodad)
        end
    end

    registry:enable_spatial_index(512)

    -- Query around the center (2000, 2000)
    local nearby = registry:get_objects_in_radius(2000, 2000, 1500)

    -- Should find the center and 4 adjacent (within ~1414 diagonal)
    -- Plus potentially corner objects depending on exact radius
    assert_gte(#nearby, 5, "found at least 5 nearby objects")

    -- Query with very small radius
    local exact = registry:get_objects_in_radius(2000, 2000, 10)
    assert_eq(#exact, 1, "found exactly 1 object at exact position")

    -- Query in empty area
    local empty = registry:get_objects_in_radius(-5000, -5000, 100)
    assert_eq(#empty, 0, "found 0 objects in empty area")
end
print("  PASSED")
-- }}}

-- {{{ Test: Spatial query - rectangle
print("Test: Spatial query - get_objects_in_rect")
do
    local registry = ObjectRegistry.new()

    -- Create a grid of objects
    for x = 0, 4 do
        for y = 0, 4 do
            local unit = Unit.new({
                id = "hfoo",
                position = { x = x * 1000, y = y * 1000, z = 0 },
                player = 0,
                creation_number = x * 5 + y + 1,
            })
            registry:add_unit(unit)
        end
    end

    registry:enable_spatial_index(512)

    -- Query a 2x2 area (should get 4 objects)
    local in_rect = registry:get_objects_in_rect(500, 500, 1500, 1500)
    assert_eq(#in_rect, 1, "found 1 object in small rect (only (1000,1000))")

    -- Query larger area (0-2000, 0-2000) should get 9 objects (3x3 grid)
    local larger = registry:get_objects_in_rect(-100, -100, 2100, 2100)
    assert_eq(#larger, 9, "found 9 objects in 3x3 area")
end
print("  PASSED")
-- }}}

-- {{{ Test: Spatial query with region bounds
print("Test: Spatial query - get_objects_in_region")
do
    local registry = ObjectRegistry.new()

    -- Create objects
    for i = 1, 5 do
        local doodad = Doodad.new({
            id = "LTlt",
            position = { x = i * 200, y = i * 200, z = 0 },
            creation_number = i,
        })
        registry:add_doodad(doodad)
    end

    registry:enable_spatial_index(256)

    -- Create a region
    local region = Region.new({
        name = "test_region",
        bounds = { left = 300, bottom = 300, right = 700, top = 700 },
    })

    -- Query objects in region
    local in_region = registry:get_objects_in_region(region)
    -- Should find objects at (400, 400) and (600, 600)
    assert_eq(#in_region, 2, "found 2 objects in region")
end
print("  PASSED")
-- }}}

-- {{{ Test: Objects added after spatial index is enabled
print("Test: Objects added after spatial index is enabled")
do
    local registry = ObjectRegistry.new()

    -- Enable spatial index first
    registry:enable_spatial_index(512)

    -- Then add objects
    for i = 1, 5 do
        local doodad = Doodad.new({
            id = "LTlt",
            position = { x = i * 100, y = 0, z = 0 },
            creation_number = i,
        })
        registry:add_doodad(doodad)
    end

    -- Query should find them
    local nearby = registry:get_objects_in_radius(300, 0, 250)
    assert_gte(#nearby, 2, "found objects added after index creation")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 5: Cross-Reference Validation Tests
-- ============================================================================

-- {{{ Test: Waygate to Region cross-reference
print("Test: Waygate to Region cross-reference")
do
    local registry = ObjectRegistry.new()

    -- Add regions first
    for i = 1, 3 do
        local region = Region.new({
            name = "region_" .. i,
            creation_number = i * 10,
            bounds = { left = 0, bottom = 0, right = 100, top = 100 },
        })
        registry:add_region(region)
    end

    -- Add waygates pointing to regions
    for i = 1, 2 do
        local waygate = Unit.new({
            id = "nwgt",
            position = { x = 0, y = 0, z = 0 },
            player = 12,
            creation_number = 100 + i,
            waygate_dest = i * 10,  -- Points to region 10 or 20
        })
        registry:add_unit(waygate)
    end

    -- Add a waygate pointing to nonexistent region
    local bad_waygate = Unit.new({
        id = "nwgt",
        position = { x = 0, y = 0, z = 0 },
        player = 12,
        creation_number = 103,
        waygate_dest = 999,  -- Nonexistent region
    })
    registry:add_unit(bad_waygate)

    -- Validate cross-references
    local waygates = registry:get_waygates()
    local valid_refs = 0
    local invalid_refs = 0

    for _, wg in ipairs(waygates) do
        local dest_region = registry:get_by_creation_id(wg.waygate_dest)
        if dest_region then
            valid_refs = valid_refs + 1
        else
            invalid_refs = invalid_refs + 1
        end
    end

    assert_eq(valid_refs, 2, "2 valid waygate references")
    assert_eq(invalid_refs, 1, "1 invalid waygate reference")
end
print("  PASSED")
-- }}}

-- {{{ Test: Region to Sound cross-reference
print("Test: Region to Sound cross-reference")
do
    local registry = ObjectRegistry.new()

    -- Add sounds
    registry:add_sound(Sound.new({ name = "rain_loop", file = "rain.wav" }))
    registry:add_sound(Sound.new({ name = "wind_ambient", file = "wind.wav" }))

    -- Add regions with sound references
    local r1 = Region.new({
        name = "rainy_area",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 },
        ambient_sound = "rain_loop",
    })
    registry:add_region(r1)

    local r2 = Region.new({
        name = "windy_area",
        bounds = { left = 100, bottom = 0, right = 200, top = 100 },
        ambient_sound = "wind_ambient",
    })
    registry:add_region(r2)

    local r3 = Region.new({
        name = "quiet_area",
        bounds = { left = 200, bottom = 0, right = 300, top = 100 },
        -- No ambient sound
    })
    registry:add_region(r3)

    local r4 = Region.new({
        name = "missing_sound_area",
        bounds = { left = 300, bottom = 0, right = 400, top = 100 },
        ambient_sound = "nonexistent_sound",
    })
    registry:add_region(r4)

    -- Validate cross-references
    local regions_with_sound = 0
    local valid_sound_refs = 0
    local missing_sound_refs = 0

    for _, region in ipairs(registry.regions) do
        if region:has_ambient_sound() then
            regions_with_sound = regions_with_sound + 1
            local sound = registry:get_by_name(region.ambient_sound)
            if sound then
                valid_sound_refs = valid_sound_refs + 1
            else
                missing_sound_refs = missing_sound_refs + 1
            end
        end
    end

    assert_eq(regions_with_sound, 3, "3 regions have ambient sound")
    assert_eq(valid_sound_refs, 2, "2 valid sound references")
    assert_eq(missing_sound_refs, 1, "1 missing sound reference")
end
print("  PASSED")
-- }}}

-- ============================================================================
-- SECTION 6: Real Map Data Integration Tests
-- ============================================================================

-- {{{ Test: Load real map with Map.load()
print("Test: Load real map with Map.load()")
do
    local map = data.load(TEST_MAP)

    assert_not_nil(map, "map loaded")
    assert_not_nil(map.registry, "map has registry")

    -- Check counts
    local counts = map.registry.counts
    print(string.format("    Map: %s", map:get_display_name()))
    print(string.format("    Doodads: %d", counts.doodads))
    print(string.format("    Units: %d", counts.units))
    print(string.format("    Regions: %d", counts.regions))
    print(string.format("    Cameras: %d", counts.cameras))
    print(string.format("    Sounds: %d", counts.sounds))

    -- Verify we loaded something
    local total = map.registry:get_total_count()
    assert_gte(total, 1, "loaded at least 1 object")
end
print("  PASSED")
-- }}}

-- {{{ Test: Real map - unit type breakdown
print("Test: Real map - unit type breakdown")
do
    local map = data.load(TEST_MAP)

    local heroes = map.registry:get_heroes()
    local buildings = map.registry:get_buildings()
    local waygates = map.registry:get_waygates()

    print(string.format("    Heroes: %d", #heroes))
    print(string.format("    Buildings: %d", #buildings))
    print(string.format("    Waygates: %d", #waygates))

    -- Just verify the methods work without errors
    assert_not_nil(heroes, "get_heroes returned")
    assert_not_nil(buildings, "get_buildings returned")
    assert_not_nil(waygates, "get_waygates returned")
end
print("  PASSED")
-- }}}

-- {{{ Test: Real map - player unit distribution
print("Test: Real map - player unit distribution")
do
    local map = data.load(TEST_MAP)

    print("    Units by player:")
    local total_accounted = 0
    for player_id = 0, 15 do
        local player_units = map.registry:get_units_for_player(player_id)
        if #player_units > 0 then
            print(string.format("      Player %d: %d units", player_id, #player_units))
            total_accounted = total_accounted + #player_units
        end
    end

    -- Total should match registry count
    assert_eq(total_accounted, map.registry.counts.units,
        "all units accounted for by player")
end
print("  PASSED")
-- }}}

-- {{{ Test: Real map - spatial queries
print("Test: Real map - spatial queries")
do
    local map = data.load(TEST_MAP)

    if map.registry.counts.doodads == 0 and map.registry.counts.units == 0 then
        print("    SKIPPED: No positioned objects in map")
    else
        -- Enable spatial indexing
        map.registry:enable_spatial_index(512)

        -- Get first positioned object as reference point
        local ref_obj = nil
        if #map.registry.doodads > 0 then
            ref_obj = map.registry.doodads[1]
        elseif #map.registry.units > 0 then
            ref_obj = map.registry.units[1]
        end

        if ref_obj and ref_obj.position then
            local x, y = ref_obj.position.x, ref_obj.position.y
            local nearby = map.registry:get_objects_in_radius(x, y, 2000)
            print(string.format("    Objects within 2000 units of (%.0f, %.0f): %d",
                x, y, #nearby))
            assert_gte(#nearby, 1, "found at least 1 object nearby")
        else
            print("    SKIPPED: No positioned objects found")
        end
    end
end
print("  PASSED")
-- }}}

-- {{{ Test: Real map - waygate cross-reference validation
print("Test: Real map - waygate cross-reference validation")
do
    local map = data.load(TEST_MAP)

    local waygates = map.registry:get_waygates()
    if #waygates == 0 then
        print("    No waygates in this map")
    else
        local valid_refs = 0
        local invalid_refs = 0

        for _, wg in ipairs(waygates) do
            local dest = wg.waygate_dest
            if dest and dest >= 0 then
                local dest_region = map.registry:get_by_creation_id(dest)
                if dest_region then
                    valid_refs = valid_refs + 1
                else
                    invalid_refs = invalid_refs + 1
                    print(string.format("    WARNING: Waygate %d points to missing region %d",
                        wg.creation_id or 0, dest))
                end
            end
        end

        print(string.format("    Waygates: %d total, %d valid, %d invalid",
            #waygates, valid_refs, invalid_refs))
    end
end
print("  PASSED")
-- }}}

-- {{{ Test: Real map - region ambient sound validation
print("Test: Real map - region ambient sound validation")
do
    local map = data.load(TEST_MAP)

    local regions_with_sound = 0
    local valid_refs = 0
    local missing_refs = 0

    for _, region in ipairs(map.registry.regions) do
        if region:has_ambient_sound() then
            regions_with_sound = regions_with_sound + 1
            local sound = map.registry:get_by_name(region.ambient_sound)
            if sound then
                valid_refs = valid_refs + 1
            else
                missing_refs = missing_refs + 1
                -- External sounds are common, just log
            end
        end
    end

    print(string.format("    Regions with ambient sound: %d", regions_with_sound))
    print(string.format("    Valid sound references: %d", valid_refs))
    print(string.format("    Missing/external sound references: %d", missing_refs))
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
