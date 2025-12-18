-- {{{ Spawn Point System Test
local TestSuite = {}

-- Create a minimal test environment
local function create_test_unit(id)
    return {
        id = id or 1,
        position = nil,
        state = "ready",
        target_lane = nil,
        target_sub_path = nil,
        spawn_timer = nil,
        path_progress = 0
    }
end

local function create_test_lane(id, start_x, start_y, end_x, end_y)
    return {
        id = id or 1,
        start_x = start_x or 0,
        start_y = start_y or 0,
        end_x = end_x or 100,
        end_y = end_y or 0,
        width = 60
    }
end

local function create_test_renderer()
    return {
        draw_circle = function(x, y, radius, color, mode) end,
        draw_rectangle = function(x, y, width, height, color, mode) end,
        draw_text = function(text, x, y) end
    }
end

-- Test functions
function TestSuite.test_spawn_point_creation()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(100, 100)
    local lanes = {
        create_test_lane(1, 150, 100, 350, 100),
        create_test_lane(2, 150, 200, 350, 200)
    }
    
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    
    assert(spawn_point.player_id == 1, "Player ID should match")
    assert(spawn_point.position.x == 100, "Position X should match")
    assert(spawn_point.position.y == 100, "Position Y should match")
    assert(#spawn_point.connected_lanes == 2, "Should have 2 connected lanes")
    assert(#spawn_point.deployment_areas == 2, "Should have 2 deployment areas")
    assert(spawn_point.active == true, "Should be active by default")
    
    print("✓ Spawn point creation test passed")
end

function TestSuite.test_deployment_area_generation()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {create_test_lane(1, 100, 50, 300, 50)}
    
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    local area = spawn_point.deployment_areas[1]
    
    assert(area.lane_id == 1, "Area should be linked to correct lane")
    assert(area.width == 60, "Area width should match lane width")
    assert(#area.sub_path_slots == 5, "Should have 5 sub-path slots")
    assert(area.max_units == 10, "Should have correct max units")
    assert(area.current_units == 0, "Should start with 0 units")
    
    -- Check sub-path slot spacing
    for i = 1, 5 do
        assert(area.sub_path_slots[i].sub_path_id == i, "Sub-path ID should match index")
        assert(area.sub_path_slots[i].max_queue_size == 3, "Should have correct queue size")
        assert(#area.sub_path_slots[i].queue == 0, "Queue should start empty")
    end
    
    print("✓ Deployment area generation test passed")
end

function TestSuite.test_unit_deployment()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {create_test_lane(1, 100, 50, 300, 50)}
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    
    local unit1 = create_test_unit(1)
    local unit2 = create_test_unit(2)
    local unit3 = create_test_unit(3)
    
    -- Test successful deployment
    assert(spawn_point:can_deploy_unit(1, 3), "Should be able to deploy to empty slot")
    assert(spawn_point:deploy_unit(unit1, 1, 3), "First deployment should succeed")
    assert(unit1.target_lane == 1, "Unit should have correct target lane")
    assert(unit1.target_sub_path == 3, "Unit should have correct sub-path")
    assert(unit1.state == "deploying", "Unit should be in deploying state")
    
    -- Test queue functionality
    assert(spawn_point:deploy_unit(unit2, 1, 3), "Second deployment should succeed")
    assert(spawn_point:deploy_unit(unit3, 1, 3), "Third deployment should succeed")
    
    local area = spawn_point.deployment_areas[1]
    assert(area.current_units == 3, "Should have 3 units deployed")
    assert(#area.sub_path_slots[3].queue == 3, "Sub-path 3 should have 3 units queued")
    
    -- Test capacity limits
    local unit4 = create_test_unit(4)
    assert(not spawn_point:deploy_unit(unit4, 1, 3), "Fourth deployment should fail (queue full)")
    
    print("✓ Unit deployment test passed")
end

function TestSuite.test_spawn_timing()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {create_test_lane(1, 100, 50, 300, 50)}
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    
    local unit1 = create_test_unit(1)
    local unit2 = create_test_unit(2)
    
    spawn_point:deploy_unit(unit1, 1, 1)
    spawn_point:deploy_unit(unit2, 1, 1)
    
    -- Check initial spawn timers
    assert(unit1.spawn_timer > 0, "Unit 1 should have spawn timer")
    assert(unit2.spawn_timer > unit1.spawn_timer, "Unit 2 should have longer timer (staggered)")
    
    -- Simulate time passing
    local initial_timer1 = unit1.spawn_timer
    spawn_point:update(0.5)
    
    assert(unit1.spawn_timer < initial_timer1, "Timer should decrease after update")
    assert(unit1.state == "deploying", "Unit should still be deploying")
    
    -- Simulate enough time for first unit to spawn
    spawn_point:update(1.0)
    
    local area = spawn_point.deployment_areas[1]
    assert(area.current_units == 1, "One unit should have been released")
    assert(#area.sub_path_slots[1].queue == 1, "One unit should remain in queue")
    
    print("✓ Spawn timing test passed")
end

function TestSuite.test_lane_availability()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {
        create_test_lane(1, 100, 50, 300, 50),
        create_test_lane(2, 100, 150, 300, 150)
    }
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    
    -- Test initial availability
    local available = spawn_point:get_available_lanes()
    assert(#available == 2, "Both lanes should be available initially")
    assert(available[1].capacity == 10, "Each lane should have full capacity")
    
    -- Deploy some units
    for i = 1, 5 do
        local unit = create_test_unit(i)
        spawn_point:deploy_unit(unit, 1, 1)
    end
    
    available = spawn_point:get_available_lanes()
    assert(available[1].capacity == 5, "Lane 1 should have reduced capacity")
    assert(available[2].capacity == 10, "Lane 2 should still have full capacity")
    
    print("✓ Lane availability test passed")
end

function TestSuite.test_sub_path_status()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {create_test_lane(1, 100, 50, 300, 50)}
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    
    -- Initial status
    local status = spawn_point:get_sub_path_status(1)
    assert(#status == 5, "Should have status for all 5 sub-paths")
    
    for i = 1, 5 do
        assert(status[i].sub_path_id == i, "Sub-path ID should match")
        assert(status[i].queue_size == 0, "Initial queue should be empty")
        assert(status[i].available == true, "Should be available initially")
    end
    
    -- Deploy units and check status
    for i = 1, 3 do
        local unit = create_test_unit(i)
        spawn_point:deploy_unit(unit, 1, 1)  -- All to sub-path 1
    end
    
    status = spawn_point:get_sub_path_status(1)
    assert(status[1].queue_size == 3, "Sub-path 1 should have 3 units")
    assert(status[1].available == false, "Sub-path 1 should be full")
    assert(status[2].available == true, "Other sub-paths should still be available")
    
    print("✓ Sub-path status test passed")
end

function TestSuite.test_spawn_point_stats()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {
        create_test_lane(1, 100, 50, 300, 50),
        create_test_lane(2, 100, 150, 300, 150)
    }
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    
    local stats = spawn_point:get_stats()
    assert(stats.player_id == 1, "Player ID should match")
    assert(stats.active == true, "Should be active")
    assert(stats.total_capacity == 20, "Total capacity should be 20 (2 lanes × 10)")
    assert(stats.total_deployed == 0, "No units deployed initially")
    assert(stats.available_capacity == 20, "Full capacity available")
    assert(stats.connected_lanes == 2, "Should have 2 connected lanes")
    assert(stats.active_lanes == 0, "No active lanes initially")
    assert(stats.utilization == 0, "No utilization initially")
    
    print("✓ Spawn point stats test passed")
end

function TestSuite.test_visual_rendering()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local position = Vector2:new(50, 50)
    local lanes = {create_test_lane(1, 100, 50, 300, 50)}
    local spawn_point = SpawnPoint:new(position, 1, lanes)
    local renderer = create_test_renderer()
    
    -- Should not crash when drawing
    spawn_point:draw(renderer)
    
    -- Deploy a unit and draw again
    local unit = create_test_unit(1)
    spawn_point:deploy_unit(unit, 1, 1)
    spawn_point:draw(renderer)
    
    print("✓ Visual rendering test passed")
end

function TestSuite.test_performance()
    local Vector2 = require("src.utils.vector2")
    local SpawnPoint = require("src.entities.spawn_point")
    
    local start_time = os.clock()
    
    -- Create multiple spawn points and test operations
    for i = 1, 50 do
        local position = Vector2:new(i * 10, i * 10)
        local lanes = {
            create_test_lane(1, i * 10, i * 10, i * 10 + 100, i * 10),
            create_test_lane(2, i * 10, i * 10 + 50, i * 10 + 100, i * 10 + 50)
        }
        local spawn_point = SpawnPoint:new(position, 1, lanes)
        
        -- Deploy some units
        for j = 1, 5 do
            local unit = create_test_unit(j)
            spawn_point:deploy_unit(unit, 1, (j % 5) + 1)
        end
        
        -- Update spawn point
        spawn_point:update(0.016)  -- Simulate 60 FPS
        
        -- Check stats
        local _ = spawn_point:get_stats()
        local _ = spawn_point:get_available_lanes()
    end
    
    local total_time = os.clock() - start_time
    print(string.format("✓ Performance test passed: %.3fs for 50 spawn points", total_time))
    
    assert(total_time < 1.0, "Performance should be reasonable")
end

function TestSuite.run_all()
    print("Running Spawn Point System Tests...")
    print(string.rep("=", 40))
    
    TestSuite.test_spawn_point_creation()
    TestSuite.test_deployment_area_generation()
    TestSuite.test_unit_deployment()
    TestSuite.test_spawn_timing()
    TestSuite.test_lane_availability()
    TestSuite.test_sub_path_status()
    TestSuite.test_spawn_point_stats()
    TestSuite.test_visual_rendering()
    TestSuite.test_performance()
    
    print(string.rep("=", 40))
    print("✅ All spawn point tests passed!")
end

return TestSuite
-- }}}