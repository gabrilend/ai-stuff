#!/usr/bin/env lua
-- Test suite for SpatialIndex (Issue 207c)
-- Tests grid-based spatial indexing for proximity queries.
-- Run from project root: luajit src/tests/test_spatial.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local SpatialIndex = require("registry.spatial")

local tests_run = 0
local tests_passed = 0

-- {{{ Test utilities
-- {{{ assert_eq
local function assert_eq(actual, expected, message)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "assertion failed"))
        print(string.format("  expected: %s", tostring(expected)))
        print(string.format("  actual:   %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ assert_near
local function assert_near(actual, expected, epsilon, message)
    tests_run = tests_run + 1
    epsilon = epsilon or 0.001
    if math.abs(actual - expected) < epsilon then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "assertion failed"))
        print(string.format("  expected: %s (within %s)", tostring(expected), tostring(epsilon)))
        print(string.format("  actual:   %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ assert_true
local function assert_true(value, message)
    tests_run = tests_run + 1
    if value then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", message or "expected true"))
        return false
    end
end
-- }}}

-- {{{ make_object
-- Create a test object with position
local function make_object(x, y, id)
    return {
        id = id or ("obj_" .. x .. "_" .. y),
        position = { x = x, y = y },
    }
end
-- }}}

-- {{{ contains
-- Check if array contains object (by reference)
local function contains(array, obj)
    for _, item in ipairs(array) do
        if item == obj then
            return true
        end
    end
    return false
end
-- }}}
-- }}}

-- {{{ Test: SpatialIndex creation
print("Test: SpatialIndex creation")
do
    local spatial = SpatialIndex.new()
    assert_eq(spatial.cell_size, 512, "default cell size should be 512")
    assert_eq(spatial:get_count(), 0, "new index should have 0 objects")
    assert_eq(spatial:get_cell_count(), 0, "new index should have 0 cells")

    local spatial2 = SpatialIndex.new(256)
    assert_eq(spatial2.cell_size, 256, "custom cell size should be 256")
end
print("  PASSED")
-- }}}

-- {{{ Test: insert objects
print("Test: insert objects")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(50, 50)
    local obj2 = make_object(150, 50)
    local obj3 = make_object(50, 150)

    spatial:insert(obj1)
    assert_eq(spatial:get_count(), 1, "count after 1 insert")

    spatial:insert(obj2)
    spatial:insert(obj3)
    assert_eq(spatial:get_count(), 3, "count after 3 inserts")

    -- obj1 is in cell (0,0), obj2 in (1,0), obj3 in (0,1)
    assert_eq(spatial:get_cell_count(), 3, "should have 3 cells")
end
print("  PASSED")
-- }}}

-- {{{ Test: insert multiple objects in same cell
print("Test: insert multiple objects in same cell")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(10, 10, "a")
    local obj2 = make_object(20, 20, "b")
    local obj3 = make_object(30, 30, "c")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)

    assert_eq(spatial:get_count(), 3, "count should be 3")
    assert_eq(spatial:get_cell_count(), 1, "all in same cell")
end
print("  PASSED")
-- }}}

