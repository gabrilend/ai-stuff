# Issue #025: Test Movement with Multiple Units Per Lane

## Current Behavior
Individual movement systems exist but comprehensive testing with multiple units in the same lane is needed to ensure smooth interaction and performance.

## Intended Behavior
Multiple units should move smoothly within the same lane while maintaining proper spacing, formation, and avoiding conflicts through coordinated movement behaviors.

## Implementation Details

### Movement Test System (src/systems/movement_test_system.lua)
```lua
-- {{{ local function run_movement_stress_test
local function run_movement_stress_test(test_config)
    local test_results = {
        test_name = test_config.name,
        start_time = love.timer.getTime(),
        units_spawned = 0,
        collisions_detected = 0,
        performance_metrics = {},
        behavior_observations = {}
    }
    
    -- Create test scenario
    setup_test_scenario(test_config)
    
    -- Spawn test units
    local test_units = spawn_test_units(test_config)
    test_results.units_spawned = #test_units
    
    -- Run test for specified duration
    run_test_simulation(test_units, test_config.duration, test_results)
    
    -- Analyze results
    analyze_test_results(test_results, test_units)
    
    -- Cleanup
    cleanup_test_scenario(test_units)
    
    return test_results
end
-- }}}

-- {{{ local function setup_test_scenario
local function setup_test_scenario(config)
    -- Clear any existing units
    clear_all_units()
    
    -- Setup specific map configuration for testing
    if config.map_type == "single_lane" then
        setup_single_lane_test()
    elseif config.map_type == "multiple_lanes" then
        setup_multiple_lane_test()
    elseif config.map_type == "curved_path" then
        setup_curved_path_test()
    elseif config.map_type == "narrow_passage" then
        setup_narrow_passage_test()
    end
    
    -- Configure test environment
    configure_test_environment(config)
end
-- }}}

-- {{{ local function spawn_test_units
local function spawn_test_units(config)
    local test_units = {}
    local spawn_interval = config.spawn_interval or 0.5
    
    for i = 1, config.unit_count do
        -- Create test unit template
        local template = create_test_unit_template(config.unit_type, i)
        
        -- Find spawn point
        local spawn_point = get_test_spawn_point(config.team_id or 1)
        
        -- Spawn with delay to simulate realistic deployment
        local spawn_time = (i - 1) * spawn_interval
        
        schedule_unit_spawn(template, spawn_point.id, spawn_time, function(unit_id)
            table.insert(test_units, unit_id)
            
            -- Add test-specific components
            add_test_tracking_component(unit_id, i)
        end)
    end
    
    return test_units
end
-- }}}

-- {{{ local function add_test_tracking_component
local function add_test_tracking_component(unit_id, test_index)
    EntityManager:add_component(unit_id, "test_tracking", {
        test_index = test_index,
        spawn_time = love.timer.getTime(),
        positions_recorded = {},
        collision_count = 0,
        stuck_time = 0,
        last_position_time = 0,
        performance_samples = {}
    })
end
-- }}}

-- {{{ local function run_test_simulation
local function run_test_simulation(test_units, duration, test_results)
    local simulation_start = love.timer.getTime()
    local last_update = simulation_start
    
    while love.timer.getTime() - simulation_start < duration do
        local current_time = love.timer.getTime()
        local dt = current_time - last_update
        last_update = current_time
        
        -- Update all systems
        update_test_systems(dt)
        
        -- Record performance metrics
        record_performance_metrics(test_results, current_time)
        
        -- Check for issues
        check_movement_issues(test_units, test_results)
        
        -- Record unit states
        record_unit_states(test_units, current_time)
        
        -- Prevent infinite loops in testing
        love.timer.sleep(0.016)  -- ~60 FPS
    end
end
-- }}}

-- {{{ local function check_movement_issues
local function check_movement_issues(test_units, test_results)
    for _, unit_id in ipairs(test_units) do
        local position = EntityManager:get_component(unit_id, "position")
        local test_tracking = EntityManager:get_component(unit_id, "test_tracking")
        local moveable = EntityManager:get_component(unit_id, "moveable")
        
        if position and test_tracking and moveable then
            -- Check for collisions
            local collisions = detect_unit_collisions(unit_id)
            if #collisions > 0 then
                test_tracking.collision_count = test_tracking.collision_count + #collisions
                test_results.collisions_detected = test_results.collisions_detected + #collisions
            end
            
            -- Check for stuck units
            check_if_unit_stuck(unit_id, test_tracking)
            
            -- Check for boundary violations
            check_boundary_violations(unit_id, test_results)
            
            -- Record position for path analysis
            record_position_sample(unit_id, test_tracking, position)
        end
    end
end
-- }}}

-- {{{ local function detect_unit_collisions
local function detect_unit_collisions(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not unit_data then
        return {}
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local unit_size = unit_data.size or 8
    local collisions = {}
    
    -- Check against other units in same sub-path
    local units_in_path = get_units_in_sub_path(position.sub_path_id)
    
    for _, other_unit_id in ipairs(units_in_path) do
        if other_unit_id ~= unit_id then
            local other_position = EntityManager:get_component(other_unit_id, "position")
            local other_unit_data = EntityManager:get_component(other_unit_id, "unit")
            
            if other_position and other_unit_data then
                local other_pos = Vector2:new(other_position.x, other_position.y)
                local other_size = other_unit_data.size or 8
                
                local distance = unit_pos:distance_to(other_pos)
                local min_distance = (unit_size + other_size) / 2
                
                if distance < min_distance then
                    table.insert(collisions, {
                        other_unit_id = other_unit_id,
                        overlap_distance = min_distance - distance
                    })
                end
            end
        end
    end
    
    return collisions
end
-- }}}

-- {{{ local function check_if_unit_stuck
local function check_if_unit_stuck(unit_id, test_tracking)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not position or not moveable then
        return
    end
    
    local current_time = love.timer.getTime()
    local current_pos = Vector2:new(position.x, position.y)
    
    -- Check if unit has moved significantly
    if #test_tracking.positions_recorded > 0 then
        local last_recorded = test_tracking.positions_recorded[#test_tracking.positions_recorded]
        local distance_moved = current_pos:distance_to(last_recorded.position)
        local time_elapsed = current_time - last_recorded.time
        
        -- Consider stuck if moved less than 5 units in 2 seconds while trying to move
        if distance_moved < 5 and time_elapsed > 2.0 and moveable.is_moving then
            test_tracking.stuck_time = test_tracking.stuck_time + time_elapsed
        else
            test_tracking.stuck_time = 0  -- Reset if moving normally
        end
    end
end
-- }}}

-- {{{ local function record_position_sample
local function record_position_sample(unit_id, test_tracking, position)
    local current_time = love.timer.getTime()
    
    -- Record position every 0.5 seconds
    if current_time - test_tracking.last_position_time > 0.5 then
        table.insert(test_tracking.positions_recorded, {
            time = current_time,
            position = Vector2:new(position.x, position.y),
            sub_path_id = position.sub_path_id
        })
        
        test_tracking.last_position_time = current_time
        
        -- Limit recorded positions to prevent memory issues
        if #test_tracking.positions_recorded > 50 then
            table.remove(test_tracking.positions_recorded, 1)
        end
    end
end
-- }}}

-- {{{ local function analyze_test_results
local function analyze_test_results(test_results, test_units)
    test_results.end_time = love.timer.getTime()
    test_results.total_duration = test_results.end_time - test_results.start_time
    
    -- Analyze unit behaviors
    local stuck_units = 0
    local units_reached_goal = 0
    local average_speed = 0
    local total_collisions = 0
    
    for _, unit_id in ipairs(test_units) do
        local test_tracking = EntityManager:get_component(unit_id, "test_tracking")
        if test_tracking then
            -- Count stuck units
            if test_tracking.stuck_time > 5.0 then
                stuck_units = stuck_units + 1
            end
            
            -- Count successful units
            if unit_reached_destination(unit_id) then
                units_reached_goal = units_reached_goal + 1
            end
            
            -- Calculate average speed
            average_speed = average_speed + calculate_unit_average_speed(test_tracking)
            
            -- Sum collisions
            total_collisions = total_collisions + test_tracking.collision_count
        end
    end
    
    -- Store analysis results
    test_results.stuck_units = stuck_units
    test_results.success_rate = units_reached_goal / #test_units
    test_results.average_speed = average_speed / #test_units
    test_results.total_collisions = total_collisions
    test_results.collision_rate = total_collisions / #test_units
    
    -- Performance analysis
    analyze_performance_metrics(test_results)
    
    -- Generate recommendations
    generate_test_recommendations(test_results)
end
-- }}}

-- {{{ local function generate_test_recommendations
local function generate_test_recommendations(test_results)
    local recommendations = {}
    
    if test_results.collision_rate > 0.5 then
        table.insert(recommendations, "High collision rate detected. Consider improving obstacle avoidance.")
    end
    
    if test_results.stuck_units > test_results.units_spawned * 0.1 then
        table.insert(recommendations, "Units getting stuck. Review pathfinding and queueing systems.")
    end
    
    if test_results.success_rate < 0.8 then
        table.insert(recommendations, "Low success rate. Check movement completion logic.")
    end
    
    local avg_fps = calculate_average_fps(test_results.performance_metrics)
    if avg_fps < 30 then
        table.insert(recommendations, "Performance issues detected. Optimize movement calculations.")
    end
    
    test_results.recommendations = recommendations
end
-- }}}

-- {{{ local function create_comprehensive_test_suite
local function create_comprehensive_test_suite()
    local test_configs = {
        {
            name = "Basic Lane Following",
            unit_count = 5,
            unit_type = "mixed",
            map_type = "single_lane",
            duration = 30,
            spawn_interval = 1.0
        },
        {
            name = "High Density Movement",
            unit_count = 20,
            unit_type = "melee",
            map_type = "single_lane",
            duration = 45,
            spawn_interval = 0.2
        },
        {
            name = "Multi-Lane Coordination",
            unit_count = 15,
            unit_type = "mixed",
            map_type = "multiple_lanes",
            duration = 60,
            spawn_interval = 0.5
        },
        {
            name = "Curved Path Navigation",
            unit_count = 10,
            unit_type = "ranged",
            map_type = "curved_path",
            duration = 40,
            spawn_interval = 0.8
        },
        {
            name = "Narrow Passage Test",
            unit_count = 12,
            unit_type = "mixed",
            map_type = "narrow_passage",
            duration = 50,
            spawn_interval = 1.5
        }
    }
    
    return test_configs
end
-- }}}
```

### Testing Features
1. **Stress Testing**: High-density unit scenarios
2. **Collision Detection**: Identify and track unit overlaps
3. **Performance Monitoring**: Track FPS and system performance
4. **Behavior Analysis**: Evaluate movement patterns and success rates
5. **Automated Reporting**: Generate detailed test results and recommendations

### Test Scenarios
- **Basic Lane Following**: Simple movement validation
- **High Density**: Crowding and congestion handling
- **Multi-Lane**: Coordination across multiple paths
- **Curved Paths**: Complex geometry navigation
- **Narrow Passages**: Bottleneck management

### Metrics Tracked
- Collision frequency and severity
- Unit success rates and completion times
- Performance impact with unit count
- Stuck unit detection and recovery
- Formation integrity maintenance

### Tool Suggestions
- Use Write tool to create comprehensive test system
- Run various test scenarios with different unit counts
- Monitor performance metrics during testing
- Analyze results to identify optimization opportunities

### Acceptance Criteria
- [ ] Multiple units move smoothly in same lane without collisions
- [ ] High-density scenarios maintain acceptable performance
- [ ] Formation and spacing are preserved during movement
- [ ] Test suite provides actionable feedback for improvements
- [ ] Edge cases and stress conditions are handled gracefully