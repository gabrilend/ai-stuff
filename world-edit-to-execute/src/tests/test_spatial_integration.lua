#!/usr/bin/env luajit
-- src/tests/test_spatial_integration.lua
-- Tests for ObjectRegistry spatial integration (207d)
--
-- Run with: luajit -e "package.path = package.path .. ';src/?.lua;src/?/init.lua'" src/tests/test_spatial_integration.lua

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

-- {{{ Helper: assert_true
local function assert_true(actual, msg)
    tests_total = tests_total + 1
    if actual == true then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected true)", msg or "assertion failed"))
        return false
    end
end
-- }}}

-- {{{ Helper: assert_false
local function assert_false(actual, msg)
    tests_total = tests_total + 1
    if actual == false or actual == nil then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s (expected false/nil)", msg or "assertion failed"))
        return false
    end
end
-- }}}

-- {{{ Helper: assert_error
local function assert_error(func, expected_msg, msg)
    tests_total = tests_total + 1
    local ok, err = pcall(func)
    if not ok and err:find(expected_msg, 1, true) then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("  FAILED: %s", msg or "expected error"))
        if ok then
            print("    no error was thrown")
        else
            print(string.format("    error: %s", err))
        end
        return false
    end
end
-- }}}

-- {{{ Helper: contains
local function contains(tbl, obj)
    for _, v in ipairs(tbl) do
        if v == obj then return true end
    end
    return false
end
-- }}}

print("=== Spatial Integration Tests (207d) ===")
print("")

-- {{{ Test: has_spatial_index returns false initially
print("Test: has_spatial_index returns false initially")
do
    local registry = ObjectRegistry.new()
    assert_false(registry:has_spatial_index(), "should return false before enable")
end
print("  PASSED")
-- }}}

-- {{{ Test: enable_spatial_index creates index
print("Test: enable_spatial_index creates index")
do
    local registry = ObjectRegistry.new()
    registry:enable_spatial_index(256)
    assert_true(registry:has_spatial_index(), "should return true after enable")
end
print("  PASSED")
-- }}}

-- {{{ Test: enable_spatial_index uses default cell size
print("Test: enable_spatial_index uses default cell size")
do
    local registry = ObjectRegistry.new()
    registry:enable_spatial_index()  -- No argument
    assert_true(registry:has_spatial_index(), "should work with default cell size")
end
print("  PASSED")
-- }}}

-- {{{ Test: existing doodads indexed when spatial enabled
print("Test: existing doodads indexed when spatial enabled")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1, position = { x = 100, y = 100 } }
    local d2 = { creation_id = 2, position = { x = 200, y = 200 } }

    registry:add_doodad(d1)
    registry:add_doodad(d2)
    registry:enable_spatial_index(512)

    local nearby = registry:get_objects_in_radius(100, 100, 50)
    assert_eq(#nearby, 1, "should find 1 doodad near (100,100)")
    assert_eq(nearby[1], d1, "should be d1")
end
print("  PASSED")
-- }}}

