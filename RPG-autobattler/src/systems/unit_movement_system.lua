-- {{{ UnitMovementSystem
local BaseSystem = require("src.systems.base_system")
local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

local UnitMovementSystem = {}
UnitMovementSystem.__index = UnitMovementSystem

-- {{{ UnitMovementSystem:new
function UnitMovementSystem:new(entity_manager, lane_system)
    local system = {
        entity_manager = entity_manager,
        lane_system = lane_system,
        name = "unit_movement",
        active_lanes = {},
        unit_assignments = {}, -- Maps unit ID to {lane, sub_path, progress}
        update_interval = 1/60,
        last_update = 0
    }
    setmetatable(system, UnitMovementSystem)
    
    debug.log("UnitMovementSystem created", "UNIT_MOVEMENT")
    return system
end
-- }}}

-- {{{ UnitMovementSystem:update
function UnitMovementSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_interval then
        return
    end
    
    -- Get all units with movement components
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        self:process_unit_movement(unit, self.last_update)
    end
    
    self.last_update = 0
end
-- }}}

-- {{{ UnitMovementSystem:process_unit_movement
function UnitMovementSystem:process_unit_movement(unit, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    -- Store previous position
    position.previous_x = position.x
    position.previous_y = position.y
    
    -- Check if unit is assigned to a sub-path
    local assignment = self.unit_assignments[unit.id]
    if assignment and assignment.sub_path then
        self:move_along_sub_path(unit, assignment, dt)
    else
        -- Use basic movement if no sub-path assigned
        self:basic_movement(unit, dt)
    end
    
    unit_data.last_move_time = love.timer.getTime()
end
-- }}}

-- {{{ UnitMovementSystem:move_along_sub_path
function UnitMovementSystem:move_along_sub_path(unit, assignment, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    -- Skip movement if unit is not in moving state
    if unit_data.state ~= "moving" and unit_data.state ~= "spawning" then
        return
    end
    
    local sub_path = assignment.sub_path
    if not sub_path or not sub_path.center_line or #sub_path.center_line < 2 then
        return
    end
    
    -- Calculate next target point along path
    local next_target = self:calculate_next_path_target(position, sub_path, unit_data.speed * dt)
    
    if next_target then
        -- Update velocity toward target
        local direction = Vector2:new(next_target.x - position.x, next_target.y - position.y)
        local distance = direction:length()
        
        if distance > 0.1 then
            direction = direction:normalize()
            moveable.velocity_x = direction.x * unit_data.speed
            moveable.velocity_y = direction.y * unit_data.speed
            moveable.is_moving = true
            
            -- Update position
            position.previous_x = position.x
            position.previous_y = position.y
            position.x = position.x + moveable.velocity_x * dt
            position.y = position.y + moveable.velocity_y * dt
            
            -- Update path progress
            assignment.progress = self:calculate_path_progress(position, sub_path)
            unit_data.state = "moving"
        else
            -- Reached target, stop movement
            moveable.velocity_x = 0
            moveable.velocity_y = 0
            moveable.is_moving = false
            unit_data.state = "arrived"
        end
    else
        -- Reached end of path
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
        moveable.arrived_at_target = true
        unit_data.state = "arrived"
        unit_data.combat_state = "arrived"
        debug.log("Unit " .. unit.name .. " reached end of sub-path", "UNIT_MOVEMENT")
    end
end
-- }}}

-- {{{ UnitMovementSystem:calculate_next_path_target
function UnitMovementSystem:calculate_next_path_target(position, sub_path, max_distance)
    local current_pos = Vector2:new(position.x, position.y)
    local center_line = sub_path.center_line
    
    -- Find current position on path
    local closest_segment_index = self:find_closest_path_segment(current_pos, center_line)
    if not closest_segment_index then
        return center_line[#center_line]  -- Move to end if lost
    end
    
    -- Calculate distance along current segment
    local segment_start = center_line[closest_segment_index]
    local segment_end = center_line[closest_segment_index + 1]
    
    if not segment_end then
        return nil  -- Reached end of path
    end
    
    local segment_vector = segment_end:subtract(segment_start)
    local to_current = current_pos:subtract(segment_start)
    local segment_length = segment_vector:length()
    
    if segment_length == 0 then
        return segment_end
    end
    
    -- Project current position onto segment
    local t = math.max(0, math.min(1, to_current:dot(segment_vector) / (segment_length * segment_length)))
    
    -- Calculate target distance ahead
    local remaining_distance = max_distance
    local target_segment = closest_segment_index
    local target_t = t
    
    while remaining_distance > 0 and target_segment < #center_line - 1 do
        local current_segment_start = center_line[target_segment]
        local current_segment_end = center_line[target_segment + 1]
        local current_segment_vector = current_segment_end:subtract(current_segment_start)
        local current_segment_length = current_segment_vector:length()
        
        -- Distance remaining in current segment
        local remaining_in_segment = current_segment_length * (1 - target_t)
        
        if remaining_distance <= remaining_in_segment then
            -- Target is within current segment
            target_t = target_t + (remaining_distance / current_segment_length)
            break
        else
            -- Move to next segment
            remaining_distance = remaining_distance - remaining_in_segment
            target_segment = target_segment + 1
            target_t = 0
        end
    end
    
    -- Calculate final target position
    if target_segment >= #center_line - 1 then
        return center_line[#center_line]
    else
        local final_start = center_line[target_segment]
        local final_end = center_line[target_segment + 1]
        local final_vector = final_end:subtract(final_start)
        return final_start:add(final_vector:multiply(target_t))
    end
end
-- }}}

-- {{{ UnitMovementSystem:find_closest_path_segment
function UnitMovementSystem:find_closest_path_segment(position, center_line)
    local min_distance = math.huge
    local closest_index = nil
    
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        
        local distance = self:point_to_line_segment_distance(position, segment_start, segment_end)
        
        if distance < min_distance then
            min_distance = distance
            closest_index = i
        end
    end
    
    return closest_index
end
-- }}}

-- {{{ UnitMovementSystem:point_to_line_segment_distance
function UnitMovementSystem:point_to_line_segment_distance(point, line_start, line_end)
    local line_vec = line_end:subtract(line_start)
    local point_vec = point:subtract(line_start)
    
    local line_length_sq = line_vec:dot(line_vec)
    if line_length_sq == 0 then
        return point:subtract(line_start):length()
    end
    
    local t = math.max(0, math.min(1, point_vec:dot(line_vec) / line_length_sq))
    local projection = line_start:add(line_vec:multiply(t))
    
    return point:subtract(projection):length()
end
-- }}}

-- {{{ UnitMovementSystem:calculate_path_progress
function UnitMovementSystem:calculate_path_progress(position, sub_path)
    local current_pos = Vector2:new(position.x, position.y)
    local center_line = sub_path.center_line
    
    if #center_line < 2 then
        return 0
    end
    
    local closest_segment_index = self:find_closest_path_segment(current_pos, center_line)
    if not closest_segment_index then
        return 0
    end
    
    -- Calculate total path length
    local total_length = 0
    for i = 1, #center_line - 1 do
        total_length = total_length + center_line[i + 1]:subtract(center_line[i]):length()
    end
    
    if total_length == 0 then
        return 1
    end
    
    -- Calculate distance to closest segment
    local distance_to_segment = 0
    for i = 1, closest_segment_index - 1 do
        distance_to_segment = distance_to_segment + center_line[i + 1]:subtract(center_line[i]):length()
    end
    
    -- Add distance along current segment
    local segment_start = center_line[closest_segment_index]
    local segment_end = center_line[closest_segment_index + 1]
    local segment_vector = segment_end:subtract(segment_start)
    local to_current = current_pos:subtract(segment_start)
    
    local segment_length = segment_vector:length()
    if segment_length > 0 then
        local t = math.max(0, math.min(1, to_current:dot(segment_vector) / (segment_length * segment_length)))
        distance_to_segment = distance_to_segment + (t * segment_length)
    end
    
    return math.min(1, distance_to_segment / total_length)
end
-- }}}

-- {{{ UnitMovementSystem:basic_movement
function UnitMovementSystem:basic_movement(unit, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    -- Update position based on velocity
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    -- Check if moving towards target
    if moveable.target_x and moveable.target_y then
        local dx = moveable.target_x - position.x
        local dy = moveable.target_y - position.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 1 then -- Not arrived yet
            -- Normalize direction and apply speed
            local dir_x = dx / distance
            local dir_y = dy / distance
            
            moveable.velocity_x = dir_x * moveable.speed
            moveable.velocity_y = dir_y * moveable.speed
            moveable.moving = true
            moveable.arrived_at_target = false
        else
            -- Arrived at target
            position.x = moveable.target_x
            position.y = moveable.target_y
            moveable.velocity_x = 0
            moveable.velocity_y = 0
            moveable.moving = false
            moveable.arrived_at_target = true
        end
    else
        -- No target, just apply velocity
        moveable.moving = (moveable.velocity_x ~= 0 or moveable.velocity_y ~= 0)
    end
end
-- }}}

-- {{{ UnitMovementSystem:assign_unit_to_sub_path
function UnitMovementSystem:assign_unit_to_sub_path(unit, lane, sub_path_id, initial_progress)
    initial_progress = initial_progress or 0
    
    local sub_path = self.lane_system:get_sub_path_by_id(lane, sub_path_id)
    if not sub_path then
        debug.error("Invalid sub-path ID: " .. sub_path_id, "UNIT_MOVEMENT")
        return false
    end
    
    self.unit_assignments[unit.id] = {
        lane = lane,
        sub_path = sub_path,
        sub_path_id = sub_path_id,
        progress = initial_progress
    }
    
    -- Update unit position to start of sub-path
    local start_position = self.lane_system:get_position_on_sub_path(sub_path, initial_progress)
    local position = self.entity_manager:get_component(unit, "position")
    if position then
        position.x = start_position.x
        position.y = start_position.y
    end
    
    -- Update unit data
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.current_sub_path = sub_path_id
        unit_data.combat_state = "moving"
    end
    
    debug.log("Assigned unit " .. unit.name .. " to sub-path " .. sub_path_id, "UNIT_MOVEMENT")
    return true
end
-- }}}

-- {{{ UnitMovementSystem:remove_unit_assignment
function UnitMovementSystem:remove_unit_assignment(unit)
    self.unit_assignments[unit.id] = nil
    
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.current_sub_path = nil
        unit_data.combat_state = "idle"
    end
    
    debug.log("Removed assignment for unit " .. unit.name, "UNIT_MOVEMENT")
end
-- }}}

-- {{{ UnitMovementSystem:get_unit_assignment
function UnitMovementSystem:get_unit_assignment(unit)
    return self.unit_assignments[unit.id]
end
-- }}}

-- {{{ UnitMovementSystem:set_unit_target
function UnitMovementSystem:set_unit_target(unit, target_x, target_y)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    if moveable then
        moveable.target_x = target_x
        moveable.target_y = target_y
        moveable.arrived_at_target = false
        
        -- Remove sub-path assignment when setting manual target
        self:remove_unit_assignment(unit)
        
        debug.log("Set target for unit " .. unit.name .. " to (" .. target_x .. ", " .. target_y .. ")", "UNIT_MOVEMENT")
        return true
    end
    return false
end
-- }}}

-- {{{ UnitMovementSystem:stop_unit
function UnitMovementSystem:stop_unit(unit)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    if moveable then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.target_x = nil
        moveable.target_y = nil
        moveable.moving = false
        
        local unit_data = self.entity_manager:get_component(unit, "unit_data")
        if unit_data then
            unit_data.combat_state = "idle"
        end
        
        debug.log("Stopped unit " .. unit.name, "UNIT_MOVEMENT")
        return true
    end
    return false
end
-- }}}

-- {{{ UnitMovementSystem:get_available_sub_path
function UnitMovementSystem:get_available_sub_path(lane, preferred_id)
    preferred_id = preferred_id or 3 -- Default to center sub-path
    
    -- Check if preferred sub-path is available
    local preferred_sub_path = self.lane_system:get_sub_path_by_id(lane, preferred_id)
    if preferred_sub_path then
        return preferred_sub_path, preferred_id
    end
    
    -- Find any available sub-path
    for i, sub_path in ipairs(lane.sub_paths) do
        return sub_path, i
    end
    
    return nil, nil
end
-- }}}

-- {{{ UnitMovementSystem:calculate_formation_deployment
function UnitMovementSystem:calculate_formation_deployment(lane, units, formation_type)
    formation_type = formation_type or "line"
    
    local positions = self.lane_system:calculate_formation_positions(
        lane, formation_type, #units, 0.05 -- Start at 5% progress
    )
    
    local assignments = {}
    for i, unit in ipairs(units) do
        if positions[i] then
            assignments[unit.id] = {
                lane = lane,
                sub_path_id = positions[i].sub_path_id,
                initial_progress = positions[i].progress,
                formation_position = positions[i].position
            }
        end
    end
    
    return assignments
end
-- }}}

-- {{{ UnitMovementSystem:deploy_formation
function UnitMovementSystem:deploy_formation(lane, units, formation_type)
    local assignments = self:calculate_formation_deployment(lane, units, formation_type)
    
    for _, unit in ipairs(units) do
        local assignment = assignments[unit.id]
        if assignment then
            self:assign_unit_to_sub_path(
                unit, 
                assignment.lane, 
                assignment.sub_path_id, 
                assignment.initial_progress
            )
        end
    end
    
    debug.log("Deployed " .. #units .. " units in " .. formation_type .. " formation", "UNIT_MOVEMENT")
    return true
end
-- }}}

-- {{{ UnitMovementSystem:get_units_on_sub_path
function UnitMovementSystem:get_units_on_sub_path(lane, sub_path_id)
    local units = {}
    
    for unit_id, assignment in pairs(self.unit_assignments) do
        if assignment.lane == lane and assignment.sub_path_id == sub_path_id then
            local unit = self.entity_manager:get_entity_by_id(unit_id)
            if unit then
                table.insert(units, unit)
            end
        end
    end
    
    return units
end
-- }}}

-- {{{ UnitMovementSystem:get_debug_info
function UnitMovementSystem:get_debug_info()
    local assigned_count = 0
    local lane_usage = {}
    
    for unit_id, assignment in pairs(self.unit_assignments) do
        assigned_count = assigned_count + 1
        local lane_key = tostring(assignment.lane)
        lane_usage[lane_key] = (lane_usage[lane_key] or 0) + 1
    end
    
    return {
        total_assignments = assigned_count,
        lane_usage = lane_usage,
        active_lanes = #self.active_lanes
    }
end
-- }}}

-- {{{ UnitMovementSystem:test_path_following
function UnitMovementSystem:test_path_following()
    local debug = require("src.utils.debug")
    
    debug.log("Testing path following calculations", "UNIT_MOVEMENT")
    
    -- Create test sub-path
    local test_sub_path = {
        center_line = {
            Vector2:new(0, 0),
            Vector2:new(100, 0),
            Vector2:new(200, 100),
            Vector2:new(300, 100)
        }
    }
    
    -- Test closest segment finding
    local test_position = Vector2:new(50, 10)
    local closest_index = self:find_closest_path_segment(test_position, test_sub_path.center_line)
    
    if closest_index == 1 then
        debug.log("✓ Closest path segment found correctly", "UNIT_MOVEMENT")
    else
        debug.error("✗ Closest path segment calculation failed", "UNIT_MOVEMENT")
    end
    
    -- Test next target calculation
    local mock_position = {x = 50, y = 5}
    local next_target = self:calculate_next_path_target(mock_position, test_sub_path, 30)
    
    if next_target and next_target.x > 50 then
        debug.log("✓ Next path target calculated correctly", "UNIT_MOVEMENT")
    else
        debug.error("✗ Next path target calculation failed", "UNIT_MOVEMENT")
    end
    
    -- Test progress calculation
    local progress = self:calculate_path_progress(mock_position, test_sub_path)
    
    if progress >= 0 and progress <= 1 then
        debug.log("✓ Path progress calculated correctly: " .. string.format("%.2f", progress), "UNIT_MOVEMENT")
    else
        debug.error("✗ Path progress calculation failed", "UNIT_MOVEMENT")
    end
    
    debug.log("Path following tests completed", "UNIT_MOVEMENT")
end
-- }}}

-- {{{ UnitMovementSystem:test_movement_integration
function UnitMovementSystem:test_movement_integration()
    local debug = require("src.utils.debug")
    local EntityManager = require("src.systems.entity_manager")
    local Unit = require("src.entities.unit")
    
    debug.log("Testing movement system integration", "UNIT_MOVEMENT")
    
    local entity_manager = EntityManager:new()
    
    -- Create test unit
    local unit = Unit.create_melee_unit(entity_manager, 100, 100, 1)
    
    -- Create mock sub-path assignment
    local mock_sub_path = {
        center_line = {
            Vector2:new(100, 100),
            Vector2:new(200, 100),
            Vector2:new(300, 150),
            Vector2:new(400, 200)
        }
    }
    
    local assignment = {
        sub_path = mock_sub_path,
        progress = 0
    }
    
    self.unit_assignments[unit.id] = assignment
    
    -- Test movement processing
    local success, err = pcall(function()
        self:move_along_sub_path(unit, assignment, 0.016) -- 60 FPS
    end)
    
    if success then
        local position = entity_manager:get_component(unit, "position")
        local moveable = entity_manager:get_component(unit, "moveable")
        
        if position and moveable and (moveable.velocity_x ~= 0 or moveable.velocity_y ~= 0) then
            debug.log("✓ Unit movement integration working correctly", "UNIT_MOVEMENT")
        else
            debug.error("✗ Unit movement integration failed - no velocity", "UNIT_MOVEMENT")
        end
    else
        debug.error("✗ Unit movement integration failed: " .. tostring(err), "UNIT_MOVEMENT")
    end
    
    debug.log("Movement integration tests completed", "UNIT_MOVEMENT")
end
-- }}}

return UnitMovementSystem
-- }}}