-- {{{ Test: query_radius basic
print("Test: query_radius basic")
do
    local spatial = SpatialIndex.new(100)

    -- Place objects at known positions
    local center = make_object(500, 500, "center")
    local near1 = make_object(550, 500, "near1")   -- 50 units away
    local near2 = make_object(500, 550, "near2")   -- 50 units away
    local far = make_object(700, 700, "far")       -- ~283 units away

    spatial:insert(center)
    spatial:insert(near1)
    spatial:insert(near2)
    spatial:insert(far)

    -- Query with radius 100 - should find center, near1, near2
    local result = spatial:query_radius(500, 500, 100)
    assert_eq(#result, 3, "radius 100 should find 3 objects")
    assert_true(contains(result, center), "should contain center")
    assert_true(contains(result, near1), "should contain near1")
    assert_true(contains(result, near2), "should contain near2")
    assert_true(not contains(result, far), "should not contain far")

    -- Query with radius 50 - should find center and the near ones
    result = spatial:query_radius(500, 500, 50)
    assert_eq(#result, 3, "radius 50 should find 3 objects (exactly on boundary)")

    -- Query with radius 49 - should only find center
    result = spatial:query_radius(500, 500, 49)
    assert_eq(#result, 1, "radius 49 should find 1 object")
    assert_true(contains(result, center), "should contain center")
end
print("  PASSED")
-- }}}

-- {{{ Test: query_radius at origin
print("Test: query_radius at origin")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(0, 0, "origin")
    local obj2 = make_object(10, 10, "near_origin")
    local obj3 = make_object(-20, -20, "negative")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)

    local result = spatial:query_radius(0, 0, 50)
    assert_eq(#result, 3, "should find all 3 near origin")
end
print("  PASSED")
-- }}}

-- {{{ Test: query_radius with negative coordinates
print("Test: query_radius with negative coordinates")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(-500, -500, "neg")
    local obj2 = make_object(-450, -500, "neg_near")
    local obj3 = make_object(500, 500, "pos")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)

    local result = spatial:query_radius(-500, -500, 100)
    assert_eq(#result, 2, "should find 2 in negative quadrant")
    assert_true(contains(result, obj1), "should contain obj1")
    assert_true(contains(result, obj2), "should contain obj2")
    assert_true(not contains(result, obj3), "should not contain obj3")
end
print("  PASSED")
-- }}}

-- {{{ Test: query_rect basic
print("Test: query_rect basic")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(50, 50, "inside")
    local obj2 = make_object(150, 50, "outside_right")
    local obj3 = make_object(50, 150, "outside_top")
    local obj4 = make_object(100, 100, "on_boundary")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)
    spatial:insert(obj4)

    -- Query rect from (0,0) to (100,100)
    local result = spatial:query_rect(0, 0, 100, 100)
    assert_eq(#result, 2, "rect should find 2 objects")
    assert_true(contains(result, obj1), "should contain inside")
    assert_true(contains(result, obj4), "should contain boundary")
    assert_true(not contains(result, obj2), "should not contain outside_right")
    assert_true(not contains(result, obj3), "should not contain outside_top")
end
print("  PASSED")
-- }}}

-- {{{ Test: query_rect spanning multiple cells
print("Test: query_rect spanning multiple cells")
do
    local spatial = SpatialIndex.new(100)

    -- Place objects in different cells
    local obj1 = make_object(50, 50, "cell_0_0")
    local obj2 = make_object(150, 50, "cell_1_0")
    local obj3 = make_object(250, 50, "cell_2_0")
    local obj4 = make_object(50, 150, "cell_0_1")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)
    spatial:insert(obj4)

    -- Query rect spanning cells (0,0) to (1,1)
    local result = spatial:query_rect(0, 0, 200, 200)
    assert_eq(#result, 3, "should find 3 objects in rect")
    assert_true(contains(result, obj1), "should contain cell_0_0")
    assert_true(contains(result, obj2), "should contain cell_1_0")
    assert_true(contains(result, obj4), "should contain cell_0_1")
    assert_true(not contains(result, obj3), "should not contain cell_2_0")
end
print("  PASSED")
-- }}}

-- {{{ Test: query_point
print("Test: query_point")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(50, 50, "a")
    local obj2 = make_object(60, 60, "b")
    local obj3 = make_object(150, 150, "c")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)

    -- Query point in cell (0,0)
    local result = spatial:query_point(50, 50)
    assert_eq(#result, 2, "should find 2 in same cell")
    assert_true(contains(result, obj1), "should contain obj1")
    assert_true(contains(result, obj2), "should contain obj2")

    -- Query point in cell (1,1)
    result = spatial:query_point(150, 150)
    assert_eq(#result, 1, "should find 1 in other cell")
    assert_true(contains(result, obj3), "should contain obj3")

    -- Query empty cell
    result = spatial:query_point(500, 500)
    assert_eq(#result, 0, "empty cell should return empty array")
end
print("  PASSED")
-- }}}

-- {{{ Test: remove object
print("Test: remove object")
do
    local spatial = SpatialIndex.new(100)

    local obj1 = make_object(50, 50, "a")
    local obj2 = make_object(60, 60, "b")

    spatial:insert(obj1)
    spatial:insert(obj2)
    assert_eq(spatial:get_count(), 2, "should have 2 objects")

    local removed = spatial:remove(obj1)
    assert_true(removed, "remove should return true")
    assert_eq(spatial:get_count(), 1, "should have 1 object after remove")

    local result = spatial:query_point(50, 50)
    assert_eq(#result, 1, "should only find obj2")
    assert_true(contains(result, obj2), "should contain obj2")
    assert_true(not contains(result, obj1), "should not contain obj1")

    -- Try removing again
    removed = spatial:remove(obj1)
    assert_true(not removed, "second remove should return false")
end
print("  PASSED")
-- }}}

-- {{{ Test: clear
print("Test: clear")
do
    local spatial = SpatialIndex.new(100)

    spatial:insert(make_object(50, 50))
    spatial:insert(make_object(150, 150))
    spatial:insert(make_object(250, 250))

    assert_eq(spatial:get_count(), 3, "should have 3 before clear")

    spatial:clear()

    assert_eq(spatial:get_count(), 0, "should have 0 after clear")
    assert_eq(spatial:get_cell_count(), 0, "should have 0 cells after clear")
end
print("  PASSED")
-- }}}

-- {{{ Test: debug_info
print("Test: debug_info")
do
    local spatial = SpatialIndex.new(100)

    -- Empty index
    local info = spatial:debug_info()
    assert_eq(info.cell_size, 100, "cell_size")
    assert_eq(info.object_count, 0, "object_count empty")
    assert_eq(info.cell_count, 0, "cell_count empty")

    -- Add some objects
    spatial:insert(make_object(50, 50, "a"))
    spatial:insert(make_object(60, 60, "b"))  -- same cell
    spatial:insert(make_object(150, 150, "c"))  -- different cell

    info = spatial:debug_info()
    assert_eq(info.object_count, 3, "object_count")
    assert_eq(info.cell_count, 2, "cell_count")
    assert_eq(info.max_per_cell, 2, "max_per_cell")
    assert_eq(info.min_per_cell, 1, "min_per_cell")
    assert_near(info.avg_per_cell, 1.5, 0.01, "avg_per_cell")
end
print("  PASSED")
-- }}}

-- {{{ Test: large cell size
print("Test: large cell size")
do
    local spatial = SpatialIndex.new(10000)  -- Very large cells

    -- All objects should end up in same cell
    spatial:insert(make_object(100, 100))
    spatial:insert(make_object(500, 500))
    spatial:insert(make_object(1000, 1000))

    assert_eq(spatial:get_cell_count(), 1, "all in one large cell")

    local result = spatial:query_radius(500, 500, 1000)
    assert_eq(#result, 3, "should find all in radius")
end
print("  PASSED")
-- }}}

-- {{{ Test: small cell size
print("Test: small cell size")
do
    local spatial = SpatialIndex.new(10)  -- Very small cells

    spatial:insert(make_object(5, 5))
    spatial:insert(make_object(15, 5))
    spatial:insert(make_object(25, 5))

    assert_eq(spatial:get_cell_count(), 3, "each in separate small cell")

    -- Query should still work across cells
    local result = spatial:query_radius(15, 5, 20)
    assert_eq(#result, 3, "should find all in radius")
end
print("  PASSED")
-- }}}

-- {{{ Test: objects on cell boundaries
print("Test: objects on cell boundaries")
do
    local spatial = SpatialIndex.new(100)

    -- Objects exactly on cell boundaries
    local obj1 = make_object(100, 100, "boundary")  -- On boundary of cells (0,0), (1,0), (0,1), (1,1)
    local obj2 = make_object(99, 99, "just_inside")
    local obj3 = make_object(101, 101, "just_outside")

    spatial:insert(obj1)
    spatial:insert(obj2)
    spatial:insert(obj3)

    -- obj1 at (100,100) should be in cell (1,1) since floor(100/100) = 1
    -- obj2 at (99,99) should be in cell (0,0)
    -- obj3 at (101,101) should be in cell (1,1)
    assert_eq(spatial:get_cell_count(), 2, "should have 2 cells")

    -- Query centered on boundary with radius 5
    -- obj1 at (100,100): distance 0
    -- obj2 at (99,99): distance sqrt(2) ≈ 1.4
    -- obj3 at (101,101): distance sqrt(2) ≈ 1.4
    local result = spatial:query_radius(100, 100, 5)
    assert_eq(#result, 3, "should find all 3 within radius 5")
    assert_true(contains(result, obj1), "should contain boundary obj")
    assert_true(contains(result, obj2), "should contain just_inside")
    assert_true(contains(result, obj3), "should contain just_outside")
end
print("  PASSED")
-- }}}

-- {{{ Test: empty query results
print("Test: empty query results")
do
    local spatial = SpatialIndex.new(100)

    -- Empty index queries
    local result = spatial:query_radius(500, 500, 100)
    assert_eq(#result, 0, "radius query on empty index")

    result = spatial:query_rect(0, 0, 1000, 1000)
    assert_eq(#result, 0, "rect query on empty index")

    result = spatial:query_point(500, 500)
    assert_eq(#result, 0, "point query on empty index")

    -- Add objects far away
    spatial:insert(make_object(5000, 5000))

    result = spatial:query_radius(0, 0, 100)
    assert_eq(#result, 0, "radius query with no nearby objects")

    result = spatial:query_rect(0, 0, 100, 100)
    assert_eq(#result, 0, "rect query with no objects in range")
end
print("  PASSED")
-- }}}

-- {{{ Test: error handling
print("Test: error handling")
do
    local spatial = SpatialIndex.new(100)

    -- Object without position should error
    local success, err = pcall(function()
        spatial:insert({ id = "no_position" })
    end)
    assert_true(not success, "should error on missing position")

    -- Object with incomplete position should error
    success, err = pcall(function()
        spatial:insert({ position = { x = 100 } })  -- missing y
    end)
    assert_true(not success, "should error on missing y")

    success, err = pcall(function()
        spatial:insert({ position = { y = 100 } })  -- missing x
    end)
    assert_true(not success, "should error on missing x")
end
print("  PASSED")
-- }}}

-- {{{ Test: diagonal distance calculation
print("Test: diagonal distance calculation")
do
    local spatial = SpatialIndex.new(100)

    -- Object at diagonal distance
    -- sqrt(100^2 + 100^2) = sqrt(20000) ≈ 141.4
    local center = make_object(0, 0, "center")
    local diagonal = make_object(100, 100, "diagonal")

    spatial:insert(center)
    spatial:insert(diagonal)

    -- Radius 141 should not include diagonal
    local result = spatial:query_radius(0, 0, 141)
    assert_eq(#result, 1, "radius 141 should only find center")

    -- Radius 142 should include diagonal
    result = spatial:query_radius(0, 0, 142)
    assert_eq(#result, 2, "radius 142 should find both")
end
print("  PASSED")
-- }}}

-- {{{ Summary
print("")
print("========================================")
print(string.format("Tests passed: %d / %d", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests PASSED!")
    os.exit(0)
else
    print("Some tests FAILED!")
    os.exit(1)
end
-- }}}
