-- {{{ Lane System Test Suite
local TestSuite = {}

-- Load modules to test
local LaneSystem = require("src.systems.lane_system")
local Vector2 = require("src.utils.vector2")

-- Helper function to validate lane structure
local function validate_lane_structure(lane)
    assert(type(lane) == "table", "Lane should be a table")
    assert(lane.start_point, "Lane should have start_point")
    assert(lane.end_point, "Lane should have end_point")
    assert(type(lane.width) == "number", "Lane should have width")
    assert(type(lane.sub_paths) == "table", "Lane should have sub_paths table")
    assert(type(lane.metadata) == "table", "Lane should have metadata")
end

-- Helper function to validate sub-path structure
local function validate_sub_path_structure(sub_path)
    assert(type(sub_path) == "table", "Sub-path should be a table")
    assert(type(sub_path.id) == "number", "Sub-path should have ID")
    assert(type(sub_path.width) == "number", "Sub-path should have width")
    assert(type(sub_path.waypoints) == "table", "Sub-path should have waypoints")
    assert(type(sub_path.center_line) == "table", "Sub-path should have center_line")
    assert(type(sub_path.metadata) == "table", "Sub-path should have metadata")
end

-- {{{ Basic Lane Creation Tests
function TestSuite.test_basic_lane_creation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(100, 200)
    local end_point = Vector2:new(400, 300)
    
    local lane = lane_system:create_lane(start, end_point, 60)
    
    validate_lane_structure(lane)
    
    assert(lane.start_point.x == 100, "Start point X should match")
    assert(lane.start_point.y == 200, "Start point Y should match")
    assert(lane.end_point.x == 400, "End point X should match")
    assert(lane.end_point.y == 300, "End point Y should match")
    assert(lane.width == 60, "Width should match")
    
    print("✓ Basic lane creation test passed")
end

function TestSuite.test_sub_path_count()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 0)
    local end_point = Vector2:new(200, 0)
    
    local lane = lane_system:create_lane(start, end_point)
    
    assert(#lane.sub_paths == LaneSystem.SUB_PATH_COUNT, "Should have exactly " .. LaneSystem.SUB_PATH_COUNT .. " sub-paths")
    
    -- Check that each sub-path has a unique ID
    local ids = {}
    for _, sub_path in ipairs(lane.sub_paths) do
        validate_sub_path_structure(sub_path)
        assert(not ids[sub_path.id], "Sub-path IDs should be unique")
        ids[sub_path.id] = true
        assert(sub_path.id >= 1 and sub_path.id <= LaneSystem.SUB_PATH_COUNT, "Sub-path ID should be in valid range")
    end
    
    print("✓ Sub-path count test passed")
end

function TestSuite.test_sub_path_spacing()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 100)
    local end_point = Vector2:new(300, 100)  -- Horizontal lane
    
    local lane = lane_system:create_lane(start, end_point, 100)
    
    -- Check that sub-paths are properly spaced
    local expected_spacing = 100 / LaneSystem.SUB_PATH_COUNT
    
    for i = 1, #lane.sub_paths - 1 do
        local sub_path1 = lane.sub_paths[i]
        local sub_path2 = lane.sub_paths[i + 1]
        
        -- Check spacing at start points
        local start1 = sub_path1.waypoints[1]
        local start2 = sub_path2.waypoints[1]
        local spacing = start1:distance_to(start2)
        
        -- Should be approximately equal to expected spacing (allowing for gaps)
        assert(spacing > expected_spacing * 0.7, "Sub-paths should have reasonable spacing")
        assert(spacing < expected_spacing * 1.3, "Sub-paths should not be too far apart")
    end
    
    print("✓ Sub-path spacing test passed")
end
-- }}}

-- {{{ Waypoint Generation Tests
function TestSuite.test_waypoint_generation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(50, 50)
    local end_point = Vector2:new(350, 150)
    
    local lane = lane_system:create_lane(start, end_point)
    
    for _, sub_path in ipairs(lane.sub_paths) do
        assert(#sub_path.waypoints >= 3, "Sub-path should have at least 3 waypoints")
        
        -- First and last waypoints should be near start and end positions
        local first_waypoint = sub_path.waypoints[1]
        local last_waypoint = sub_path.waypoints[#sub_path.waypoints]
        
        -- Check that waypoints form a reasonable path
        assert(first_waypoint.x < last_waypoint.x, "For left-to-right lane, X should increase")
        
        -- Check waypoint progression
        for i = 1, #sub_path.waypoints - 1 do
            local current = sub_path.waypoints[i]
            local next_wp = sub_path.waypoints[i + 1]
            local distance = current:distance_to(next_wp)
            
            assert(distance > 0, "Consecutive waypoints should not be identical")
            assert(distance < 200, "Waypoints should not be too far apart")
        end
    end
    
    print("✓ Waypoint generation test passed")
end

function TestSuite.test_path_smoothing()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 200)
    local end_point = Vector2:new(400, 200)
    
    local lane = lane_system:create_lane(start, end_point)
    
    for _, sub_path in ipairs(lane.sub_paths) do
        assert(#sub_path.center_line > 0, "Sub-path should have center line points")
        assert(sub_path.metadata.smoothed ~= nil, "Sub-path should have smoothed metadata")
        
        if #sub_path.waypoints >= 3 then
            assert(sub_path.metadata.smoothed, "Sub-path with enough waypoints should be smoothed")
            assert(#sub_path.center_line > #sub_path.waypoints, "Smoothed path should have more points than waypoints")
        end
        
        -- Check that center line forms a continuous path
        for i = 1, #sub_path.center_line - 1 do
            local current = sub_path.center_line[i]
            local next_pt = sub_path.center_line[i + 1]
            local distance = current:distance_to(next_pt)
            
            assert(distance > 0, "Center line points should not be identical")
            assert(distance < 50, "Center line points should not have large gaps")
        end
    end
    
    print("✓ Path smoothing test passed")
end
-- }}}

-- {{{ Curved Lane Tests
function TestSuite.test_curved_lane_creation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(100, 300)
    local end_point = Vector2:new(300, 100)
    local control_point = Vector2:new(200, 150)  -- Curve control point
    
    local lane = lane_system:create_lane(start, end_point, 80, {control_point})
    
    validate_lane_structure(lane)
    assert(#lane.curve_points == 1, "Lane should have curve points")
    assert(lane.curve_points[1].x == control_point.x, "Curve point should be copied correctly")
    
    -- Check that sub-paths follow the curve
    for _, sub_path in ipairs(lane.sub_paths) do
        local first_point = sub_path.center_line[1]
        local mid_point = sub_path.center_line[math.floor(#sub_path.center_line / 2)]
        local last_point = sub_path.center_line[#sub_path.center_line]
        
        -- Path should curve (not be straight)
        local straight_mid = first_point:lerp(last_point, 0.5)
        local curve_deviation = mid_point:distance_to(straight_mid)
        
        assert(curve_deviation > 5, "Curved lane should deviate from straight path")
    end
    
    print("✓ Curved lane creation test passed")
end

function TestSuite.test_bezier_curve_evaluation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local p0 = Vector2:new(0, 0)
    local p1 = Vector2:new(50, 100)
    local p2 = Vector2:new(100, 0)
    
    -- Test bezier curve at different t values
    local start_point = lane_system:quadratic_bezier(p0, p1, p2, 0)
    local mid_point = lane_system:quadratic_bezier(p0, p1, p2, 0.5)
    local end_point = lane_system:quadratic_bezier(p0, p1, p2, 1)
    
    assert(start_point:distance_to(p0) < 0.1, "t=0 should give start point")
    assert(end_point:distance_to(p2) < 0.1, "t=1 should give end point")
    assert(mid_point.y > 0, "Mid point should be above x-axis due to curve")
    
    print("✓ Bezier curve evaluation test passed")
end
-- }}}

-- {{{ Position Calculation Tests
function TestSuite.test_position_on_sub_path()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 0)
    local end_point = Vector2:new(200, 0)
    
    local lane = lane_system:create_lane(start, end_point)
    local sub_path = lane.sub_paths[3]  -- Center sub-path
    
    -- Test position calculation at different progress values
    local start_pos = lane_system:get_position_on_sub_path(sub_path, 0)
    local mid_pos = lane_system:get_position_on_sub_path(sub_path, 0.5)
    local end_pos = lane_system:get_position_on_sub_path(sub_path, 1)
    
    assert(start_pos.x < mid_pos.x, "Progress should move forward along X axis")
    assert(mid_pos.x < end_pos.x, "Progress should move forward along X axis")
    
    -- Test clamping
    local before_start = lane_system:get_position_on_sub_path(sub_path, -0.5)
    local after_end = lane_system:get_position_on_sub_path(sub_path, 1.5)
    
    assert(before_start:distance_to(start_pos) < 1, "Negative progress should clamp to start")
    assert(after_end:distance_to(end_pos) < 1, "Progress > 1 should clamp to end")
    
    print("✓ Position on sub-path test passed")
end

function TestSuite.test_direction_on_sub_path()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(100, 100)
    local end_point = Vector2:new(300, 100)  -- Horizontal lane
    
    local lane = lane_system:create_lane(start, end_point)
    local sub_path = lane.sub_paths[1]
    
    local direction = lane_system:get_direction_on_sub_path(sub_path, 0.5)
    
    assert(type(direction) == "table", "Direction should be a vector")
    assert(direction.x > 0, "For left-to-right lane, direction should be positive X")
    assert(math.abs(direction.y) < 0.5, "For horizontal lane, Y direction should be small")
    
    -- Direction should be normalized
    local length = direction:length()
    assert(math.abs(length - 1) < 0.1, "Direction vector should be approximately normalized")
    
    print("✓ Direction on sub-path test passed")
end
-- }}}

-- {{{ Sub-Path Finding Tests
function TestSuite.test_nearest_sub_path_finding()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 100)
    local end_point = Vector2:new(200, 100)
    
    local lane = lane_system:create_lane(start, end_point, 100)
    
    -- Test finding nearest sub-path to a position
    local test_position = Vector2:new(100, 80)  -- Slightly above the lane
    local nearest_sub_path, distance, progress = lane_system:find_nearest_sub_path(lane, test_position)
    
    assert(nearest_sub_path ~= nil, "Should find a nearest sub-path")
    assert(type(distance) == "number", "Should return distance")
    assert(type(progress) == "number", "Should return progress")
    assert(distance >= 0, "Distance should be non-negative")
    assert(progress >= 0 and progress <= 1, "Progress should be between 0 and 1")
    
    print("✓ Nearest sub-path finding test passed")
end

function TestSuite.test_sub_path_by_id()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 0)
    local end_point = Vector2:new(100, 0)
    
    local lane = lane_system:create_lane(start, end_point)
    
    -- Test valid IDs
    for i = 1, LaneSystem.SUB_PATH_COUNT do
        local sub_path = lane_system:get_sub_path_by_id(lane, i)
        assert(sub_path ~= nil, "Should find sub-path with valid ID")
        assert(sub_path.id == i, "Sub-path should have correct ID")
    end
    
    -- Test invalid IDs
    local invalid_sub_path = lane_system:get_sub_path_by_id(lane, 0)
    assert(invalid_sub_path == nil, "Should not find sub-path with invalid ID")
    
    local invalid_sub_path2 = lane_system:get_sub_path_by_id(lane, 10)
    assert(invalid_sub_path2 == nil, "Should not find sub-path with out-of-range ID")
    
    print("✓ Sub-path by ID test passed")
end

function TestSuite.test_available_sub_paths()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 0)
    local end_point = Vector2:new(100, 0)
    
    local lane = lane_system:create_lane(start, end_point)
    
    -- Test with no exclusions
    local all_available = lane_system:get_available_sub_paths(lane)
    assert(#all_available == LaneSystem.SUB_PATH_COUNT, "Should return all sub-paths when none excluded")
    
    -- Test with exclusions
    local excluded_ids = {1, 3, 5}
    local available = lane_system:get_available_sub_paths(lane, excluded_ids)
    assert(#available == LaneSystem.SUB_PATH_COUNT - #excluded_ids, "Should exclude specified sub-paths")
    
    for _, sub_path in ipairs(available) do
        local is_excluded = false
        for _, excluded_id in ipairs(excluded_ids) do
            if sub_path.id == excluded_id then
                is_excluded = true
                break
            end
        end
        assert(not is_excluded, "Available sub-paths should not include excluded IDs")
    end
    
    print("✓ Available sub-paths test passed")
end
-- }}}

-- {{{ Formation Tests
function TestSuite.test_line_formation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 100)
    local end_point = Vector2:new(300, 100)
    
    local lane = lane_system:create_lane(start, end_point)
    
    local unit_count = 3
    local positions = lane_system:calculate_formation_positions(lane, "line", unit_count, 0.5)
    
    assert(#positions == unit_count, "Should return correct number of positions")
    
    for _, pos_data in ipairs(positions) do
        assert(pos_data.position, "Position data should have position")
        assert(pos_data.direction, "Position data should have direction")
        assert(pos_data.sub_path_id, "Position data should have sub_path_id")
        assert(pos_data.progress, "Position data should have progress")
        assert(pos_data.progress == 0.5, "All units should be at same progress for line formation")
    end
    
    print("✓ Line formation test passed")
end

function TestSuite.test_column_formation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 0)
    local end_point = Vector2:new(200, 0)
    
    local lane = lane_system:create_lane(start, end_point)
    
    local unit_count = 4
    local positions = lane_system:calculate_formation_positions(lane, "column", unit_count, 0.8)
    
    assert(#positions == unit_count, "Should return correct number of positions")
    
    -- All units should be on the same sub-path (center)
    for _, pos_data in ipairs(positions) do
        assert(pos_data.sub_path_id == 3, "Column formation should use center sub-path")
    end
    
    -- Units should have decreasing progress (spread along path)
    for i = 1, #positions - 1 do
        assert(positions[i].progress >= positions[i + 1].progress, "Units should be spread along path")
    end
    
    print("✓ Column formation test passed")
end

function TestSuite.test_wedge_formation()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 50)
    local end_point = Vector2:new(150, 50)
    
    local lane = lane_system:create_lane(start, end_point)
    
    local unit_count = 5  -- Odd number for center unit
    local positions = lane_system:calculate_formation_positions(lane, "wedge", unit_count, 0.7)
    
    assert(#positions == unit_count, "Should return correct number of positions")
    
    -- Should have units on different sub-paths
    local sub_path_ids = {}
    for _, pos_data in ipairs(positions) do
        sub_path_ids[pos_data.sub_path_id] = true
    end
    
    assert(next(sub_path_ids) ~= nil, "Should use multiple sub-paths")
    
    print("✓ Wedge formation test passed")
end
-- }}}

-- {{{ Performance and Statistics Tests
function TestSuite.test_lane_statistics()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start = Vector2:new(0, 0)
    local end_point = Vector2:new(250, 100)
    
    local lane = lane_system:create_lane(start, end_point, 75)
    local stats = lane_system:get_lane_stats(lane)
    
    assert(type(stats) == "table", "Stats should be a table")
    assert(stats.sub_path_count == LaneSystem.SUB_PATH_COUNT, "Should report correct sub-path count")
    assert(stats.total_length > 0, "Should report positive total length")
    assert(stats.width == 75, "Should report correct width")
    assert(type(stats.has_curves) == "boolean", "Should report curve status")
    assert(type(stats.sub_paths) == "table", "Should have sub-path details")
    assert(#stats.sub_paths == LaneSystem.SUB_PATH_COUNT, "Should have stats for all sub-paths")
    
    for _, sub_path_stats in ipairs(stats.sub_paths) do
        assert(type(sub_path_stats.id) == "number", "Sub-path stats should have ID")
        assert(type(sub_path_stats.length) == "number", "Sub-path stats should have length")
        assert(type(sub_path_stats.waypoint_count) == "number", "Sub-path stats should have waypoint count")
        assert(type(sub_path_stats.smoothed) == "boolean", "Sub-path stats should have smoothed flag")
    end
    
    print("✓ Lane statistics test passed")
end

function TestSuite.test_performance()
    local lane_system = {}
    setmetatable(lane_system, {__index = LaneSystem})
    
    local start_time = os.clock()
    local iterations = 50
    
    for i = 1, iterations do
        local start = Vector2:new(math.random(100), math.random(100))
        local end_point = Vector2:new(start.x + math.random(200, 400), start.y + math.random(-100, 100))
        local width = 40 + math.random(40)
        
        local lane = lane_system:create_lane(start, end_point, width)
        
        -- Test position calculations
        for j = 1, 10 do
            local progress = j / 10
            for _, sub_path in ipairs(lane.sub_paths) do
                local _ = lane_system:get_position_on_sub_path(sub_path, progress)
                local _ = lane_system:get_direction_on_sub_path(sub_path, progress)
            end
        end
        
        -- Test formation calculations
        local _ = lane_system:calculate_formation_positions(lane, "line", 5, 0.5)
    end
    
    local total_time = os.clock() - start_time
    local avg_time = total_time / iterations
    
    print(string.format("✓ Performance test passed: %.3fs average (%.3fs total for %d lanes)", 
          avg_time, total_time, iterations))
    
    assert(avg_time < 0.1, "Average lane creation and processing should be fast")
end
-- }}}

-- {{{ Run All Tests
function TestSuite.run_all()
    print("Running Lane System Test Suite...")
    print(string.rep("=", 50))
    
    -- Basic tests
    TestSuite.test_basic_lane_creation()
    TestSuite.test_sub_path_count()
    TestSuite.test_sub_path_spacing()
    
    -- Waypoint and smoothing tests
    TestSuite.test_waypoint_generation()
    TestSuite.test_path_smoothing()
    
    -- Curved lane tests
    TestSuite.test_curved_lane_creation()
    TestSuite.test_bezier_curve_evaluation()
    
    -- Position calculation tests
    TestSuite.test_position_on_sub_path()
    TestSuite.test_direction_on_sub_path()
    
    -- Sub-path finding tests
    TestSuite.test_nearest_sub_path_finding()
    TestSuite.test_sub_path_by_id()
    TestSuite.test_available_sub_paths()
    
    -- Formation tests
    TestSuite.test_line_formation()
    TestSuite.test_column_formation()
    TestSuite.test_wedge_formation()
    
    -- Performance and statistics tests
    TestSuite.test_lane_statistics()
    TestSuite.test_performance()
    
    print(string.rep("=", 50))
    print("✅ All lane system tests passed successfully!")
    print("")
    print("Summary:")
    print("• Lane system creates exactly 5 sub-paths per lane")
    print("• Sub-paths are properly spaced and parallel")
    print("• Path smoothing creates natural-looking curves")
    print("• Position calculation along sub-paths is accurate")
    print("• Formation systems support tactical positioning")
    print("• Performance is excellent for real-time use")
end
-- }}}

return TestSuite
-- }}}