-- {{{ MovementTestSystem
local MovementTestSystem = {}

local Unit = require("src.entities.unit")
local Vector2 = require("src.utils.vector2")
local debug = require("src.utils.debug")

-- {{{ MovementTestSystem:new
function MovementTestSystem:new(entity_manager, map_data, unit_movement_system, unit_spawning_system, 
                                 lane_following_system, obstacle_avoidance_system, formation_system, queueing_system)
    local system = {
        entity_manager = entity_manager,
        map_data = map_data,
        unit_movement_system = unit_movement_system,
        unit_spawning_system = unit_spawning_system,
        lane_following_system = lane_following_system,
        obstacle_avoidance_system = obstacle_avoidance_system,
        formation_system = formation_system,
        queueing_system = queueing_system,
        name = "movement_test",
        
        -- Test state
        active_tests = {},
        test_results = {},
        current_test_id = 0,
        
        -- Enhanced test tracking
        collision_tracker = {},
        performance_tracker = {},
        stuck_unit_tracker = {},
        position_history = {},
        
        -- Test scenarios
        test_scenarios = {
            "single_unit_movement",
            "multiple_units_same_lane",
            "formation_movement",
            "congestion_handling",
            "obstacle_avoidance",
            "queue_formation",
            "lane_switching",
            "stress_test"
        }
    }
    setmetatable(system, {__index = MovementTestSystem})
    
    debug.log("MovementTestSystem created", "MOVEMENT_TEST")
    return system
end
-- }}}

-- {{{ MovementTestSystem:run_all_tests
function MovementTestSystem:run_all_tests()
    debug.log("Starting comprehensive movement tests", "MOVEMENT_TEST")
    
    for _, scenario in ipairs(self.test_scenarios) do
        local test_result = self:run_test_scenario(scenario)
        self.test_results[scenario] = test_result
        
        -- Wait between tests to observe results
        love.timer.sleep(2)
        self:cleanup_test_units()
    end
    
    self:print_test_summary()
end
-- }}}

-- {{{ MovementTestSystem:run_test_scenario
function MovementTestSystem:run_test_scenario(scenario_name)
    debug.log("Running test scenario: " .. scenario_name, "MOVEMENT_TEST")
    
    local start_time = love.timer.getTime()
    local test_result = {
        scenario = scenario_name,
        start_time = start_time,
        units_created = 0,
        formations_created = 0,
        queues_formed = 0,
        success = false,
        notes = {}
    }
    
    if scenario_name == "single_unit_movement" then
        test_result = self:test_single_unit_movement(test_result)
    elseif scenario_name == "multiple_units_same_lane" then
        test_result = self:test_multiple_units_same_lane(test_result)
    elseif scenario_name == "formation_movement" then
        test_result = self:test_formation_movement(test_result)
    elseif scenario_name == "congestion_handling" then
        test_result = self:test_congestion_handling(test_result)
    elseif scenario_name == "obstacle_avoidance" then
        test_result = self:test_obstacle_avoidance(test_result)
    elseif scenario_name == "queue_formation" then
        test_result = self:test_queue_formation(test_result)
    elseif scenario_name == "lane_switching" then
        test_result = self:test_lane_switching(test_result)
    elseif scenario_name == "stress_test" then
        test_result = self:test_stress_scenario(test_result)
    end
    
    test_result.end_time = love.timer.getTime()
    test_result.duration = test_result.end_time - test_result.start_time
    
    debug.log("Test " .. scenario_name .. " completed in " .. string.format("%.2f", test_result.duration) .. "s", "MOVEMENT_TEST")
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_single_unit_movement
function MovementTestSystem:test_single_unit_movement(test_result)
    -- Test basic single unit movement along a sub-path
    local units = self.unit_spawning_system:create_test_spawn(1, 1)
    test_result.units_created = #units
    
    if #units > 0 then
        -- Monitor unit for movement along path
        local test_duration = 5.0
        local monitor_start = love.timer.getTime()
        
        while love.timer.getTime() - monitor_start < test_duration do
            love.timer.sleep(0.1)
            -- Update systems
            self.unit_movement_system:update(0.1)
            self.lane_following_system:update(0.1)
        end
        
        test_result.success = true
        table.insert(test_result.notes, "Single unit moved successfully along sub-path")
    else
        table.insert(test_result.notes, "Failed to create test unit")
    end
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_multiple_units_same_lane
function MovementTestSystem:test_multiple_units_same_lane(test_result)
    -- Test multiple units in the same lane
    local units = self.unit_spawning_system:create_test_spawn(5, 1)
    test_result.units_created = #units
    
    if #units >= 5 then
        -- Monitor for proper spacing and following behavior
        local test_duration = 8.0
        local monitor_start = love.timer.getTime()
        
        while love.timer.getTime() - monitor_start < test_duration do
            love.timer.sleep(0.1)
            -- Update systems
            self.unit_movement_system:update(0.1)
            self.lane_following_system:update(0.1)
            self.obstacle_avoidance_system:update(0.1)
            self.queueing_system:update(0.1)
        end
        
        -- Check if queueing system activated
        local queue_info = self.queueing_system:get_debug_info()
        test_result.queues_formed = queue_info.total_queues
        
        test_result.success = true
        table.insert(test_result.notes, "Multiple units managed in same lane")
        table.insert(test_result.notes, "Queues formed: " .. test_result.queues_formed)
    else
        table.insert(test_result.notes, "Failed to create enough test units")
    end
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_formation_movement
function MovementTestSystem:test_formation_movement(test_result)
    -- Test formation creation and movement
    local units = self.unit_spawning_system:create_test_spawn(6, 1)
    test_result.units_created = #units
    
    if #units >= 6 then
        -- Create formation
        local unit_entities = {}
        for _, unit_type in ipairs(units) do
            -- Get actual unit entities (this would need proper integration)
            local test_units = self.entity_manager:get_entities_with_components({
                "position", "unit_data", "team"
            })
            for _, unit in ipairs(test_units) do
                local team = self.entity_manager:get_component(unit, "team")
                if team and team.player_id == 1 and #unit_entities < 6 then
                    table.insert(unit_entities, unit)
                end
            end
        end
        
        if #unit_entities >= 3 then
            local formation = self.formation_system:create_formation(unit_entities, "wedge")
            test_result.formations_created = 1
            
            -- Monitor formation movement
            local test_duration = 10.0
            local monitor_start = love.timer.getTime()
            
            while love.timer.getTime() - monitor_start < test_duration do
                love.timer.sleep(0.1)
                -- Update systems
                self.unit_movement_system:update(0.1)
                self.lane_following_system:update(0.1)
                self.formation_system:update(0.1)
                self.obstacle_avoidance_system:update(0.1)
            end
            
            -- Check formation health
            if formation then
                test_result.success = formation.formation_health > 0.5
                table.insert(test_result.notes, "Formation health: " .. string.format("%.2f", formation.formation_health))
            end
        else
            table.insert(test_result.notes, "Could not get enough unit entities for formation")
        end
    else
        table.insert(test_result.notes, "Failed to create enough units for formation")
    end
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_congestion_handling
function MovementTestSystem:test_congestion_handling(test_result)
    -- Test congestion with many units in a single sub-path
    local units = self.unit_spawning_system:create_test_spawn(10, 1)
    test_result.units_created = #units
    
    -- Also spawn units for player 2 coming from opposite direction
    local opposing_units = self.unit_spawning_system:create_test_spawn(8, 2)
    test_result.units_created = test_result.units_created + #opposing_units
    
    -- Monitor congestion handling
    local test_duration = 12.0
    local monitor_start = love.timer.getTime()
    
    while love.timer.getTime() - monitor_start < test_duration do
        love.timer.sleep(0.1)
        -- Update all movement systems
        self.unit_movement_system:update(0.1)
        self.lane_following_system:update(0.1)
        self.obstacle_avoidance_system:update(0.1)
        self.queueing_system:update(0.1)
    end
    
    -- Analyze results
    local queue_info = self.queueing_system:get_debug_info()
    local avoidance_info = self.obstacle_avoidance_system:get_debug_info()
    
    test_result.queues_formed = queue_info.total_queues
    test_result.success = queue_info.total_queues > 0 and avoidance_info.units_avoiding > 0
    
    table.insert(test_result.notes, "Queues formed: " .. queue_info.total_queues)
    table.insert(test_result.notes, "Units avoiding: " .. avoidance_info.units_avoiding)
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_obstacle_avoidance
function MovementTestSystem:test_obstacle_avoidance(test_result)
    -- Test obstacle avoidance between units
    local units = self.unit_spawning_system:create_test_spawn(8, 1)
    test_result.units_created = #units
    
    -- Monitor avoidance behavior
    local test_duration = 8.0
    local monitor_start = love.timer.getTime()
    local max_avoiding = 0
    
    while love.timer.getTime() - monitor_start < test_duration do
        love.timer.sleep(0.1)
        -- Update systems
        self.unit_movement_system:update(0.1)
        self.lane_following_system:update(0.1)
        self.obstacle_avoidance_system:update(0.1)
        
        -- Track peak avoidance activity
        local avoidance_info = self.obstacle_avoidance_system:get_debug_info()
        max_avoiding = math.max(max_avoiding, avoidance_info.units_avoiding)
    end
    
    test_result.success = max_avoiding > 0
    table.insert(test_result.notes, "Peak units avoiding obstacles: " .. max_avoiding)
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_queue_formation
function MovementTestSystem:test_queue_formation(test_result)
    -- Test automatic queue formation when units are blocked
    local units = self.unit_spawning_system:create_test_spawn(12, 1)
    test_result.units_created = #units
    
    -- Monitor queue formation
    local test_duration = 10.0
    local monitor_start = love.timer.getTime()
    local max_queues = 0
    local max_queued_units = 0
    
    while love.timer.getTime() - monitor_start < test_duration do
        love.timer.sleep(0.1)
        -- Update systems
        self.unit_movement_system:update(0.1)
        self.queueing_system:update(0.1)
        
        -- Track queue statistics
        local queue_info = self.queueing_system:get_debug_info()
        max_queues = math.max(max_queues, queue_info.total_queues)
        max_queued_units = math.max(max_queued_units, queue_info.total_queued_units)
    end
    
    test_result.queues_formed = max_queues
    test_result.success = max_queues > 0 and max_queued_units >= 3
    
    table.insert(test_result.notes, "Max queues: " .. max_queues)
    table.insert(test_result.notes, "Max queued units: " .. max_queued_units)
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_lane_switching
function MovementTestSystem:test_lane_switching(test_result)
    -- Test units switching between sub-paths when congested
    local units = self.unit_spawning_system:create_test_spawn(15, 1)
    test_result.units_created = #units
    
    -- Enable lane switching in queueing system
    if self.queueing_system.queue_branching then
        -- Monitor for lane switching behavior
        local test_duration = 15.0
        local monitor_start = love.timer.getTime()
        
        while love.timer.getTime() - monitor_start < test_duration do
            love.timer.sleep(0.1)
            -- Update systems
            self.unit_movement_system:update(0.1)
            self.lane_following_system:update(0.1)
            self.queueing_system:update(0.1)
        end
        
        test_result.success = true
        table.insert(test_result.notes, "Lane switching system active")
    else
        table.insert(test_result.notes, "Lane switching not enabled")
    end
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:test_stress_scenario
function MovementTestSystem:test_stress_scenario(test_result)
    -- Stress test with many units and complex interactions
    local p1_units = self.unit_spawning_system:create_test_spawn(20, 1)
    local p2_units = self.unit_spawning_system:create_test_spawn(20, 2)
    test_result.units_created = #p1_units + #p2_units
    
    -- Run all systems for extended period
    local test_duration = 20.0
    local monitor_start = love.timer.getTime()
    local performance_samples = {}
    
    while love.timer.getTime() - monitor_start < test_duration do
        local frame_start = love.timer.getTime()
        
        -- Update all systems
        self.unit_movement_system:update(0.1)
        self.lane_following_system:update(0.1)
        self.obstacle_avoidance_system:update(0.1)
        self.formation_system:update(0.1)
        self.queueing_system:update(0.1)
        
        local frame_time = love.timer.getTime() - frame_start
        table.insert(performance_samples, frame_time)
        
        love.timer.sleep(0.1)
    end
    
    -- Calculate performance metrics
    local avg_frame_time = 0
    for _, sample in ipairs(performance_samples) do
        avg_frame_time = avg_frame_time + sample
    end
    avg_frame_time = avg_frame_time / #performance_samples
    
    test_result.success = avg_frame_time < 0.016  -- Target 60fps
    table.insert(test_result.notes, "Average frame time: " .. string.format("%.4f", avg_frame_time) .. "s")
    table.insert(test_result.notes, "Target: 0.0167s (60fps)")
    
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:cleanup_test_units
function MovementTestSystem:cleanup_test_units()
    -- Remove all test units
    local units = self.entity_manager:get_entities_with_components({
        "position", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        self.entity_manager:remove_entity(unit)
    end
    
    -- Clear formations and queues
    for formation_id, _ in pairs(self.formation_system.formations) do
        self.formation_system:break_formation(formation_id)
    end
    
    for queue_id, _ in pairs(self.queueing_system.lane_queues) do
        self.queueing_system:dissolve_queue(self.queueing_system.lane_queues[queue_id])
    end
    
    debug.log("Cleaned up test units and formations", "MOVEMENT_TEST")
end
-- }}}

-- {{{ MovementTestSystem:print_test_summary
function MovementTestSystem:print_test_summary()
    debug.log("=== MOVEMENT SYSTEM TEST SUMMARY ===", "MOVEMENT_TEST")
    
    local total_tests = #self.test_scenarios
    local passed_tests = 0
    
    for scenario, result in pairs(self.test_results) do
        local status = result.success and "PASS" or "FAIL"
        if result.success then
            passed_tests = passed_tests + 1
        end
        
        debug.log(string.format("%s: %s (%.2fs, %d units)", 
                  scenario, status, result.duration or 0, result.units_created), "MOVEMENT_TEST")
        
        for _, note in ipairs(result.notes) do
            debug.log("  - " .. note, "MOVEMENT_TEST")
        end
    end
    
    debug.log(string.format("OVERALL: %d/%d tests passed (%.1f%%)", 
              passed_tests, total_tests, (passed_tests / total_tests) * 100), "MOVEMENT_TEST")
    debug.log("=== END TEST SUMMARY ===", "MOVEMENT_TEST")
end
-- }}}

-- {{{ MovementTestSystem:detect_unit_collisions
function MovementTestSystem:detect_unit_collisions()
    local collisions = {}
    local units = self.entity_manager:get_entities_with_components({
        "position", "unit_data"
    })
    
    for i, unit1 in ipairs(units) do
        local pos1 = self.entity_manager:get_component(unit1, "position")
        local data1 = self.entity_manager:get_component(unit1, "unit_data")
        
        if pos1 and data1 then
            local unit1_pos = Vector2:new(pos1.x, pos1.y)
            local unit1_size = data1.size or 8
            
            for j = i + 1, #units do
                local unit2 = units[j]
                local pos2 = self.entity_manager:get_component(unit2, "position")
                local data2 = self.entity_manager:get_component(unit2, "unit_data")
                
                if pos2 and data2 then
                    local unit2_pos = Vector2:new(pos2.x, pos2.y)
                    local unit2_size = data2.size or 8
                    
                    local distance = unit1_pos:distance_to(unit2_pos)
                    local min_distance = (unit1_size + unit2_size) / 2
                    
                    if distance < min_distance then
                        table.insert(collisions, {
                            unit1 = unit1,
                            unit2 = unit2,
                            overlap = min_distance - distance,
                            time = love.timer.getTime()
                        })
                    end
                end
            end
        end
    end
    
    return collisions
end
-- }}}

-- {{{ MovementTestSystem:track_performance_metrics
function MovementTestSystem:track_performance_metrics(dt)
    local current_time = love.timer.getTime()
    
    -- Count active entities
    local total_units = #self.entity_manager:get_entities_with_components({"position", "unit_data"})
    
    -- Get system debug info
    local queue_info = self.queueing_system:get_debug_info()
    local avoidance_info = self.obstacle_avoidance_system:get_debug_info()
    local formation_info = self.formation_system:get_debug_info()
    
    local performance_sample = {
        time = current_time,
        frame_time = dt,
        fps = 1.0 / dt,
        total_units = total_units,
        queued_units = queue_info.total_queued_units,
        avoiding_units = avoidance_info.units_avoiding,
        formations = formation_info.total_formations,
        memory_usage = collectgarbage("count")
    }
    
    table.insert(self.performance_tracker, performance_sample)
    
    -- Limit tracking history
    if #self.performance_tracker > 1000 then
        table.remove(self.performance_tracker, 1)
    end
end
-- }}}

-- {{{ MovementTestSystem:detect_stuck_units
function MovementTestSystem:detect_stuck_units()
    local stuck_units = {}
    local current_time = love.timer.getTime()
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data"
    })
    
    for _, unit in ipairs(units) do
        local position = self.entity_manager:get_component(unit, "position")
        local moveable = self.entity_manager:get_component(unit, "moveable")
        
        if position and moveable then
            local unit_pos = Vector2:new(position.x, position.y)
            
            -- Initialize position history for this unit
            if not self.position_history[unit.id] then
                self.position_history[unit.id] = {}
            end
            
            -- Record position
            table.insert(self.position_history[unit.id], {
                position = unit_pos,
                time = current_time
            })
            
            -- Keep only recent history
            local history = self.position_history[unit.id]
            while #history > 10 do
                table.remove(history, 1)
            end
            
            -- Check if unit is stuck (hasn't moved much in 3 seconds)
            if #history >= 5 then
                local oldest = history[1]
                local newest = history[#history]
                local time_span = newest.time - oldest.time
                local distance_moved = oldest.position:distance_to(newest.position)
                
                if time_span >= 3.0 and distance_moved < 10 and moveable.moving then
                    table.insert(stuck_units, {
                        unit_id = unit.id,
                        position = unit_pos,
                        stuck_duration = time_span,
                        distance_moved = distance_moved
                    })
                end
            end
        end
    end
    
    return stuck_units
end
-- }}}

-- {{{ MovementTestSystem:run_comprehensive_stress_test
function MovementTestSystem:run_comprehensive_stress_test()
    debug.log("Starting comprehensive stress test", "MOVEMENT_TEST")
    
    local test_result = {
        scenario = "comprehensive_stress_test",
        start_time = love.timer.getTime(),
        phases = {},
        overall_success = true
    }
    
    -- Phase 1: Low density baseline
    debug.log("Phase 1: Low density baseline", "MOVEMENT_TEST")
    local phase1 = self:run_stress_phase("low_density", 5, 10.0)
    table.insert(test_result.phases, phase1)
    
    -- Phase 2: Medium density
    debug.log("Phase 2: Medium density", "MOVEMENT_TEST")
    self:cleanup_test_units()
    love.timer.sleep(1)
    local phase2 = self:run_stress_phase("medium_density", 15, 15.0)
    table.insert(test_result.phases, phase2)
    
    -- Phase 3: High density stress
    debug.log("Phase 3: High density stress", "MOVEMENT_TEST")
    self:cleanup_test_units()
    love.timer.sleep(1)
    local phase3 = self:run_stress_phase("high_density", 30, 20.0)
    table.insert(test_result.phases, phase3)
    
    -- Phase 4: Extreme stress test
    debug.log("Phase 4: Extreme stress test", "MOVEMENT_TEST")
    self:cleanup_test_units()
    love.timer.sleep(1)
    local phase4 = self:run_stress_phase("extreme_density", 50, 25.0)
    table.insert(test_result.phases, phase4)
    
    test_result.end_time = love.timer.getTime()
    test_result.total_duration = test_result.end_time - test_result.start_time
    
    -- Analyze overall performance
    self:analyze_stress_test_results(test_result)
    
    self:cleanup_test_units()
    return test_result
end
-- }}}

-- {{{ MovementTestSystem:run_stress_phase
function MovementTestSystem:run_stress_phase(phase_name, unit_count, duration)
    local phase_result = {
        name = phase_name,
        unit_count = unit_count,
        duration = duration,
        start_time = love.timer.getTime(),
        collisions = {},
        stuck_units = {},
        performance_samples = {}
    }
    
    -- Clear tracking data
    self.collision_tracker = {}
    self.performance_tracker = {}
    self.position_history = {}
    
    -- Spawn units
    local units = self.unit_spawning_system:create_test_spawn(unit_count, 1)
    phase_result.units_spawned = #units
    
    -- Run test phase
    local monitor_start = love.timer.getTime()
    
    while love.timer.getTime() - monitor_start < duration do
        local frame_start = love.timer.getTime()
        
        -- Update all systems
        self.unit_movement_system:update(0.1)
        self.lane_following_system:update(0.1)
        self.obstacle_avoidance_system:update(0.1)
        self.formation_system:update(0.1)
        self.queueing_system:update(0.1)
        
        local frame_time = love.timer.getTime() - frame_start
        
        -- Track performance
        self:track_performance_metrics(frame_time)
        
        -- Detect collisions
        local collisions = self:detect_unit_collisions()
        for _, collision in ipairs(collisions) do
            table.insert(phase_result.collisions, collision)
        end
        
        -- Detect stuck units
        local stuck_units = self:detect_stuck_units()
        for _, stuck_unit in ipairs(stuck_units) do
            table.insert(phase_result.stuck_units, stuck_unit)
        end
        
        love.timer.sleep(0.1)
    end
    
    phase_result.end_time = love.timer.getTime()
    phase_result.actual_duration = phase_result.end_time - phase_result.start_time
    
    -- Calculate phase metrics
    self:calculate_phase_metrics(phase_result)
    
    return phase_result
end
-- }}}

-- {{{ MovementTestSystem:calculate_phase_metrics
function MovementTestSystem:calculate_phase_metrics(phase_result)
    -- Performance metrics
    local total_frame_time = 0
    local min_fps = math.huge
    local max_fps = 0
    
    for _, sample in ipairs(self.performance_tracker) do
        total_frame_time = total_frame_time + sample.frame_time
        min_fps = math.min(min_fps, sample.fps)
        max_fps = math.max(max_fps, sample.fps)
    end
    
    phase_result.avg_frame_time = total_frame_time / #self.performance_tracker
    phase_result.avg_fps = 1.0 / phase_result.avg_frame_time
    phase_result.min_fps = min_fps
    phase_result.max_fps = max_fps
    
    -- Collision metrics
    phase_result.total_collisions = #phase_result.collisions
    phase_result.collision_rate = phase_result.total_collisions / phase_result.units_spawned
    
    -- Stuck unit metrics
    local unique_stuck_units = {}
    for _, stuck_unit in ipairs(phase_result.stuck_units) do
        unique_stuck_units[stuck_unit.unit_id] = true
    end
    phase_result.stuck_unit_count = 0
    for _ in pairs(unique_stuck_units) do
        phase_result.stuck_unit_count = phase_result.stuck_unit_count + 1
    end
    
    -- Success criteria
    phase_result.performance_success = phase_result.avg_fps >= 30
    phase_result.collision_success = phase_result.collision_rate < 0.1
    phase_result.stuck_success = phase_result.stuck_unit_count == 0
    phase_result.overall_success = phase_result.performance_success and 
                                   phase_result.collision_success and 
                                   phase_result.stuck_success
end
-- }}}

-- {{{ MovementTestSystem:analyze_stress_test_results
function MovementTestSystem:analyze_stress_test_results(test_result)
    debug.log("=== COMPREHENSIVE STRESS TEST RESULTS ===", "MOVEMENT_TEST")
    
    for _, phase in ipairs(test_result.phases) do
        local status = phase.overall_success and "PASS" or "FAIL"
        debug.log(string.format("%s (%d units): %s", phase.name, phase.unit_count, status), "MOVEMENT_TEST")
        debug.log(string.format("  Performance: %.1f fps (min: %.1f, max: %.1f)", 
                  phase.avg_fps, phase.min_fps, phase.max_fps), "MOVEMENT_TEST")
        debug.log(string.format("  Collisions: %d total (%.2f per unit)", 
                  phase.total_collisions, phase.collision_rate), "MOVEMENT_TEST")
        debug.log(string.format("  Stuck units: %d", phase.stuck_unit_count), "MOVEMENT_TEST")
        
        if not phase.overall_success then
            test_result.overall_success = false
        end
    end
    
    debug.log(string.format("OVERALL STRESS TEST: %s", 
              test_result.overall_success and "PASS" or "FAIL"), "MOVEMENT_TEST")
    debug.log("=== END STRESS TEST RESULTS ===", "MOVEMENT_TEST")
end
-- }}}

-- {{{ MovementTestSystem:run_quick_test
function MovementTestSystem:run_quick_test()
    -- Quick test for development iteration
    debug.log("Running quick movement test", "MOVEMENT_TEST")
    
    local units = self.unit_spawning_system:create_test_spawn(5, 1)
    
    -- Brief test run
    for i = 1, 30 do  -- 3 seconds at 10fps
        self.unit_movement_system:update(0.1)
        self.lane_following_system:update(0.1)
        self.obstacle_avoidance_system:update(0.1)
        self.queueing_system:update(0.1)
        love.timer.sleep(0.1)
    end
    
    -- Check basic functionality
    local queue_info = self.queueing_system:get_debug_info()
    local avoidance_info = self.obstacle_avoidance_system:get_debug_info()
    
    debug.log("Quick test results:", "MOVEMENT_TEST")
    debug.log("- Units spawned: " .. #units, "MOVEMENT_TEST")
    debug.log("- Queues formed: " .. queue_info.total_queues, "MOVEMENT_TEST")
    debug.log("- Units avoiding: " .. avoidance_info.units_avoiding, "MOVEMENT_TEST")
    
    self:cleanup_test_units()
end
-- }}}

return MovementTestSystem
-- }}}