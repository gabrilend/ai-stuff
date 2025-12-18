-- {{{ ObstacleAvoidanceSystem
local ObstacleAvoidanceSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

-- {{{ ObstacleAvoidanceSystem:new
function ObstacleAvoidanceSystem:new(entity_manager, unit_movement_system)
    local system = {
        entity_manager = entity_manager,
        unit_movement_system = unit_movement_system,
        name = "obstacle_avoidance",
        
        -- Avoidance parameters
        detection_radius = 25,        -- How far to look for obstacles
        avoidance_strength = 1.5,     -- How strongly to avoid obstacles
        personal_space = 15,          -- Minimum distance to maintain from other units
        prediction_time = 1.0,        -- How far ahead to predict collisions
        
        -- Behavior settings
        ally_avoidance = true,        -- Avoid friendly units
        enemy_detection = true,       -- Detect enemy units for combat
        formation_awareness = true,   -- Consider formation when avoiding
        dynamic_spacing = true,       -- Adjust spacing based on unit density
        
        -- Performance optimization
        spatial_grid_size = 50,       -- Size of spatial grid cells for optimization
        spatial_grid = {},            -- Grid for fast neighbor lookup
        update_frequency = 1/20,      -- Update avoidance 20 times per second
        last_update = 0
    }
    setmetatable(system, {__index = ObstacleAvoidanceSystem})
    
    debug.log("ObstacleAvoidanceSystem created", "OBSTACLE_AVOIDANCE")
    return system
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:update
function ObstacleAvoidanceSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Update spatial grid for fast neighbor lookup
    self:update_spatial_grid()
    
    -- Get all moving units
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        local moveable = self.entity_manager:get_component(unit, "moveable")
        if moveable and moveable.moving then
            self:process_unit_avoidance(unit, self.last_update)
        end
    end
    
    self.last_update = 0
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:update_spatial_grid
function ObstacleAvoidanceSystem:update_spatial_grid()
    self.spatial_grid = {}
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        local position = self.entity_manager:get_component(unit, "position")
        if position then
            local grid_x = math.floor(position.x / self.spatial_grid_size)
            local grid_y = math.floor(position.y / self.spatial_grid_size)
            local grid_key = grid_x .. "," .. grid_y
            
            if not self.spatial_grid[grid_key] then
                self.spatial_grid[grid_key] = {}
            end
            
            table.insert(self.spatial_grid[grid_key], unit)
        end
    end
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:process_unit_avoidance
function ObstacleAvoidanceSystem:process_unit_avoidance(unit, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local team = self.entity_manager:get_component(unit, "team")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not moveable or not team then
        return
    end
    
    -- Get nearby units for collision avoidance
    local nearby_units = self:get_nearby_units(unit, position)
    
    -- Calculate avoidance forces
    local avoidance_force = self:calculate_avoidance_force(unit, nearby_units)
    
    -- Calculate separation force (maintain personal space)
    local separation_force = self:calculate_separation_force(unit, nearby_units)
    
    -- Calculate formation cohesion force
    local cohesion_force = Vector2:new(0, 0)
    if self.formation_awareness then
        cohesion_force = self:calculate_formation_cohesion(unit, nearby_units)
    end
    
    -- Combine forces
    local total_force = avoidance_force:add(separation_force):add(cohesion_force)
    
    -- Apply force to movement
    self:apply_avoidance_force(unit, total_force, dt)
    
    -- Update unit state
    if unit_data then
        unit_data.avoiding_obstacles = total_force:length() > 0.1
        unit_data.nearby_unit_count = #nearby_units
    end
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:get_nearby_units
function ObstacleAvoidanceSystem:get_nearby_units(unit, position)
    local nearby = {}
    
    -- Get units from nearby grid cells
    local grid_x = math.floor(position.x / self.spatial_grid_size)
    local grid_y = math.floor(position.y / self.spatial_grid_size)
    
    -- Check the unit's cell and surrounding cells
    for dx = -1, 1 do
        for dy = -1, 1 do
            local check_x = grid_x + dx
            local check_y = grid_y + dy
            local grid_key = check_x .. "," .. check_y
            
            if self.spatial_grid[grid_key] then
                for _, other_unit in ipairs(self.spatial_grid[grid_key]) do
                    if other_unit.id ~= unit.id then
                        local other_position = self.entity_manager:get_component(other_unit, "position")
                        if other_position then
                            local distance = Vector2:new(position.x, position.y):distance_to(
                                Vector2:new(other_position.x, other_position.y)
                            )
                            
                            if distance <= self.detection_radius then
                                table.insert(nearby, {
                                    unit = other_unit,
                                    position = other_position,
                                    distance = distance
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nearby
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:calculate_avoidance_force
function ObstacleAvoidanceSystem:calculate_avoidance_force(unit, nearby_units)
    local unit_position = self.entity_manager:get_component(unit, "position")
    local unit_moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_team = self.entity_manager:get_component(unit, "team")
    
    if not unit_position or not unit_moveable or not unit_team then
        return Vector2:new(0, 0)
    end
    
    local current_pos = Vector2:new(unit_position.x, unit_position.y)
    local current_velocity = Vector2:new(unit_moveable.velocity_x, unit_moveable.velocity_y)
    local avoidance_force = Vector2:new(0, 0)
    
    for _, nearby in ipairs(nearby_units) do
        local other_team = self.entity_manager:get_component(nearby.unit, "team")
        local other_moveable = self.entity_manager:get_component(nearby.unit, "moveable")
        
        if other_team and other_moveable then
            local is_ally = unit_team.player_id == other_team.player_id
            
            -- Only avoid allies if ally avoidance is enabled
            if (is_ally and self.ally_avoidance) or (not is_ally and self.enemy_detection) then
                local other_pos = Vector2:new(nearby.position.x, nearby.position.y)
                local other_velocity = Vector2:new(other_moveable.velocity_x, other_moveable.velocity_y)
                
                -- Predict future collision
                local collision_data = self:predict_collision(
                    current_pos, current_velocity,
                    other_pos, other_velocity,
                    self.prediction_time
                )
                
                if collision_data.will_collide then
                    -- Calculate avoidance direction
                    local avoidance_dir = self:calculate_avoidance_direction(
                        current_pos, other_pos, current_velocity, collision_data
                    )
                    
                    -- Calculate force strength based on urgency
                    local urgency = 1.0 - (collision_data.time_to_collision / self.prediction_time)
                    local force_strength = self.avoidance_strength * urgency
                    
                    -- Add to total avoidance force
                    avoidance_force = avoidance_force:add(avoidance_dir:multiply(force_strength))
                end
            end
        end
    end
    
    return avoidance_force
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:predict_collision
function ObstacleAvoidanceSystem:predict_collision(pos1, vel1, pos2, vel2, prediction_time)
    local relative_pos = pos2:subtract(pos1)
    local relative_vel = vel2:subtract(vel1)
    
    -- If no relative velocity, no collision
    if relative_vel:length() < 0.1 then
        return {
            will_collide = false,
            time_to_collision = math.huge,
            collision_point = pos1
        }
    end
    
    -- Calculate closest approach
    local time_to_closest = -relative_pos:dot(relative_vel) / relative_vel:length_squared()
    time_to_closest = math.max(0, time_to_closest)  -- Can't collide in the past
    
    if time_to_closest > prediction_time then
        return {
            will_collide = false,
            time_to_collision = time_to_closest,
            collision_point = pos1
        }
    end
    
    -- Calculate closest distance
    local future_pos1 = pos1:add(vel1:multiply(time_to_closest))
    local future_pos2 = pos2:add(vel2:multiply(time_to_closest))
    local closest_distance = future_pos1:distance_to(future_pos2)
    
    local collision_threshold = self.personal_space
    local will_collide = closest_distance < collision_threshold
    
    return {
        will_collide = will_collide,
        time_to_collision = time_to_closest,
        collision_point = future_pos1,
        closest_distance = closest_distance
    }
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:calculate_avoidance_direction
function ObstacleAvoidanceSystem:calculate_avoidance_direction(my_pos, other_pos, my_velocity, collision_data)
    -- Calculate direction to avoid
    local to_other = other_pos:subtract(my_pos)
    
    if to_other:length() < 0.1 then
        -- If positions are very close, avoid perpendicular to velocity
        local perpendicular = Vector2:new(-my_velocity.y, my_velocity.x):normalize()
        return perpendicular
    end
    
    local to_other_normalized = to_other:normalize()
    
    -- Choose avoidance direction (perpendicular to approach direction)
    local perpendicular = Vector2:new(-to_other_normalized.y, to_other_normalized.x)
    
    -- Choose the side that doesn't conflict with current movement
    local velocity_normalized = my_velocity:normalize()
    if velocity_normalized:length() > 0.1 then
        local dot1 = perpendicular:dot(velocity_normalized)
        local dot2 = perpendicular:multiply(-1):dot(velocity_normalized)
        
        -- Choose the direction that's more aligned with current movement
        if dot2 > dot1 then
            perpendicular = perpendicular:multiply(-1)
        end
    end
    
    return perpendicular
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:calculate_separation_force
function ObstacleAvoidanceSystem:calculate_separation_force(unit, nearby_units)
    local unit_position = self.entity_manager:get_component(unit, "position")
    local unit_team = self.entity_manager:get_component(unit, "team")
    
    if not unit_position or not unit_team then
        return Vector2:new(0, 0)
    end
    
    local current_pos = Vector2:new(unit_position.x, unit_position.y)
    local separation_force = Vector2:new(0, 0)
    local separation_count = 0
    
    for _, nearby in ipairs(nearby_units) do
        if nearby.distance < self.personal_space then
            local other_team = self.entity_manager:get_component(nearby.unit, "team")
            
            if other_team and unit_team.player_id == other_team.player_id then  -- Only separate from allies
                local other_pos = Vector2:new(nearby.position.x, nearby.position.y)
                local separation_dir = current_pos:subtract(other_pos)
                
                if separation_dir:length() > 0.1 then
                    -- Stronger force for closer units
                    local force_strength = (self.personal_space - nearby.distance) / self.personal_space
                    separation_dir = separation_dir:normalize():multiply(force_strength)
                    separation_force = separation_force:add(separation_dir)
                    separation_count = separation_count + 1
                end
            end
        end
    end
    
    if separation_count > 0 then
        separation_force = separation_force:divide(separation_count):multiply(0.8)  -- Average and scale
    end
    
    return separation_force
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:calculate_formation_cohesion
function ObstacleAvoidanceSystem:calculate_formation_cohesion(unit, nearby_units)
    local unit_position = self.entity_manager:get_component(unit, "position")
    local unit_team = self.entity_manager:get_component(unit, "team")
    local assignment = self.unit_movement_system:get_unit_assignment(unit)
    
    if not unit_position or not unit_team or not assignment then
        return Vector2:new(0, 0)
    end
    
    local current_pos = Vector2:new(unit_position.x, unit_position.y)
    local formation_center = Vector2:new(0, 0)
    local formation_count = 0
    
    -- Find other units in the same formation (same sub-path or nearby sub-paths)
    for _, nearby in ipairs(nearby_units) do
        local other_team = self.entity_manager:get_component(nearby.unit, "team")
        local other_assignment = self.unit_movement_system:get_unit_assignment(nearby.unit)
        
        if other_team and other_assignment and 
           unit_team.player_id == other_team.player_id and
           assignment.lane == other_assignment.lane then
            
            local other_pos = Vector2:new(nearby.position.x, nearby.position.y)
            formation_center = formation_center:add(other_pos)
            formation_count = formation_count + 1
        end
    end
    
    if formation_count > 0 then
        formation_center = formation_center:divide(formation_count)
        local to_center = formation_center:subtract(current_pos)
        
        -- Weak cohesion force to maintain formation
        return to_center:normalize():multiply(0.2)
    end
    
    return Vector2:new(0, 0)
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:apply_avoidance_force
function ObstacleAvoidanceSystem:apply_avoidance_force(unit, force, dt)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local position = self.entity_manager:get_component(unit, "position")
    
    if not moveable or not position or force:length() < 0.01 then
        return
    end
    
    -- Apply lane constraints to the avoidance force
    local constrained_force = self:constrain_force_to_lane(unit, force)
    
    -- Convert force to velocity adjustment
    local max_speed = moveable.max_speed or moveable.speed or 50
    local force_strength = math.min(constrained_force:length(), max_speed * 0.5)  -- Limit avoidance to 50% of max speed
    
    if constrained_force:length() > 0.01 then
        local force_direction = constrained_force:normalize()
        
        -- Apply force to current velocity
        local current_velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
        local avoidance_velocity = force_direction:multiply(force_strength)
        
        -- Blend with current velocity (more gentle blending for smoother movement)
        local blend_factor = 0.25  -- 25% avoidance, 75% original velocity
        local new_velocity = current_velocity:multiply(1 - blend_factor):add(avoidance_velocity:multiply(blend_factor))
        
        -- Ensure we don't exceed max speed
        if new_velocity:length() > max_speed then
            new_velocity = new_velocity:normalize():multiply(max_speed)
        end
        
        moveable.velocity_x = new_velocity.x
        moveable.velocity_y = new_velocity.y
        
        -- Update position with lane boundary checking
        local new_x = position.x + moveable.velocity_x * dt
        local new_y = position.y + moveable.velocity_y * dt
        
        local corrected_position = self:ensure_lane_boundaries(unit, Vector2:new(new_x, new_y))
        position.previous_x = position.x
        position.previous_y = position.y
        position.x = corrected_position.x
        position.y = corrected_position.y
    end
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:set_avoidance_parameters
function ObstacleAvoidanceSystem:set_avoidance_parameters(params)
    self.detection_radius = params.detection_radius or self.detection_radius
    self.avoidance_strength = params.avoidance_strength or self.avoidance_strength
    self.personal_space = params.personal_space or self.personal_space
    self.prediction_time = params.prediction_time or self.prediction_time
    
    debug.log("Updated obstacle avoidance parameters", "OBSTACLE_AVOIDANCE")
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:enable_avoidance_features
function ObstacleAvoidanceSystem:enable_avoidance_features(ally_avoidance, enemy_detection, formation_awareness)
    self.ally_avoidance = ally_avoidance ~= nil and ally_avoidance or self.ally_avoidance
    self.enemy_detection = enemy_detection ~= nil and enemy_detection or self.enemy_detection
    self.formation_awareness = formation_awareness ~= nil and formation_awareness or self.formation_awareness
    
    debug.log("Updated avoidance features", "OBSTACLE_AVOIDANCE")
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:get_debug_info
function ObstacleAvoidanceSystem:get_debug_info()
    local avoiding_count = 0
    local total_nearby = 0
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data"
    })
    
    for _, unit in ipairs(units) do
        local unit_data = self.entity_manager:get_component(unit, "unit_data")
        if unit_data then
            if unit_data.avoiding_obstacles then
                avoiding_count = avoiding_count + 1
            end
            total_nearby = total_nearby + (unit_data.nearby_unit_count or 0)
        end
    end
    
    return {
        units_avoiding = avoiding_count,
        total_units = #units,
        average_nearby_units = #units > 0 and (total_nearby / #units) or 0,
        spatial_grid_cells = self:count_table(self.spatial_grid),
        ally_avoidance = self.ally_avoidance,
        enemy_detection = self.enemy_detection,
        formation_awareness = self.formation_awareness
    }
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:count_table
function ObstacleAvoidanceSystem:count_table(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:constrain_force_to_lane
function ObstacleAvoidanceSystem:constrain_force_to_lane(unit, force)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position or not self.unit_movement_system then
        return force
    end
    
    local assignment = self.unit_movement_system:get_unit_assignment(unit)
    if not assignment or not assignment.sub_path then
        return force
    end
    
    local sub_path = assignment.sub_path
    local current_pos = Vector2:new(position.x, position.y)
    
    -- Test if the force would take the unit out of bounds
    local test_position = current_pos:add(force:multiply(0.1))  -- Small test step
    
    -- Check bounds using simplified boundary checking
    if not self:is_position_in_sub_path(test_position, sub_path) then
        -- Project force to stay within lane boundaries
        local path_direction = self:get_path_direction_at_position(unit, sub_path)
        if path_direction and path_direction:length() > 0 then
            local parallel_component = force:dot(path_direction)
            -- Keep only the component parallel to the path
            return path_direction:multiply(parallel_component)
        end
    end
    
    return force
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:is_position_in_sub_path
function ObstacleAvoidanceSystem:is_position_in_sub_path(position, sub_path)
    -- Simplified boundary check - assume sub-path has width constraint
    local path_width = sub_path.width or 12
    local center_line = sub_path.center_line or {}
    
    if #center_line == 0 then
        return true  -- No constraints available
    end
    
    -- Find closest point on center line
    local min_distance = math.huge
    for i = 1, #center_line do
        local distance = position:distance_to(center_line[i])
        min_distance = math.min(min_distance, distance)
    end
    
    return min_distance <= path_width / 2
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:get_path_direction_at_position
function ObstacleAvoidanceSystem:get_path_direction_at_position(unit, sub_path)
    local position = self.entity_manager:get_component(unit, "position")
    if not position then
        return Vector2:new(1, 0)  -- Default direction
    end
    
    local center_line = sub_path.center_line or {}
    if #center_line < 2 then
        return Vector2:new(1, 0)  -- Default direction
    end
    
    -- Find closest segment and return its direction
    local current_pos = Vector2:new(position.x, position.y)
    local closest_distance = math.huge
    local best_direction = Vector2:new(1, 0)
    
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        local segment_center = segment_start:add(segment_end):divide(2)
        
        local distance = current_pos:distance_to(segment_center)
        if distance < closest_distance then
            closest_distance = distance
            local direction = segment_end:subtract(segment_start)
            if direction:length() > 0 then
                best_direction = direction:normalize()
            end
        end
    end
    
    return best_direction
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:ensure_lane_boundaries
function ObstacleAvoidanceSystem:ensure_lane_boundaries(unit, new_position)
    if not self.unit_movement_system then
        return new_position
    end
    
    local assignment = self.unit_movement_system:get_unit_assignment(unit)
    if not assignment or not assignment.sub_path then
        return new_position
    end
    
    local sub_path = assignment.sub_path
    
    -- Check if new position is within bounds
    if self:is_position_in_sub_path(new_position, sub_path) then
        return new_position
    end
    
    -- Correct position to stay within bounds
    local center_line = sub_path.center_line or {}
    if #center_line == 0 then
        return new_position
    end
    
    -- Find closest point on center line
    local closest_point = center_line[1]
    local min_distance = new_position:distance_to(closest_point)
    
    for i = 2, #center_line do
        local distance = new_position:distance_to(center_line[i])
        if distance < min_distance then
            min_distance = distance
            closest_point = center_line[i]
        end
    end
    
    -- Move toward center line if outside bounds
    local path_width = sub_path.width or 12
    local max_distance = path_width / 2
    
    if min_distance > max_distance then
        local direction_to_center = closest_point:subtract(new_position):normalize()
        return closest_point:subtract(direction_to_center:multiply(max_distance * 0.9))
    end
    
    return new_position
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:create_flow_field_around_obstacle
function ObstacleAvoidanceSystem:create_flow_field_around_obstacle(obstacle_position, avoidance_radius)
    -- Create smooth flow field for units to follow around obstacles
    local flow_vectors = {}
    local field_resolution = 8  -- Points around obstacle
    
    for i = 0, field_resolution - 1 do
        local angle = (i / field_resolution) * 2 * math.pi
        local offset_x = math.cos(angle) * avoidance_radius
        local offset_y = math.sin(angle) * avoidance_radius
        
        local field_point = obstacle_position:add(Vector2:new(offset_x, offset_y))
        
        -- Flow direction is tangent to circle around obstacle
        local flow_direction = Vector2:new(-math.sin(angle), math.cos(angle))
        
        table.insert(flow_vectors, {
            position = field_point,
            direction = flow_direction
        })
    end
    
    return flow_vectors
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:get_relevant_sub_paths
function ObstacleAvoidanceSystem:get_relevant_sub_paths(unit)
    if not self.unit_movement_system then
        return {}
    end
    
    local assignment = self.unit_movement_system:get_unit_assignment(unit)
    if not assignment or not assignment.sub_path then
        return {}
    end
    
    local relevant_paths = {assignment.sub_path.id}
    
    -- Add adjacent sub-paths in the same lane if available
    if assignment.lane and assignment.lane.sub_paths then
        for _, sub_path in ipairs(assignment.lane.sub_paths) do
            if sub_path.id ~= assignment.sub_path.id then
                table.insert(relevant_paths, sub_path.id)
            end
        end
    end
    
    return relevant_paths
end
-- }}}

-- {{{ ObstacleAvoidanceSystem:calculate_collision_risk_weight
function ObstacleAvoidanceSystem:calculate_collision_risk_weight(unit, other_unit)
    local moveable1 = self.entity_manager:get_component(unit, "moveable")
    local moveable2 = self.entity_manager:get_component(other_unit, "moveable")
    local position1 = self.entity_manager:get_component(unit, "position")
    local position2 = self.entity_manager:get_component(other_unit, "position")
    
    if not moveable1 or not moveable2 or not position1 or not position2 then
        return 1.0
    end
    
    -- Calculate relative velocity
    local velocity1 = Vector2:new(moveable1.velocity_x, moveable1.velocity_y)
    local velocity2 = Vector2:new(moveable2.velocity_x, moveable2.velocity_y)
    local relative_velocity = velocity1:subtract(velocity2)
    
    -- Calculate position difference
    local pos1 = Vector2:new(position1.x, position1.y)
    local pos2 = Vector2:new(position2.x, position2.y)
    local position_diff = pos1:subtract(pos2)
    
    -- If units are moving toward each other, increase avoidance weight
    local approach_factor = relative_velocity:dot(position_diff)
    
    if approach_factor < 0 then
        -- Units are approaching each other
        return 2.0
    else
        -- Units are moving away or parallel
        return 1.0
    end
end
-- }}}

return ObstacleAvoidanceSystem
-- }}}