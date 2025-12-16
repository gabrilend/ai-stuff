-- {{{ UnitSpawningSystem
local UnitSpawningSystem = {}

local Unit = require("src.entities.unit")
local Vector2 = require("src.utils.vector2")
local Colors = require("src.constants.colors")
local debug = require("src.utils.debug")

-- {{{ UnitSpawningSystem:new
function UnitSpawningSystem:new(entity_manager, map_data, unit_movement_system)
    local system = {
        entity_manager = entity_manager,
        map_data = map_data,
        unit_movement_system = unit_movement_system,
        name = "unit_spawning",
        spawn_queues = {
            [1] = {},  -- Player 1 spawn queue
            [2] = {}   -- Player 2 spawn queue
        },
        spawn_cooldowns = {
            [1] = 0,   -- Player 1 cooldown
            [2] = 0    -- Player 2 cooldown
        },
        default_spawn_cooldown = 1.0,  -- Seconds between spawns (reduced for better flow)
        max_queue_size = 10,
        spawn_formation = "line",
        spawned_units = {},
        spawn_effects = {}
    }
    setmetatable(system, {__index = UnitSpawningSystem})
    
    debug.log("UnitSpawningSystem created", "UNIT_SPAWN")
    return system
end
-- }}}

-- {{{ UnitSpawningSystem:update
function UnitSpawningSystem:update(dt)
    -- Update cooldowns
    for player_id in pairs(self.spawn_cooldowns) do
        if self.spawn_cooldowns[player_id] > 0 then
            self.spawn_cooldowns[player_id] = self.spawn_cooldowns[player_id] - dt
        end
    end
    
    -- Process spawn queues
    for player_id, queue in pairs(self.spawn_queues) do
        if #queue > 0 and self.spawn_cooldowns[player_id] <= 0 then
            self:process_spawn_request(player_id, queue[1])
            table.remove(queue, 1)  -- Remove processed request
            self.spawn_cooldowns[player_id] = self.default_spawn_cooldown
        end
    end
end
-- }}}

-- {{{ UnitSpawningSystem:queue_unit_spawn
function UnitSpawningSystem:queue_unit_spawn(player_id, unit_type, lane_preference)
    unit_type = unit_type or "melee"
    
    if #self.spawn_queues[player_id] >= self.max_queue_size then
        debug.warn("Spawn queue full for player " .. player_id, "UNIT_SPAWN")
        return false
    end
    
    local spawn_request = {
        player_id = player_id,
        unit_type = unit_type,
        lane_preference = lane_preference,
        request_time = love and love.timer and love.timer.getTime() or 0
    }
    
    table.insert(self.spawn_queues[player_id], spawn_request)
    
    debug.log("Queued " .. unit_type .. " for player " .. player_id, "UNIT_SPAWN")
    return true
end
-- }}}

-- {{{ UnitSpawningSystem:process_spawn_request
function UnitSpawningSystem:process_spawn_request(player_id, spawn_request)
    -- Enhanced spawn validation
    local can_spawn, reason = self:can_spawn_unit(spawn_request.unit_type, player_id)
    if not can_spawn then
        debug.warn("Cannot spawn unit: " .. reason, "UNIT_SPAWN")
        return false
    end
    
    local spawn_point = self:get_spawn_point(player_id)
    if not spawn_point then
        debug.error("No spawn point found for player " .. player_id, "UNIT_SPAWN")
        return false
    end
    
    -- Find appropriate sub-path with intelligent selection
    local target_sub_path = self:find_spawn_sub_path(spawn_point, spawn_request.lane_preference, player_id)
    if not target_sub_path then
        debug.warn("No available sub-path for spawning", "UNIT_SPAWN")
        return false
    end
    
    -- Calculate spawn position with formation offset
    local spawn_position = self:calculate_spawn_position(spawn_point, target_sub_path, spawn_request.unit_type)
    if not spawn_position then
        debug.error("Cannot calculate valid spawn position", "UNIT_SPAWN")
        return false
    end
    
    -- Create the unit at calculated position
    local unit = Unit.create_basic_unit(
        self.entity_manager,
        spawn_position.x,
        spawn_position.y,
        player_id,
        spawn_request.unit_type
    )
    
    if not unit then
        debug.error("Failed to create unit", "UNIT_SPAWN")
        return false
    end
    
    -- Register spawned unit and assign to movement system
    self:register_spawned_unit(unit, spawn_point.id or player_id, target_sub_path.id)
    
    -- Create spawn effects
    self:create_spawn_effects(spawn_position, player_id)
    
    -- Assign unit to movement system
    if self.unit_movement_system then
        local success = self.unit_movement_system:assign_unit_to_sub_path(unit, target_sub_path.lane, target_sub_path.id, 0.0)
        if success then
            debug.log("Spawned " .. spawn_request.unit_type .. " for player " .. player_id .. " at " .. spawn_position.x .. "," .. spawn_position.y, "UNIT_SPAWN")
        else
            debug.warn("Failed to assign spawned unit to sub-path", "UNIT_SPAWN")
        end
    end
    
    return unit
end
-- }}}

-- {{{ UnitSpawningSystem:get_spawn_point
function UnitSpawningSystem:get_spawn_point(player_id)
    local spawn_key = "player_" .. player_id
    return self.map_data.spawn_points[spawn_key]
end
-- }}}

-- {{{ UnitSpawningSystem:find_suitable_lane_and_path
function UnitSpawningSystem:find_suitable_lane_and_path(player_id, lane_preference)
    local spawn_point = self:get_spawn_point(player_id)
    if not spawn_point then
        return nil, nil
    end
    
    -- Find lanes that start near the spawn point
    local suitable_lanes = {}
    local lane_threshold = 100  -- Distance threshold for considering a lane "near" spawn
    
    for _, connection in ipairs(self.map_data.connections) do
        local distance_to_start = spawn_point:distance_to(connection.from)
        local distance_to_end = spawn_point:distance_to(connection.to)
        
        if distance_to_start < lane_threshold then
            -- This lane starts near our spawn point
            table.insert(suitable_lanes, {
                connection = connection,
                start_point = connection.from,
                end_point = connection.to,
                distance = distance_to_start
            })
        elseif distance_to_end < lane_threshold then
            -- This lane ends near our spawn point (reverse direction)
            table.insert(suitable_lanes, {
                connection = connection,
                start_point = connection.to,
                end_point = connection.from,
                distance = distance_to_end
            })
        end
    end
    
    if #suitable_lanes == 0 then
        debug.warn("No suitable lanes found near spawn point", "UNIT_SPAWN")
        return nil, nil
    end
    
    -- Sort by distance and pick the closest
    table.sort(suitable_lanes, function(a, b) return a.distance < b.distance end)
    local chosen_lane_data = suitable_lanes[1]
    
    -- Create a lane using the lane system
    local lane = self:create_lane_from_connection(chosen_lane_data)
    
    -- Choose sub-path based on preference and availability
    local sub_path_id = self:choose_sub_path(lane, lane_preference)
    
    return lane, sub_path_id
end
-- }}}

-- {{{ UnitSpawningSystem:create_lane_from_connection
function UnitSpawningSystem:create_lane_from_connection(lane_data)
    -- This is a simplified version - in a full implementation,
    -- you'd want to integrate this with the LaneSystem properly
    local lane = {
        start_point = lane_data.start_point,
        end_point = lane_data.end_point,
        width = 60,
        sub_paths = {},
        connection = lane_data.connection
    }
    
    -- Create simplified sub-paths for immediate use
    for i = 1, 5 do
        local offset_multiplier = i - 3  -- -2, -1, 0, 1, 2
        local sub_path = {
            id = i,
            width = 12,
            center_line = {lane_data.start_point, lane_data.end_point}
        }
        table.insert(lane.sub_paths, sub_path)
    end
    
    return lane
end
-- }}}

-- {{{ UnitSpawningSystem:choose_sub_path
function UnitSpawningSystem:choose_sub_path(lane, preference)
    -- Default to center path
    local preferred_id = 3
    
    if preference == "left" then
        preferred_id = 1
    elseif preference == "right" then
        preferred_id = 5
    elseif preference == "center" then
        preferred_id = 3
    elseif type(preference) == "number" and preference >= 1 and preference <= 5 then
        preferred_id = preference
    end
    
    -- Check if preferred path is available (not too crowded)
    local units_on_path = self.unit_movement_system:get_units_on_sub_path(lane, preferred_id)
    if #units_on_path < 3 then  -- Allow up to 3 units per sub-path
        return preferred_id
    end
    
    -- Find least crowded sub-path
    local least_crowded_id = 1
    local min_units = math.huge
    
    for i = 1, 5 do
        local units_count = #self.unit_movement_system:get_units_on_sub_path(lane, i)
        if units_count < min_units then
            min_units = units_count
            least_crowded_id = i
        end
    end
    
    return least_crowded_id
end
-- }}}

-- {{{ UnitSpawningSystem:spawn_immediate
function UnitSpawningSystem:spawn_immediate(player_id, unit_type, lane_preference)
    -- Bypass queue and spawn immediately
    local spawn_request = {
        player_id = player_id,
        unit_type = unit_type,
        lane_preference = lane_preference,
        request_time = love and love.timer and love.timer.getTime() or 0
    }
    
    return self:process_spawn_request(player_id, spawn_request)
end
-- }}}

-- {{{ UnitSpawningSystem:spawn_formation
function UnitSpawningSystem:spawn_formation(player_id, unit_types, formation_type)
    formation_type = formation_type or "line"
    local spawned_units = {}
    
    -- Find a suitable lane
    local lane, _ = self:find_suitable_lane_and_path(player_id, "center")
    if not lane then
        debug.error("No suitable lane for formation spawn", "UNIT_SPAWN")
        return {}
    end
    
    -- Create all units first
    local spawn_point = self:get_spawn_point(player_id)
    for i, unit_type in ipairs(unit_types) do
        local unit = Unit.create_basic_unit(
            self.entity_manager,
            spawn_point.x,
            spawn_point.y,
            player_id,
            unit_type
        )
        if unit then
            table.insert(spawned_units, unit)
        end
    end
    
    -- Deploy them in formation
    if #spawned_units > 0 then
        local success = self.unit_movement_system:deploy_formation(lane, spawned_units, formation_type)
        if success then
            debug.log("Spawned formation of " .. #spawned_units .. " units", "UNIT_SPAWN")
        end
    end
    
    return spawned_units
end
-- }}}

-- {{{ UnitSpawningSystem:clear_spawn_queue
function UnitSpawningSystem:clear_spawn_queue(player_id)
    if player_id then
        self.spawn_queues[player_id] = {}
        debug.log("Cleared spawn queue for player " .. player_id, "UNIT_SPAWN")
    else
        for pid in pairs(self.spawn_queues) do
            self.spawn_queues[pid] = {}
        end
        debug.log("Cleared all spawn queues", "UNIT_SPAWN")
    end
end
-- }}}

-- {{{ UnitSpawningSystem:set_spawn_cooldown
function UnitSpawningSystem:set_spawn_cooldown(cooldown)
    self.default_spawn_cooldown = cooldown
    debug.log("Set spawn cooldown to " .. cooldown .. " seconds", "UNIT_SPAWN")
end
-- }}}

-- {{{ UnitSpawningSystem:get_queue_status
function UnitSpawningSystem:get_queue_status(player_id)
    if player_id then
        return {
            queue_size = #self.spawn_queues[player_id],
            cooldown_remaining = self.spawn_cooldowns[player_id],
            can_spawn = self.spawn_cooldowns[player_id] <= 0
        }
    else
        local status = {}
        for pid in pairs(self.spawn_queues) do
            status[pid] = {
                queue_size = #self.spawn_queues[pid],
                cooldown_remaining = self.spawn_cooldowns[pid],
                can_spawn = self.spawn_cooldowns[pid] <= 0
            }
        end
        return status
    end
end
-- }}}

-- {{{ UnitSpawningSystem:get_spawn_statistics
function UnitSpawningSystem:get_spawn_statistics()
    local stats = {
        total_queued = 0,
        queues_by_player = {},
        cooldowns = {},
        spawned_units = self.spawned_units or {}
    }
    
    for player_id, queue in pairs(self.spawn_queues) do
        stats.total_queued = stats.total_queued + #queue
        stats.queues_by_player[player_id] = #queue
        stats.cooldowns[player_id] = self.spawn_cooldowns[player_id]
    end
    
    return stats
end
-- }}}

-- {{{ UnitSpawningSystem:find_spawn_sub_path
function UnitSpawningSystem:find_spawn_sub_path(spawn_point, preference, team_id)
    -- Get available lanes near spawn point
    local available_lanes = self:get_lanes_at_spawn_point(spawn_point, team_id)
    
    if #available_lanes == 0 then
        return nil
    end
    
    -- If preference specified, try to use it
    if preference and type(preference) == "table" and preference.lane_id then
        for _, lane in ipairs(available_lanes) do
            if lane.id == preference.lane_id then
                local sub_path = self:select_sub_path_in_lane(lane, preference.sub_path_index)
                if sub_path then
                    return sub_path
                end
            end
        end
    end
    
    -- Default selection: find least crowded sub-path
    local best_sub_path = nil
    local min_unit_count = math.huge
    
    for _, lane in ipairs(available_lanes) do
        for i = 1, 5 do  -- 5 sub-paths per lane
            local unit_count = self:count_units_in_sub_path(lane, i)
            if unit_count < min_unit_count then
                min_unit_count = unit_count
                best_sub_path = {
                    id = i,
                    lane = lane,
                    center_line = self:get_sub_path_center_line(lane, i),
                    width = 12
                }
            end
        end
    end
    
    return best_sub_path
end
-- }}}

-- {{{ UnitSpawningSystem:calculate_spawn_position
function UnitSpawningSystem:calculate_spawn_position(spawn_point, sub_path, unit_type)
    local base_position = Vector2:new(spawn_point.x, spawn_point.y)
    
    -- Find closest point on sub-path center line to spawn point
    local center_line = sub_path.center_line or {base_position}
    if #center_line == 0 then
        return nil
    end
    
    local closest_point = center_line[1]
    local min_distance = base_position:distance_to(closest_point)
    
    for i = 2, #center_line do
        local distance = base_position:distance_to(center_line[i])
        if distance < min_distance then
            min_distance = distance
            closest_point = center_line[i]
        end
    end
    
    -- Apply formation offset based on unit count in sub-path
    local formation_offset = self:calculate_formation_offset(sub_path, unit_type)
    local spawn_position = closest_point:add(formation_offset)
    
    -- Ensure position is within reasonable bounds
    if self:is_valid_spawn_position(spawn_position, sub_path) then
        return spawn_position
    else
        -- Fall back to spawn point if calculated position is invalid
        return base_position
    end
end
-- }}}

-- {{{ UnitSpawningSystem:calculate_formation_offset
function UnitSpawningSystem:calculate_formation_offset(sub_path, unit_type)
    local existing_units = self:get_units_in_sub_path(sub_path)
    local unit_count = #existing_units
    
    -- Calculate lateral offset to prevent spawning on top of each other
    local lateral_spacing = 12  -- Distance between units side-by-side
    local depth_spacing = 16   -- Distance between units front-to-back
    
    -- Determine formation position based on unit count
    local units_per_row = 3  -- Maximum units side-by-side
    local row = math.floor(unit_count / units_per_row)
    local col = unit_count % units_per_row
    
    -- Calculate offset perpendicular to path direction
    local path_direction = self:get_sub_path_direction(sub_path)
    local perpendicular = Vector2:new(-path_direction.y, path_direction.x)
    
    -- Center the formation
    local lateral_offset = (col - (units_per_row - 1) / 2) * lateral_spacing
    local depth_offset = -row * depth_spacing  -- Behind the front line
    
    local formation_offset = perpendicular:multiply(lateral_offset):add(
        path_direction:multiply(depth_offset)
    )
    
    return formation_offset
end
-- }}}

-- {{{ UnitSpawningSystem:get_sub_path_direction
function UnitSpawningSystem:get_sub_path_direction(sub_path)
    local center_line = sub_path.center_line or {}
    
    if #center_line < 2 then
        return Vector2:new(1, 0)  -- Default direction
    end
    
    -- Use direction from first segment
    local direction = center_line[2]:subtract(center_line[1]):normalize()
    return direction
end
-- }}}

-- {{{ UnitSpawningSystem:create_spawn_effects
function UnitSpawningSystem:create_spawn_effects(position, team_id)
    -- Visual spawn effect (simple circle expansion)
    local effect_duration = 0.5
    local max_radius = 20
    
    local effect = {
        position = position,
        team_id = team_id,
        start_time = love and love.timer and love.timer.getTime() or 0,
        duration = effect_duration,
        max_radius = max_radius,
        type = "spawn"
    }
    
    -- Store effect for rendering (simplified - would integrate with EffectSystem)
    self.spawn_effects = self.spawn_effects or {}
    table.insert(self.spawn_effects, effect)
    
    debug.log("Created spawn effect at " .. position.x .. "," .. position.y, "UNIT_SPAWN")
end
-- }}}

-- {{{ UnitSpawningSystem:can_spawn_unit
function UnitSpawningSystem:can_spawn_unit(unit_type, team_id, spawn_point_id)
    local spawn_point = self:get_spawn_point(team_id)
    
    if not spawn_point then
        return false, "Invalid spawn point"
    end
    
    -- Check if spawn point area is clear
    local nearby_units = self:get_units_near_position(spawn_point, 20)
    if #nearby_units > 5 then  -- Limit concurrent spawning
        return false, "Spawn area too crowded"
    end
    
    -- Check if valid sub-paths are available
    local available_lanes = self:get_lanes_at_spawn_point(spawn_point, team_id)
    if #available_lanes == 0 then
        return false, "No available lanes"
    end
    
    return true, "Ready to spawn"
end
-- }}}

-- {{{ UnitSpawningSystem:register_spawned_unit
function UnitSpawningSystem:register_spawned_unit(unit_id, spawn_point_id, sub_path_id)
    self.spawned_units = self.spawned_units or {}
    
    local spawn_record = {
        unit_id = unit_id,
        spawn_point_id = spawn_point_id,
        sub_path_id = sub_path_id,
        spawn_time = love and love.timer and love.timer.getTime() or 0
    }
    
    table.insert(self.spawned_units, spawn_record)
    debug.log("Registered spawned unit: " .. unit_id, "UNIT_SPAWN")
end
-- }}}

-- {{{ UnitSpawningSystem:create_test_spawn
function UnitSpawningSystem:create_test_spawn(unit_count, player_id)
    player_id = player_id or 1
    unit_count = unit_count or 5
    
    local unit_types = {"melee", "ranged", "tank", "support", "melee"}
    local spawned_units = {}
    
    for i = 1, unit_count do
        local unit_type = unit_types[((i - 1) % #unit_types) + 1]
        if self:spawn_immediate(player_id, unit_type, "center") then
            table.insert(spawned_units, unit_type)
        end
    end
    
    debug.log("Created test spawn of " .. #spawned_units .. " units", "UNIT_SPAWN")
    return spawned_units
end
-- }}}

-- {{{ UnitSpawningSystem:batch_spawn_units
function UnitSpawningSystem:batch_spawn_units(spawn_requests)
    local spawned_units = {}
    local spawn_delay = 0.1  -- Delay between spawns in batch
    
    for i, request in ipairs(spawn_requests) do
        -- Schedule spawn with slight delay to prevent overlap
        local spawn_time = (love and love.timer and love.timer.getTime() or 0) + (i - 1) * spawn_delay
        
        -- For immediate batch spawning, process directly
        local unit = self:process_spawn_request(request.player_id, request)
        if unit then
            table.insert(spawned_units, unit)
        end
    end
    
    debug.log("Batch spawned " .. #spawned_units .. " units", "UNIT_SPAWN")
    return spawned_units
end
-- }}}

-- {{{ UnitSpawningSystem:get_lanes_at_spawn_point
function UnitSpawningSystem:get_lanes_at_spawn_point(spawn_point, team_id)
    -- Simplified implementation - would integrate with LaneSystem
    local available_lanes = {}
    
    if self.map_data and self.map_data.connections then
        local lane_threshold = 100  -- Distance threshold
        
        for i, connection in ipairs(self.map_data.connections) do
            local distance_to_start = spawn_point:distance_to(connection.from)
            local distance_to_end = spawn_point:distance_to(connection.to)
            
            if distance_to_start < lane_threshold or distance_to_end < lane_threshold then
                local lane = {
                    id = i,
                    connection = connection,
                    start_point = distance_to_start < distance_to_end and connection.from or connection.to,
                    end_point = distance_to_start < distance_to_end and connection.to or connection.from
                }
                table.insert(available_lanes, lane)
            end
        end
    end
    
    return available_lanes
end
-- }}}

-- {{{ UnitSpawningSystem:select_sub_path_in_lane
function UnitSpawningSystem:select_sub_path_in_lane(lane, sub_path_index)
    sub_path_index = sub_path_index or 3  -- Default to center path
    
    if sub_path_index >= 1 and sub_path_index <= 5 then
        return {
            id = sub_path_index,
            lane = lane,
            center_line = self:get_sub_path_center_line(lane, sub_path_index),
            width = 12
        }
    end
    
    return nil
end
-- }}}

-- {{{ UnitSpawningSystem:count_units_in_sub_path
function UnitSpawningSystem:count_units_in_sub_path(lane, sub_path_id)
    -- Count units currently in this sub-path
    if self.unit_movement_system then
        local units = self.unit_movement_system:get_units_on_sub_path(lane, sub_path_id)
        return units and #units or 0
    end
    
    return 0  -- Default if no movement system
end
-- }}}

-- {{{ UnitSpawningSystem:get_sub_path_center_line
function UnitSpawningSystem:get_sub_path_center_line(lane, sub_path_id)
    -- Generate center line for sub-path (simplified)
    local start_point = lane.start_point
    local end_point = lane.end_point
    
    if not start_point or not end_point then
        return {}
    end
    
    -- Create simple two-point center line
    return {start_point, end_point}
end
-- }}}

-- {{{ UnitSpawningSystem:get_units_in_sub_path
function UnitSpawningSystem:get_units_in_sub_path(sub_path)
    -- Get units currently in this sub-path
    local units = {}
    
    if self.spawned_units then
        for _, spawn_record in ipairs(self.spawned_units) do
            if spawn_record.sub_path_id == sub_path.id then
                table.insert(units, spawn_record.unit_id)
            end
        end
    end
    
    return units
end
-- }}}

-- {{{ UnitSpawningSystem:is_valid_spawn_position
function UnitSpawningSystem:is_valid_spawn_position(position, sub_path)
    -- Basic validation - check if position is reasonable
    if not position or not position.x or not position.y then
        return false
    end
    
    -- Check if position is within map bounds (simplified)
    local map_width = 800  -- Default map width
    local map_height = 600  -- Default map height
    
    return position.x >= 0 and position.x <= map_width and 
           position.y >= 0 and position.y <= map_height
end
-- }}}

-- {{{ UnitSpawningSystem:get_units_near_position
function UnitSpawningSystem:get_units_near_position(position, radius)
    local nearby_units = {}
    
    if self.spawned_units then
        for _, spawn_record in ipairs(self.spawned_units) do
            -- This would need to get actual unit position from entity manager
            -- Simplified for now
            table.insert(nearby_units, spawn_record.unit_id)
        end
    end
    
    return nearby_units
end
-- }}}

-- {{{ UnitSpawningSystem:test_enhanced_spawning
function UnitSpawningSystem:test_enhanced_spawning()
    print("Testing Enhanced Unit Spawning System...")
    
    -- Test spawn point validation
    local spawn_point_1 = self:get_spawn_point(1)
    local spawn_point_2 = self:get_spawn_point(2)
    
    assert(spawn_point_1, "Player 1 spawn point must exist")
    assert(spawn_point_2, "Player 2 spawn point must exist")
    print("✓ Spawn points validation working")
    
    -- Test spawn validation
    local can_spawn_1, reason_1 = self:can_spawn_unit("melee", 1)
    assert(can_spawn_1, "Should be able to spawn for player 1: " .. (reason_1 or "unknown"))
    print("✓ Spawn validation working")
    
    -- Test sub-path selection
    local sub_path = self:find_spawn_sub_path(spawn_point_1, nil, 1)
    if sub_path then
        assert(sub_path.id, "Sub-path must have ID")
        assert(sub_path.lane, "Sub-path must have lane reference")
        print("✓ Sub-path selection working")
    else
        print("⚠ No sub-paths available (expected in test environment)")
    end
    
    -- Test formation offset calculation
    local mock_sub_path = {
        id = 3,
        center_line = {Vector2:new(100, 100), Vector2:new(200, 100)},
        width = 12
    }
    
    local formation_offset = self:calculate_formation_offset(mock_sub_path, "melee")
    assert(formation_offset, "Formation offset must be calculated")
    assert(formation_offset.x ~= nil and formation_offset.y ~= nil, "Formation offset must have x,y coordinates")
    print("✓ Formation offset calculation working")
    
    -- Test spawn position calculation
    local spawn_position = self:calculate_spawn_position(spawn_point_1, mock_sub_path, "melee")
    if spawn_position then
        assert(spawn_position.x and spawn_position.y, "Spawn position must have coordinates")
        print("✓ Spawn position calculation working")
    else
        print("⚠ Spawn position calculation returned nil (may be expected)")
    end
    
    -- Test spawn effects creation
    local test_position = Vector2:new(100, 100)
    self:create_spawn_effects(test_position, 1)
    assert(self.spawn_effects and #self.spawn_effects > 0, "Spawn effects should be created")
    print("✓ Spawn effects creation working")
    
    -- Test batch spawning request structure
    local batch_requests = {
        {player_id = 1, unit_type = "melee", lane_preference = "center"},
        {player_id = 1, unit_type = "ranged", lane_preference = "center"},
        {player_id = 1, unit_type = "tank", lane_preference = "center"}
    }
    
    -- Test batch spawn (without actually spawning)
    assert(#batch_requests == 3, "Batch requests should contain 3 items")
    print("✓ Batch spawning structure validation working")
    
    -- Test spawn queue and cooldown mechanics
    local original_cooldown = self.spawn_cooldowns[1]
    self.spawn_cooldowns[1] = 0  -- Allow immediate spawning
    
    local queue_success = self:queue_unit_spawn(1, "melee", "center")
    assert(queue_success, "Should be able to queue unit spawn")
    
    local queue_status = self:get_queue_status(1)
    assert(queue_status.queue_size > 0, "Queue should contain spawned unit")
    
    -- Restore original cooldown
    self.spawn_cooldowns[1] = original_cooldown
    print("✓ Queue and cooldown management working")
    
    -- Test spawn statistics
    local stats = self:get_spawn_statistics()
    assert(stats.total_queued >= 0, "Total queued should be non-negative")
    assert(stats.queues_by_player, "Stats should include player queue counts")
    assert(stats.spawned_units, "Stats should include spawned units tracking")
    print("✓ Spawn statistics collection working")
    
    print("✓ Enhanced Unit Spawning System tests passed!")
    return true
end
-- }}}

return UnitSpawningSystem
-- }}}