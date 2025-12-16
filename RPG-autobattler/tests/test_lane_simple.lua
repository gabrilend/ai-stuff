-- {{{ Simple Lane System Test
local TestSuite = {}

-- Create a minimal lane system for testing
local SimpleLane = {}

function SimpleLane:create_lane(start_x, start_y, end_x, end_y, width)
    width = width or 60
    
    local lane = {
        start_x = start_x,
        start_y = start_y,
        end_x = end_x,
        end_y = end_y,
        width = width,
        length = math.sqrt((end_x - start_x)^2 + (end_y - start_y)^2),
        sub_paths = {}
    }
    
    -- Generate 5 sub-paths
    for i = 1, 5 do
        local offset = (i - 3) * (width / 5)  -- -2, -1, 0, 1, 2 spacing
        
        local sub_path = {
            id = i,
            offset = offset,
            start_x = start_x,
            start_y = start_y + offset,
            end_x = end_x,
            end_y = end_y + offset,
            waypoints = {}
        }
        
        -- Generate simple waypoints
        for j = 0, 5 do
            local t = j / 5
            local x = start_x + (end_x - start_x) * t
            local y = (start_y + offset) + ((end_y + offset) - (start_y + offset)) * t
            table.insert(sub_path.waypoints, {x = x, y = y})
        end
        
        lane.sub_paths[i] = sub_path
    end
    
    return lane
end

function SimpleLane:get_position_on_sub_path(sub_path, progress)
    progress = math.max(0, math.min(1, progress))
    
    if #sub_path.waypoints == 0 then
        return {x = 0, y = 0}
    end
    
    local segment_index = math.floor(progress * (#sub_path.waypoints - 1)) + 1
    segment_index = math.min(segment_index, #sub_path.waypoints - 1)
    
    local segment_progress = (progress * (#sub_path.waypoints - 1)) - (segment_index - 1)
    
    local p1 = sub_path.waypoints[segment_index]
    local p2 = sub_path.waypoints[segment_index + 1]
    
    return {
        x = p1.x + (p2.x - p1.x) * segment_progress,
        y = p1.y + (p2.y - p1.y) * segment_progress
    }
end

-- Test functions
function TestSuite.test_basic_lane_creation()
    local lane = SimpleLane:create_lane(0, 100, 200, 100, 60)
    
    assert(lane.start_x == 0, "Start X should match")
    assert(lane.start_y == 100, "Start Y should match")
    assert(lane.end_x == 200, "End X should match")
    assert(lane.end_y == 100, "End Y should match")
    assert(lane.width == 60, "Width should match")
    assert(#lane.sub_paths == 5, "Should have 5 sub-paths")
    
    print("✓ Basic lane creation test passed")
end

function TestSuite.test_sub_path_structure()
    local lane = SimpleLane:create_lane(50, 50, 250, 150, 100)
    
    for i, sub_path in ipairs(lane.sub_paths) do
        assert(sub_path.id == i, "Sub-path should have correct ID")
        assert(#sub_path.waypoints == 6, "Sub-path should have 6 waypoints")
        
        -- Check waypoint progression
        for j = 1, #sub_path.waypoints - 1 do
            local current = sub_path.waypoints[j]
            local next_point = sub_path.waypoints[j + 1]
            assert(current.x < next_point.x, "X should increase along path")
        end
    end
    
    print("✓ Sub-path structure test passed")
end

function TestSuite.test_position_calculation()
    local lane = SimpleLane:create_lane(0, 0, 100, 0, 50)
    local sub_path = lane.sub_paths[3]  -- Center sub-path
    
    local start_pos = SimpleLane:get_position_on_sub_path(sub_path, 0)
    local mid_pos = SimpleLane:get_position_on_sub_path(sub_path, 0.5)
    local end_pos = SimpleLane:get_position_on_sub_path(sub_path, 1)
    
    assert(start_pos.x == 0, "Start position should be at beginning")
    assert(end_pos.x == 100, "End position should be at end")
    assert(mid_pos.x > start_pos.x and mid_pos.x < end_pos.x, "Mid position should be between start and end")
    
    print("✓ Position calculation test passed")
end

function TestSuite.test_sub_path_spacing()
    local lane = SimpleLane:create_lane(0, 100, 200, 100, 100)
    
    -- Check that sub-paths are properly spaced
    local expected_spacing = 100 / 5  -- 20 units
    
    for i = 1, #lane.sub_paths - 1 do
        local sub_path1 = lane.sub_paths[i]
        local sub_path2 = lane.sub_paths[i + 1]
        
        local spacing = sub_path2.start_y - sub_path1.start_y
        assert(math.abs(spacing - expected_spacing) < 1, "Sub-paths should be evenly spaced")
    end
    
    print("✓ Sub-path spacing test passed")
end

function TestSuite.test_performance()
    local start_time = os.clock()
    
    for i = 1, 100 do
        local lane = SimpleLane:create_lane(
            math.random(100), math.random(100),
            math.random(200, 400), math.random(200, 400),
            40 + math.random(40)
        )
        
        for _, sub_path in ipairs(lane.sub_paths) do
            for j = 1, 10 do
                local progress = j / 10
                local _ = SimpleLane:get_position_on_sub_path(sub_path, progress)
            end
        end
    end
    
    local total_time = os.clock() - start_time
    print(string.format("✓ Performance test passed: %.3fs for 100 lanes", total_time))
    
    assert(total_time < 1.0, "Performance should be reasonable")
end

function TestSuite.run_all()
    print("Running Simple Lane System Tests...")
    print(string.rep("=", 40))
    
    TestSuite.test_basic_lane_creation()
    TestSuite.test_sub_path_structure()
    TestSuite.test_position_calculation()
    TestSuite.test_sub_path_spacing()
    TestSuite.test_performance()
    
    print(string.rep("=", 40))
    print("✅ All simple lane tests passed!")
end

return TestSuite
-- }}}