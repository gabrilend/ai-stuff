-- {{{ Vector Math Test Suite
local TestSuite = {}

-- Load modules to test
local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local Collision = require("src.utils.collision")

-- Test helper functions
local function assert_approximately_equal(a, b, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("Expected %f, got %f (difference: %f)", a, b, math.abs(a - b)))
    end
end

local function assert_vector_approximately_equal(v1, v2, epsilon)
    epsilon = epsilon or 1e-6
    assert_approximately_equal(v1.x, v2.x, epsilon)
    assert_approximately_equal(v1.y, v2.y, epsilon)
end

-- {{{ Vector2 Tests
function TestSuite.test_vector2_creation()
    local v1 = Vector2:new()
    assert(v1.x == 0 and v1.y == 0, "Default vector should be zero")
    
    local v2 = Vector2:new(3, 4)
    assert(v2.x == 3 and v2.y == 4, "Vector with values should store them")
    
    print("✓ Vector2 creation tests passed")
end

function TestSuite.test_vector2_length()
    local v = Vector2:new(3, 4)
    assert_approximately_equal(v:length(), 5)
    assert_approximately_equal(v:length_squared(), 25)
    
    local zero = Vector2:new(0, 0)
    assert_approximately_equal(zero:length(), 0)
    
    print("✓ Vector2 length tests passed")
end

function TestSuite.test_vector2_normalization()
    local v = Vector2:new(3, 4)
    local normalized = v:normalize()
    assert_approximately_equal(normalized:length(), 1)
    assert_approximately_equal(normalized.x, 0.6)
    assert_approximately_equal(normalized.y, 0.8)
    
    -- Test zero vector normalization
    local zero = Vector2:new(0, 0)
    local zero_norm = zero:normalize()
    assert(zero_norm.x == 0 and zero_norm.y == 0, "Zero vector normalization should return zero")
    
    print("✓ Vector2 normalization tests passed")
end

function TestSuite.test_vector2_arithmetic()
    local v1 = Vector2:new(1, 2)
    local v2 = Vector2:new(3, 4)
    
    -- Addition
    local sum = v1:add(v2)
    assert(sum.x == 4 and sum.y == 6, "Vector addition failed")
    
    -- Subtraction
    local diff = v2:subtract(v1)
    assert(diff.x == 2 and diff.y == 2, "Vector subtraction failed")
    
    -- Multiplication
    local scaled = v1:multiply(3)
    assert(scaled.x == 3 and scaled.y == 6, "Vector scaling failed")
    
    -- Division
    local divided = scaled:divide(3)
    assert_vector_approximately_equal(divided, v1)
    
    print("✓ Vector2 arithmetic tests passed")
end

function TestSuite.test_vector2_operators()
    local v1 = Vector2:new(1, 2)
    local v2 = Vector2:new(3, 4)
    
    -- Operator overloading
    local sum = v1 + v2
    assert(sum.x == 4 and sum.y == 6, "Addition operator failed")
    
    local diff = v2 - v1
    assert(diff.x == 2 and diff.y == 2, "Subtraction operator failed")
    
    local scaled = v1 * 3
    assert(scaled.x == 3 and scaled.y == 6, "Multiplication operator failed")
    
    local dot = v1 * v2
    assert(dot == 11, "Dot product operator failed")
    
    print("✓ Vector2 operator tests passed")
end

function TestSuite.test_vector2_distance()
    local v1 = Vector2:new(0, 0)
    local v2 = Vector2:new(3, 4)
    
    assert_approximately_equal(v1:distance_to(v2), 5)
    assert_approximately_equal(v1:distance_squared_to(v2), 25)
    
    print("✓ Vector2 distance tests passed")
end

function TestSuite.test_vector2_angles()
    local v1 = Vector2:new(1, 0)
    local v2 = Vector2:new(0, 1)
    local v3 = Vector2:new(1, 1)
    
    assert_approximately_equal(v1:angle(), 0)
    assert_approximately_equal(v2:angle(), math.pi / 2)
    
    -- angle_to calculates angle from one point to another
    local origin = Vector2:new(0, 0)
    assert_approximately_equal(origin:angle_to(v1), 0)
    assert_approximately_equal(origin:angle_to(v2), math.pi / 2)
    assert_approximately_equal(origin:angle_to(v3), math.pi / 4)
    
    print("✓ Vector2 angle tests passed")
end

function TestSuite.test_vector2_rotation()
    local v = Vector2:new(1, 0)
    local rotated = v:rotate(math.pi / 2)
    
    assert_approximately_equal(rotated.x, 0, 1e-10)
    assert_approximately_equal(rotated.y, 1, 1e-10)
    
    print("✓ Vector2 rotation tests passed")
end
-- }}}

-- {{{ MathUtils Tests
function TestSuite.test_math_utils_clamp()
    assert(MathUtils.clamp(5, 0, 10) == 5, "Value within range should be unchanged")
    assert(MathUtils.clamp(-5, 0, 10) == 0, "Value below range should be clamped to min")
    assert(MathUtils.clamp(15, 0, 10) == 10, "Value above range should be clamped to max")
    
    print("✓ MathUtils clamp tests passed")
end

function TestSuite.test_math_utils_lerp()
    assert_approximately_equal(MathUtils.lerp(0, 10, 0.5), 5)
    assert_approximately_equal(MathUtils.lerp(0, 10, 0), 0)
    assert_approximately_equal(MathUtils.lerp(0, 10, 1), 10)
    
    print("✓ MathUtils lerp tests passed")
end

function TestSuite.test_math_utils_distance()
    assert_approximately_equal(MathUtils.distance(0, 0, 3, 4), 5)
    assert_approximately_equal(MathUtils.distance_squared(0, 0, 3, 4), 25)
    
    print("✓ MathUtils distance tests passed")
end

function TestSuite.test_math_utils_angles()
    assert_approximately_equal(MathUtils.angle_between(0, 0, 1, 0), 0)
    assert_approximately_equal(MathUtils.angle_between(0, 0, 0, 1), math.pi / 2)
    
    assert_approximately_equal(MathUtils.normalize_angle(3 * math.pi), math.pi)
    assert_approximately_equal(MathUtils.normalize_angle(-3 * math.pi), -math.pi)
    
    print("✓ MathUtils angle tests passed")
end

function TestSuite.test_math_utils_point_tests()
    -- Point in circle
    assert(MathUtils.point_in_circle(1, 1, 0, 0, 2), "Point should be in circle")
    assert(not MathUtils.point_in_circle(3, 3, 0, 0, 2), "Point should be outside circle")
    
    -- Point in rect
    assert(MathUtils.point_in_rect(5, 5, 0, 0, 10, 10), "Point should be in rect")
    assert(not MathUtils.point_in_rect(15, 15, 0, 0, 10, 10), "Point should be outside rect")
    
    -- Point in triangle
    assert(MathUtils.point_in_triangle(1, 1, 0, 0, 2, 0, 1, 2), "Point should be in triangle")
    assert(not MathUtils.point_in_triangle(3, 3, 0, 0, 2, 0, 1, 2), "Point should be outside triangle")
    
    print("✓ MathUtils point tests passed")
end
-- }}}

-- {{{ Collision Tests
function TestSuite.test_collision_circle_circle()
    -- Overlapping circles
    assert(Collision.circle_circle(0, 0, 2, 1, 1, 2), "Circles should be colliding")
    
    -- Non-overlapping circles
    assert(not Collision.circle_circle(0, 0, 1, 5, 5, 1), "Circles should not be colliding")
    
    -- Detailed collision
    local result = Collision.circle_circle_detailed(0, 0, 2, 1, 1, 1)
    assert(result.colliding, "Detailed collision should detect collision")
    assert(result.overlap > 0, "Should have positive overlap")
    
    print("✓ Collision circle-circle tests passed")
end

function TestSuite.test_collision_rect_rect()
    -- Overlapping rects
    assert(Collision.rect_rect(0, 0, 5, 5, 3, 3, 5, 5), "Rects should be colliding")
    
    -- Non-overlapping rects
    assert(not Collision.rect_rect(0, 0, 2, 2, 5, 5, 2, 2), "Rects should not be colliding")
    
    print("✓ Collision rect-rect tests passed")
end

function TestSuite.test_collision_circle_rect()
    -- Circle overlapping rect
    assert(Collision.circle_rect(2, 2, 2, 0, 0, 4, 4), "Circle should overlap rect")
    
    -- Circle not overlapping rect
    assert(not Collision.circle_rect(10, 10, 1, 0, 0, 4, 4), "Circle should not overlap rect")
    
    print("✓ Collision circle-rect tests passed")
end

function TestSuite.test_collision_ray_circle()
    -- Ray hitting circle
    local result = Collision.ray_circle(0, 0, 1, 0, 5, 0, 2)
    assert(result ~= nil, "Ray should hit circle")
    assert_approximately_equal(result.distance, 3)
    
    -- Ray missing circle
    local miss = Collision.ray_circle(0, 0, 1, 0, 0, 5, 1)
    assert(miss == nil, "Ray should miss circle")
    
    print("✓ Collision ray-circle tests passed")
end
-- }}}

-- {{{ Edge Cases and Error Handling Tests
function TestSuite.test_edge_cases()
    -- Zero vectors
    local zero = Vector2:new(0, 0)
    assert_approximately_equal(zero:length(), 0)
    
    local norm_zero = zero:normalize()
    assert(norm_zero.x == 0 and norm_zero.y == 0, "Zero vector normalization should be zero")
    
    -- Division by zero
    local v = Vector2:new(1, 1)
    local result = v:divide(0)
    assert(result.x == 0 and result.y == 0, "Division by zero should return zero vector")
    
    -- Very small numbers
    local tiny = Vector2:new(1e-15, 1e-15)
    local tiny_norm = tiny:normalize()
    assert(tiny_norm:length() >= 0, "Tiny vector normalization should not crash")
    
    -- Large numbers
    local large = Vector2:new(1e10, 1e10)
    local large_norm = large:normalize()
    assert_approximately_equal(large_norm:length(), 1, 1e-6)
    
    print("✓ Edge case tests passed")
end
-- }}}

-- {{{ Performance Tests
function TestSuite.test_performance()
    local start_time = os.clock()
    local iterations = 10000
    
    -- Vector operations performance
    for i = 1, iterations do
        local v1 = Vector2:new(math.random(), math.random())
        local v2 = Vector2:new(math.random(), math.random())
        
        local _ = v1 + v2
        local _ = v1 - v2
        local _ = v1 * 2.5
        local _ = v1:length()
        local _ = v1:normalize()
        local _ = v1:distance_to(v2)
    end
    
    local vector_time = os.clock() - start_time
    
    -- Collision detection performance
    start_time = os.clock()
    for i = 1, iterations do
        local x1, y1, r1 = math.random(100), math.random(100), math.random(10)
        local x2, y2, r2 = math.random(100), math.random(100), math.random(10)
        
        local _ = Collision.circle_circle(x1, y1, r1, x2, y2, r2)
        local _ = Collision.circle_circle_detailed(x1, y1, r1, x2, y2, r2)
    end
    
    local collision_time = os.clock() - start_time
    
    print(string.format("✓ Performance tests completed:"))
    print(string.format("  Vector operations: %.4f seconds for %d iterations", vector_time, iterations))
    print(string.format("  Collision detection: %.4f seconds for %d iterations", collision_time, iterations))
    print(string.format("  Vector ops per second: %.0f", iterations / vector_time))
    print(string.format("  Collision checks per second: %.0f", iterations / collision_time))
end
-- }}}

-- {{{ Run All Tests
function TestSuite.run_all()
    print("Running Vector Math Test Suite...")
    print(string.rep("=", 50))
    
    -- Vector2 tests
    TestSuite.test_vector2_creation()
    TestSuite.test_vector2_length()
    TestSuite.test_vector2_normalization()
    TestSuite.test_vector2_arithmetic()
    TestSuite.test_vector2_operators()
    TestSuite.test_vector2_distance()
    TestSuite.test_vector2_angles()
    TestSuite.test_vector2_rotation()
    
    -- MathUtils tests
    TestSuite.test_math_utils_clamp()
    TestSuite.test_math_utils_lerp()
    TestSuite.test_math_utils_distance()
    TestSuite.test_math_utils_angles()
    TestSuite.test_math_utils_point_tests()
    
    -- Collision tests
    TestSuite.test_collision_circle_circle()
    TestSuite.test_collision_rect_rect()
    TestSuite.test_collision_circle_rect()
    TestSuite.test_collision_ray_circle()
    
    -- Edge cases and performance
    TestSuite.test_edge_cases()
    TestSuite.test_performance()
    
    print(string.rep("=", 50))
    print("✅ All tests passed successfully!")
end
-- }}}

return TestSuite
-- }}}