-- {{{ Test: existing units indexed when spatial enabled
print("Test: existing units indexed when spatial enabled")
do
    local registry = ObjectRegistry.new()
    local u1 = { creation_id = 1, player = 0, position = { x = 500, y = 500 } }
    local u2 = { creation_id = 2, player = 1, position = { x = 600, y = 600 } }

    registry:add_unit(u1)
    registry:add_unit(u2)
    registry:enable_spatial_index(512)

    local nearby = registry:get_objects_in_radius(500, 500, 50)
    assert_eq(#nearby, 1, "should find 1 unit near (500,500)")
    assert_eq(nearby[1], u1, "should be u1")
end
print("  PASSED")
-- }}}

-- {{{ Test: new doodads auto-indexed after enable
print("Test: new doodads auto-indexed after enable")
do
    local registry = ObjectRegistry.new()
    registry:enable_spatial_index(512)

    local d1 = { creation_id = 1, position = { x = 100, y = 100 } }
    registry:add_doodad(d1)

    local nearby = registry:get_objects_in_radius(100, 100, 50)
    assert_eq(#nearby, 1, "should find doodad added after enable")
end
print("  PASSED")
-- }}}

-- {{{ Test: new units auto-indexed after enable
print("Test: new units auto-indexed after enable")
do
    local registry = ObjectRegistry.new()
    registry:enable_spatial_index(512)

    local u1 = { creation_id = 1, player = 0, position = { x = 100, y = 100 } }
    registry:add_unit(u1)

    local nearby = registry:get_objects_in_radius(100, 100, 50)
    assert_eq(#nearby, 1, "should find unit added after enable")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_objects_in_radius returns correct objects
print("Test: get_objects_in_radius returns correct objects")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1, position = { x = 0, y = 0 } }
    local d2 = { creation_id = 2, position = { x = 100, y = 0 } }
    local u1 = { creation_id = 3, player = 0, position = { x = 50, y = 0 } }
    local d3 = { creation_id = 4, position = { x = 1000, y = 1000 } }  -- Far away

    registry:add_doodad(d1)
    registry:add_doodad(d2)
    registry:add_unit(u1)
    registry:add_doodad(d3)
    registry:enable_spatial_index(512)

    local nearby = registry:get_objects_in_radius(50, 0, 100)
    assert_eq(#nearby, 3, "should find 3 objects within radius 100")
    assert_true(contains(nearby, d1), "should contain d1")
    assert_true(contains(nearby, d2), "should contain d2")
    assert_true(contains(nearby, u1), "should contain u1")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_objects_in_region returns correct objects
print("Test: get_objects_in_region returns correct objects")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1, position = { x = 50, y = 50 } }
    local d2 = { creation_id = 2, position = { x = 150, y = 150 } }  -- Outside
    local u1 = { creation_id = 3, player = 0, position = { x = 75, y = 75 } }

    registry:add_doodad(d1)
    registry:add_doodad(d2)
    registry:add_unit(u1)
    registry:enable_spatial_index(512)

    local region = {
        name = "test_region",
        bounds = { left = 0, bottom = 0, right = 100, top = 100 }
    }

    local in_region = registry:get_objects_in_region(region)
    assert_eq(#in_region, 2, "should find 2 objects in region")
    assert_true(contains(in_region, d1), "should contain d1")
    assert_true(contains(in_region, u1), "should contain u1")
end
print("  PASSED")
-- }}}

-- {{{ Test: error if spatial query before enable
print("Test: error if spatial query before enable")
do
    local registry = ObjectRegistry.new()

    assert_error(function()
        registry:get_objects_in_radius(0, 0, 100)
    end, "Spatial indexing not enabled", "get_objects_in_radius should error")

    assert_error(function()
        registry:get_objects_in_rect(0, 0, 100, 100)
    end, "Spatial indexing not enabled", "get_objects_in_rect should error")

    assert_error(function()
        registry:get_objects_in_region({ bounds = { left = 0, bottom = 0, right = 100, top = 100 } })
    end, "Spatial indexing not enabled", "get_objects_in_region should error")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_objects_in_region errors without bounds
print("Test: get_objects_in_region errors without bounds")
do
    local registry = ObjectRegistry.new()
    registry:enable_spatial_index(512)

    assert_error(function()
        registry:get_objects_in_region({ name = "no_bounds" })
    end, "Region must have bounds", "should error on region without bounds")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_units_in_radius filters correctly
print("Test: get_units_in_radius filters correctly")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1, position = { x = 50, y = 50 } }  -- Doodad (no player)
    local u1 = { creation_id = 2, player = 0, position = { x = 60, y = 60 } }  -- Unit
    local u2 = { creation_id = 3, player = 1, position = { x = 70, y = 70 } }  -- Unit

    registry:add_doodad(d1)
    registry:add_unit(u1)
    registry:add_unit(u2)
    registry:enable_spatial_index(512)

    local units = registry:get_units_in_radius(60, 60, 100)
    assert_eq(#units, 2, "should find 2 units")
    assert_true(contains(units, u1), "should contain u1")
    assert_true(contains(units, u2), "should contain u2")

    -- Verify doodad is NOT included
    for _, obj in ipairs(units) do
        if obj == d1 then
            tests_total = tests_total + 1
            print("  FAILED: doodad should not be in units list")
        end
    end
end
print("  PASSED")
-- }}}

-- {{{ Test: get_doodads_in_radius filters correctly
print("Test: get_doodads_in_radius filters correctly")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1, position = { x = 50, y = 50 } }  -- Doodad
    local d2 = { creation_id = 2, position = { x = 60, y = 60 } }  -- Doodad
    local u1 = { creation_id = 3, player = 0, position = { x = 70, y = 70 } }  -- Unit

    registry:add_doodad(d1)
    registry:add_doodad(d2)
    registry:add_unit(u1)
    registry:enable_spatial_index(512)

    local doodads = registry:get_doodads_in_radius(60, 60, 100)
    assert_eq(#doodads, 2, "should find 2 doodads")
    assert_true(contains(doodads, d1), "should contain d1")
    assert_true(contains(doodads, d2), "should contain d2")
end
print("  PASSED")
-- }}}

-- {{{ Test: objects without position not indexed
print("Test: objects without position not indexed")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1 }  -- No position

    registry:add_doodad(d1)
    registry:enable_spatial_index(512)

    -- Should not error, just skip the object
    assert_eq(registry.spatial:get_count(), 0, "should have 0 objects in spatial index")
end
print("  PASSED")
-- }}}

-- {{{ Test: get_objects_in_rect returns correct objects
print("Test: get_objects_in_rect returns correct objects")
do
    local registry = ObjectRegistry.new()
    local d1 = { creation_id = 1, position = { x = 50, y = 50 } }
    local d2 = { creation_id = 2, position = { x = 150, y = 150 } }  -- Outside
    local u1 = { creation_id = 3, player = 0, position = { x = 75, y = 75 } }

    registry:add_doodad(d1)
    registry:add_doodad(d2)
    registry:add_unit(u1)
    registry:enable_spatial_index(512)

    local in_rect = registry:get_objects_in_rect(0, 0, 100, 100)
    assert_eq(#in_rect, 2, "should find 2 objects in rect")
    assert_true(contains(in_rect, d1), "should contain d1")
    assert_true(contains(in_rect, u1), "should contain u1")
end
print("  PASSED")
-- }}}

-- {{{ Test: spatial index count matches
print("Test: spatial index count matches added objects")
do
    local registry = ObjectRegistry.new()

    -- Add objects with positions
    registry:add_doodad({ creation_id = 1, position = { x = 0, y = 0 } })
    registry:add_doodad({ creation_id = 2, position = { x = 100, y = 100 } })
    registry:add_unit({ creation_id = 3, player = 0, position = { x = 200, y = 200 } })
    -- Add object without position (should not be indexed)
    registry:add_doodad({ creation_id = 4 })

    registry:enable_spatial_index(512)

    assert_eq(registry.spatial:get_count(), 3, "spatial index should have 3 objects")
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
