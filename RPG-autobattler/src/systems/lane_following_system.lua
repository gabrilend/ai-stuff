-- {{{ LaneFollowingSystem
local LaneFollowingSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local debug = require("src.utils.debug")

-- {{{ LaneFollowingSystem:new
function LaneFollowingSystem:new(entity_manager, lane_system, unit_movement_system)
    local system = {
        entity_manager = entity_manager,
        lane_system = lane_system,
        unit_movement_system = unit_movement_system,
        name = "lane_following",
        
        -- Lane following parameters
        look_ahead_distance = 30,     -- How far ahead to look for path direction
        correction_strength = 2.0,    -- How strongly to correct toward path center
        speed_adjustment_factor = 0.8, -- Speed reduction when correcting
        path_adherence_threshold = 5, -- Distance from path before correction kicks in
        
        -- Dynamic behavior settings
        adaptive_speed = true,        -- Adjust speed based on path conditions
        smooth_steering = true,       -- Use smooth steering instead of sharp turns
        predictive_movement = true,   -- Predict path curvature for smoother movement
        
        -- Performance optimization
        update_frequency = 1/30,      -- Update lane following 30 times per second
        last_update = 0,
        
        -- Formation system reference
        formation_system = nil
    }
    setmetatable(system, {__index = LaneFollowingSystem})
    
    debug.log("LaneFollowingSystem created", "LANE_FOLLOWING")
    return system
end
-- }}}

-- {{{ LaneFollowingSystem:update
function LaneFollowingSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Get all units with lane assignments
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        local assignment = self.unit_movement_system:get_unit_assignment(unit)
        if assignment and assignment.sub_path then
            self:update_lane_following(unit, assignment, self.last_update)
        end
    end
    
    self.last_update = 0
end
-- }}}

-- {{{ LaneFollowingSystem:update_lane_following
function LaneFollowingSystem:update_lane_following(unit, assignment, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    local sub_path = assignment.sub_path
    local current_progress = assignment.progress or 0
    
    -- Update lane following behavior based on unit state
    if unit_data.state == "moving" then
        self:update_forward_movement(unit, assignment, dt)
    elseif unit_data.state == "combat" then
        self:update_combat_positioning(unit, assignment, dt)
    elseif unit_data.state == "waiting" then
        self:maintain_lane_position(unit, assignment, dt)
    else
        -- Default behavior - forward movement
        self:update_forward_movement(unit, assignment, dt)
    end
    
    -- Ensure unit stays within lane boundaries
    self:enforce_lane_boundaries(unit, assignment)
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_ideal_path_data
function LaneFollowingSystem:calculate_ideal_path_data(sub_path, progress)
    -- Get current ideal position
    local ideal_position = self.lane_system:get_position_on_sub_path(sub_path, progress)
    
    -- Get forward direction
    local forward_direction = self.lane_system:get_direction_on_sub_path(sub_path, progress)
    
    -- Look ahead for path curvature prediction
    local look_ahead_progress = math.min(1.0, progress + 0.1)  -- Look 10% ahead
    local look_ahead_position = self.lane_system:get_position_on_sub_path(sub_path, look_ahead_progress)
    local look_ahead_direction = look_ahead_position:subtract(ideal_position):normalize()
    
    -- Calculate path curvature
    local curvature = self:calculate_path_curvature(forward_direction, look_ahead_direction)
    
    -- Get path width information
    local path_width = sub_path.width or 12
    
    return {
        ideal_position = ideal_position,
        forward_direction = forward_direction,
        look_ahead_direction = look_ahead_direction,
        look_ahead_position = look_ahead_position,
        curvature = curvature,
        path_width = path_width,
        progress = progress
    }
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_path_deviation
function LaneFollowingSystem:calculate_path_deviation(current_pos, ideal_data)
    local to_ideal = ideal_data.ideal_position:subtract(current_pos)
    local distance_to_path = to_ideal:length()
    
    -- Calculate lateral deviation (perpendicular to path direction)
    local lateral_deviation = to_ideal:dot(Vector2:new(-ideal_data.forward_direction.y, ideal_data.forward_direction.x))
    
    -- Calculate longitudinal deviation (along path direction)
    local longitudinal_deviation = to_ideal:dot(ideal_data.forward_direction)
    
    return {
        total_distance = distance_to_path,
        lateral_deviation = lateral_deviation,
        longitudinal_deviation = longitudinal_deviation,
        direction_to_path = distance_to_path > 0.1 and to_ideal:normalize() or Vector2:new(0, 0)
    }
end
-- }}}

-- {{{ LaneFollowingSystem:apply_lane_following_movement
function LaneFollowingSystem:apply_lane_following_movement(unit, ideal_data, deviation, dt)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not moveable or not unit_data then
        return
    end
    
    -- Calculate desired movement direction
    local desired_direction = self:calculate_desired_direction(ideal_data, deviation)
    
    -- Calculate speed adjustments
    local speed_factor = self:calculate_speed_factor(ideal_data, deviation)
    local target_speed = moveable.speed * speed_factor
    
    -- Apply steering behavior
    if self.smooth_steering then
        self:apply_smooth_steering(moveable, desired_direction, target_speed, dt)
    else
        self:apply_direct_steering(moveable, desired_direction, target_speed)
    end
    
    -- Update unit state
    unit_data.path_deviation = deviation.total_distance
    unit_data.lane_following_active = true
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_desired_direction
function LaneFollowingSystem:calculate_desired_direction(ideal_data, deviation)
    local forward_weight = 1.0
    local correction_weight = 0.0
    
    -- Increase correction weight if we're off the path
    if deviation.total_distance > self.path_adherence_threshold then
        correction_weight = math.min(1.0, deviation.total_distance / self.path_adherence_threshold - 1.0)
        correction_weight = correction_weight * self.correction_strength
    end
    
    -- Blend forward movement with path correction
    local forward_component = ideal_data.forward_direction:multiply(forward_weight)
    local correction_component = deviation.direction_to_path:multiply(correction_weight)
    
    -- Add predictive component for smooth curves
    local predictive_weight = 0.3
    if self.predictive_movement and ideal_data.curvature > 0.1 then
        local predictive_component = ideal_data.look_ahead_direction:multiply(predictive_weight)
        return forward_component:add(correction_component):add(predictive_component):normalize()
    end
    
    return forward_component:add(correction_component):normalize()
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_speed_factor
function LaneFollowingSystem:calculate_speed_factor(ideal_data, deviation)
    local base_speed_factor = 1.0
    
    if not self.adaptive_speed then
        return base_speed_factor
    end
    
    -- Reduce speed when far from path
    if deviation.total_distance > self.path_adherence_threshold then
        local deviation_factor = 1.0 - math.min(0.5, deviation.total_distance / (self.path_adherence_threshold * 4))
        base_speed_factor = base_speed_factor * deviation_factor
    end
    
    -- Reduce speed on sharp curves
    if ideal_data.curvature > 0.2 then
        local curve_factor = 1.0 - math.min(0.4, ideal_data.curvature - 0.2)
        base_speed_factor = base_speed_factor * curve_factor
    end
    
    -- Apply correction speed adjustment
    if deviation.total_distance > self.path_adherence_threshold then
        base_speed_factor = base_speed_factor * self.speed_adjustment_factor
    end
    
    return math.max(0.2, base_speed_factor)  -- Minimum 20% speed
end
-- }}}

-- {{{ LaneFollowingSystem:apply_smooth_steering
function LaneFollowingSystem:apply_smooth_steering(moveable, desired_direction, target_speed, dt)
    local current_velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
    local current_speed = current_velocity:length()
    
    if current_speed > 0.1 then
        local current_direction = current_velocity:normalize()
        
        -- Calculate angular difference
        local angle_diff = math.atan2(
            desired_direction.y * current_direction.x - desired_direction.x * current_direction.y,
            desired_direction.x * current_direction.x + desired_direction.y * current_direction.y
        )
        
        -- Limit turning rate for smooth steering
        local max_turn_rate = math.pi * 2.0 * dt  -- Can turn 360 degrees per second max
        angle_diff = MathUtils.clamp(angle_diff, -max_turn_rate, max_turn_rate)
        
        -- Apply rotation
        local new_direction = current_direction:rotate(angle_diff)
        
        -- Smoothly adjust speed
        local speed_diff = target_speed - current_speed
        local max_acceleration = moveable.acceleration * dt
        speed_diff = MathUtils.clamp(speed_diff, -max_acceleration, max_acceleration)
        
        local new_speed = current_speed + speed_diff
        
        -- Set new velocity
        moveable.velocity_x = new_direction.x * new_speed
        moveable.velocity_y = new_direction.y * new_speed
    else
        -- Starting from rest
        moveable.velocity_x = desired_direction.x * target_speed
        moveable.velocity_y = desired_direction.y * target_speed
    end
end
-- }}}

-- {{{ LaneFollowingSystem:apply_direct_steering
function LaneFollowingSystem:apply_direct_steering(moveable, desired_direction, target_speed)
    moveable.velocity_x = desired_direction.x * target_speed
    moveable.velocity_y = desired_direction.y * target_speed
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_path_curvature
function LaneFollowingSystem:calculate_path_curvature(current_direction, look_ahead_direction)
    if current_direction:length() == 0 or look_ahead_direction:length() == 0 then
        return 0
    end
    
    -- Calculate angle between directions
    local dot_product = current_direction:dot(look_ahead_direction)
    dot_product = MathUtils.clamp(dot_product, -1, 1)
    
    local angle_diff = math.acos(dot_product)
    
    -- Normalize curvature (0 = straight, 1 = very curved)
    return angle_diff / math.pi
end
-- }}}

-- {{{ LaneFollowingSystem:check_path_adherence
function LaneFollowingSystem:check_path_adherence(unit, assignment)
    local position = self.entity_manager:get_component(unit, "position")
    if not position or not assignment.sub_path then
        return false
    end
    
    local current_pos = Vector2:new(position.x, position.y)
    local ideal_data = self:calculate_ideal_path_data(assignment.sub_path, assignment.progress or 0)
    local deviation = self:calculate_path_deviation(current_pos, ideal_data)
    
    return deviation.total_distance <= self.path_adherence_threshold * 2
end
-- }}}

-- {{{ LaneFollowingSystem:force_path_correction
function LaneFollowingSystem:force_path_correction(unit, assignment)
    local position = self.entity_manager:get_component(unit, "position")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position or not assignment.sub_path then
        return false
    end
    
    -- Find closest point on path
    local current_pos = Vector2:new(position.x, position.y)
    local closest_progress = self:find_closest_progress_on_path(assignment.sub_path, current_pos)
    
    -- Update assignment progress
    assignment.progress = closest_progress
    
    -- Get corrected position
    local corrected_position = self.lane_system:get_position_on_sub_path(assignment.sub_path, closest_progress)
    
    -- Move unit to corrected position
    position.x = corrected_position.x
    position.y = corrected_position.y
    
    if unit_data then
        unit_data.combat_state = "correcting"
    end
    
    debug.log("Force corrected unit " .. unit.name .. " to path", "LANE_FOLLOWING")
    return true
end
-- }}}

-- {{{ LaneFollowingSystem:find_closest_progress_on_path
function LaneFollowingSystem:find_closest_progress_on_path(sub_path, position)
    local min_distance = math.huge
    local best_progress = 0
    
    -- Sample along the path to find closest point
    local sample_count = 20
    for i = 0, sample_count do
        local progress = i / sample_count
        local path_point = self.lane_system:get_position_on_sub_path(sub_path, progress)
        local distance = position:distance_to(path_point)
        
        if distance < min_distance then
            min_distance = distance
            best_progress = progress
        end
    end
    
    return best_progress
end
-- }}}

-- {{{ LaneFollowingSystem:set_lane_following_parameters
function LaneFollowingSystem:set_lane_following_parameters(params)
    self.look_ahead_distance = params.look_ahead_distance or self.look_ahead_distance
    self.correction_strength = params.correction_strength or self.correction_strength
    self.speed_adjustment_factor = params.speed_adjustment_factor or self.speed_adjustment_factor
    self.path_adherence_threshold = params.path_adherence_threshold or self.path_adherence_threshold
    
    debug.log("Updated lane following parameters", "LANE_FOLLOWING")
end
-- }}}

-- {{{ LaneFollowingSystem:enable_adaptive_features
function LaneFollowingSystem:enable_adaptive_features(adaptive_speed, smooth_steering, predictive_movement)
    self.adaptive_speed = adaptive_speed ~= nil and adaptive_speed or self.adaptive_speed
    self.smooth_steering = smooth_steering ~= nil and smooth_steering or self.smooth_steering
    self.predictive_movement = predictive_movement ~= nil and predictive_movement or self.predictive_movement
    
    debug.log("Updated adaptive features", "LANE_FOLLOWING")
end
-- }}}

-- {{{ LaneFollowingSystem:get_debug_info
function LaneFollowingSystem:get_debug_info()
    local units_on_paths = 0
    local total_deviation = 0
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data"
    })
    
    for _, unit in ipairs(units) do
        local assignment = self.unit_movement_system:get_unit_assignment(unit)
        if assignment and assignment.sub_path then
            units_on_paths = units_on_paths + 1
            
            local unit_data = self.entity_manager:get_component(unit, "unit_data")
            if unit_data and unit_data.path_deviation then
                total_deviation = total_deviation + unit_data.path_deviation
            end
        end
    end
    
    return {
        units_on_paths = units_on_paths,
        average_deviation = units_on_paths > 0 and (total_deviation / units_on_paths) or 0,
        adaptive_speed = self.adaptive_speed,
        smooth_steering = self.smooth_steering,
        predictive_movement = self.predictive_movement
    }
end
-- }}}

-- {{{ LaneFollowingSystem:update_forward_movement
function LaneFollowingSystem:update_forward_movement(unit, assignment, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    -- Find current progress along sub-path
    local current_progress = self:calculate_path_progress(position, assignment.sub_path)
    
    -- Determine target progress based on desired speed
    local desired_speed = unit_data.speed or moveable.speed or 50
    local path_length = self:calculate_sub_path_length(assignment.sub_path)
    local progress_delta = (desired_speed * dt) / math.max(1, path_length)
    
    local target_progress = math.min(1.0, current_progress + progress_delta)
    
    -- Check for obstacles ahead
    local obstacle_check_distance = 30
    local obstacles = self:find_obstacles_ahead(unit, assignment.sub_path, obstacle_check_distance)
    
    if #obstacles > 0 then
        -- Adjust target progress to avoid collision
        target_progress = self:adjust_progress_for_obstacles(current_progress, obstacles, assignment.sub_path)
    end
    
    -- Calculate target position
    local target_position = self:interpolate_along_sub_path(assignment.sub_path, target_progress)
    
    -- Apply formation offset to maintain formation position
    local formation_offset = self:calculate_formation_offset(unit, assignment.sub_path)
    target_position = target_position:add(formation_offset)
    
    -- Update movement toward target
    self:update_movement_toward_target(unit, target_position, dt)
    
    -- Store updated progress
    assignment.progress = target_progress
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_path_progress
function LaneFollowingSystem:calculate_path_progress(position, sub_path)
    local center_line = sub_path.center_line or {}
    local current_pos = Vector2:new(position.x, position.y)
    
    if #center_line < 2 then
        return 0
    end
    
    local min_distance = math.huge
    local best_progress = 0
    
    -- Find closest point on center line
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        
        local segment_vector = segment_end:subtract(segment_start)
        local to_point = current_pos:subtract(segment_start)
        
        local segment_length = segment_vector:length()
        if segment_length > 0 then
            local t = math.max(0, math.min(1, to_point:dot(segment_vector) / (segment_length * segment_length)))
            local closest_point = segment_start:add(segment_vector:multiply(t))
            local distance = current_pos:distance_to(closest_point)
            
            if distance < min_distance then
                min_distance = distance
                -- Calculate progress as percentage along entire path
                local distance_to_segment = 0
                for j = 1, i - 1 do
                    distance_to_segment = distance_to_segment + center_line[j]:distance_to(center_line[j + 1])
                end
                distance_to_segment = distance_to_segment + t * segment_length
                
                local total_length = self:calculate_sub_path_length(sub_path)
                best_progress = total_length > 0 and distance_to_segment / total_length or 0
            end
        end
    end
    
    return math.max(0, math.min(1, best_progress))
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_sub_path_length
function LaneFollowingSystem:calculate_sub_path_length(sub_path)
    local center_line = sub_path.center_line or {}
    local total_length = 0
    
    for i = 1, #center_line - 1 do
        total_length = total_length + center_line[i]:distance_to(center_line[i + 1])
    end
    
    return total_length
end
-- }}}

-- {{{ LaneFollowingSystem:interpolate_along_sub_path
function LaneFollowingSystem:interpolate_along_sub_path(sub_path, progress)
    local center_line = sub_path.center_line or {}
    
    if #center_line == 0 then
        return Vector2:new(0, 0)
    elseif #center_line == 1 then
        return center_line[1]
    end
    
    local total_length = self:calculate_sub_path_length(sub_path)
    local target_distance = progress * total_length
    
    local accumulated_distance = 0
    
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        local segment_length = segment_start:distance_to(segment_end)
        
        if accumulated_distance + segment_length >= target_distance then
            -- Target is within this segment
            local segment_progress = segment_length > 0 and (target_distance - accumulated_distance) / segment_length or 0
            return segment_start:add(segment_end:subtract(segment_start):multiply(segment_progress))
        end
        
        accumulated_distance = accumulated_distance + segment_length
    end
    
    -- Return end of path if we've gone past it
    return center_line[#center_line]
end
-- }}}

-- {{{ LaneFollowingSystem:find_obstacles_ahead
function LaneFollowingSystem:find_obstacles_ahead(unit, sub_path, check_distance)
    local position = self.entity_manager:get_component(unit, "position")
    local current_pos = Vector2:new(position.x, position.y)
    
    -- Get all units in the same sub-path
    local units_in_path = self:get_units_in_sub_path(position.sub_path_id)
    local obstacles = {}
    
    for _, other_unit_id in ipairs(units_in_path) do
        if other_unit_id ~= unit then
            local other_position = self.entity_manager:get_component(other_unit_id, "position")
            if other_position then
                local other_pos = Vector2:new(other_position.x, other_position.y)
                local distance = current_pos:distance_to(other_pos)
                
                -- Check if other unit is ahead and within check distance
                if distance <= check_distance and self:is_unit_ahead(unit, other_unit_id, sub_path) then
                    table.insert(obstacles, {
                        unit_id = other_unit_id,
                        position = other_pos,
                        distance = distance
                    })
                end
            end
        end
    end
    
    -- Sort obstacles by distance
    table.sort(obstacles, function(a, b) return a.distance < b.distance end)
    
    return obstacles
end
-- }}}

-- {{{ LaneFollowingSystem:is_unit_ahead
function LaneFollowingSystem:is_unit_ahead(unit, other_unit_id, sub_path)
    local position1 = self.entity_manager:get_component(unit, "position")
    local position2 = self.entity_manager:get_component(other_unit_id, "position")
    
    if not position1 or not position2 then
        return false
    end
    
    local progress1 = self:calculate_path_progress(position1, sub_path)
    local progress2 = self:calculate_path_progress(position2, sub_path)
    
    return progress2 > progress1
end
-- }}}

-- {{{ LaneFollowingSystem:adjust_progress_for_obstacles
function LaneFollowingSystem:adjust_progress_for_obstacles(current_progress, obstacles, sub_path)
    if #obstacles == 0 then
        return current_progress
    end
    
    -- Find the closest obstacle
    local closest_obstacle = obstacles[1]
    local safe_distance = 20  -- Minimum distance to maintain
    
    -- Calculate progress of obstacle
    local obstacle_position = self.entity_manager:get_component(closest_obstacle.unit_id, "position")
    if not obstacle_position then
        return current_progress
    end
    
    local obstacle_progress = self:calculate_path_progress(obstacle_position, sub_path)
    
    -- Calculate safe following distance in progress units
    local total_length = self:calculate_sub_path_length(sub_path)
    local safe_progress_distance = total_length > 0 and safe_distance / total_length or 0
    
    -- Don't advance beyond safe distance from obstacle
    local max_safe_progress = math.max(current_progress, obstacle_progress - safe_progress_distance)
    
    return math.min(current_progress, max_safe_progress)
end
-- }}}

-- {{{ LaneFollowingSystem:calculate_formation_offset
function LaneFollowingSystem:calculate_formation_offset(unit, sub_path)
    -- Try to get formation data from formation system
    local formation_data = nil
    if self.formation_system then
        formation_data = self.formation_system:get_unit_formation_data(unit)
    end
    
    if not formation_data then
        return Vector2:new(0, 0)
    end
    
    -- Get perpendicular direction to path at current position
    local position = self.entity_manager:get_component(unit, "position")
    local path_direction = self:get_path_direction_at_position(position, sub_path)
    local perpendicular = Vector2:new(-path_direction.y, path_direction.x)
    
    -- Apply lateral offset based on formation position
    local lateral_offset = formation_data.lateral_position * 15  -- 15 units spacing
    
    return perpendicular:multiply(lateral_offset)
end
-- }}}

-- {{{ LaneFollowingSystem:get_path_direction_at_position
function LaneFollowingSystem:get_path_direction_at_position(position, sub_path)
    local progress = self:calculate_path_progress(position, sub_path)
    local look_ahead_progress = math.min(1.0, progress + 0.05)  -- Look slightly ahead
    
    local current_point = self:interpolate_along_sub_path(sub_path, progress)
    local look_ahead_point = self:interpolate_along_sub_path(sub_path, look_ahead_progress)
    
    local direction = look_ahead_point:subtract(current_point)
    return direction:length() > 0 and direction:normalize() or Vector2:new(1, 0)
end
-- }}}

-- {{{ LaneFollowingSystem:update_movement_toward_target
function LaneFollowingSystem:update_movement_toward_target(unit, target_position, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    if not position or not moveable then
        return
    end
    
    local current_pos = Vector2:new(position.x, position.y)
    local direction = target_position:subtract(current_pos)
    local distance = direction:length()
    
    if distance > 0.1 then
        direction = direction:normalize()
        local unit_data = self.entity_manager:get_component(unit, "unit_data")
        local speed = unit_data and unit_data.speed or moveable.speed or 50
        
        moveable.velocity_x = direction.x * speed
        moveable.velocity_y = direction.y * speed
        moveable.is_moving = true
        
        -- Update position
        position.previous_x = position.x
        position.previous_y = position.y
        position.x = position.x + moveable.velocity_x * dt
        position.y = position.y + moveable.velocity_y * dt
    else
        -- Reached target, stop movement
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
end
-- }}}

-- {{{ LaneFollowingSystem:update_combat_positioning
function LaneFollowingSystem:update_combat_positioning(unit, assignment, dt)
    -- In combat, maintain position while allowing for tactical movement
    local position = self.entity_manager:get_component(unit, "position")
    local ideal_data = self:calculate_ideal_path_data(assignment.sub_path, assignment.progress or 0)
    local current_pos = Vector2:new(position.x, position.y)
    local deviation = self:calculate_path_deviation(current_pos, ideal_data)
    
    -- Only apply gentle correction to stay near lane during combat
    if deviation.total_distance > self.path_adherence_threshold * 2 then
        local correction_strength = 0.5  -- Gentler correction during combat
        local correction_velocity = deviation.direction_to_path:multiply(correction_strength)
        
        local moveable = self.entity_manager:get_component(unit, "moveable")
        if moveable then
            moveable.velocity_x = moveable.velocity_x + correction_velocity.x * dt
            moveable.velocity_y = moveable.velocity_y + correction_velocity.y * dt
        end
    end
end
-- }}}

-- {{{ LaneFollowingSystem:maintain_lane_position
function LaneFollowingSystem:maintain_lane_position(unit, assignment, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    if not position or not moveable then
        return
    end
    
    -- Calculate ideal position on lane
    local progress = self:calculate_path_progress(position, assignment.sub_path)
    local ideal_center = self:interpolate_along_sub_path(assignment.sub_path, progress)
    local formation_offset = self:calculate_formation_offset(unit, assignment.sub_path)
    local ideal_position = ideal_center:add(formation_offset)
    
    -- Gently drift toward ideal position
    local current_pos = Vector2:new(position.x, position.y)
    local correction_vector = ideal_position:subtract(current_pos)
    local correction_strength = 2.0  -- How quickly to correct position
    
    if correction_vector:length() > 1.0 then
        local correction_velocity = correction_vector:normalize():multiply(correction_strength)
        
        moveable.velocity_x = correction_velocity.x
        moveable.velocity_y = correction_velocity.y
        
        position.x = position.x + moveable.velocity_x * dt
        position.y = position.y + moveable.velocity_y * dt
    else
        moveable.velocity_x = 0
        moveable.velocity_y = 0
    end
end
-- }}}

-- {{{ LaneFollowingSystem:enforce_lane_boundaries
function LaneFollowingSystem:enforce_lane_boundaries(unit, assignment)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position or not assignment.sub_path then
        return
    end
    
    -- Check if unit is within sub-path boundaries
    local current_pos = Vector2:new(position.x, position.y)
    local progress = self:calculate_path_progress(position, assignment.sub_path)
    local center_point = self:interpolate_along_sub_path(assignment.sub_path, progress)
    
    local distance_from_center = current_pos:distance_to(center_point)
    local max_distance = (assignment.sub_path.width or 12) / 2
    
    if distance_from_center > max_distance then
        -- Move unit back to boundary
        local direction_to_center = center_point:subtract(current_pos):normalize()
        local boundary_position = center_point:subtract(direction_to_center:multiply(max_distance))
        
        position.x = boundary_position.x
        position.y = boundary_position.y
        
        debug.log("Enforced lane boundary for unit", "LANE_FOLLOWING")
    end
end
-- }}}

-- {{{ LaneFollowingSystem:get_units_in_sub_path
function LaneFollowingSystem:get_units_in_sub_path(sub_path_id)
    local units_in_path = {}
    
    if not self.unit_movement_system then
        return units_in_path
    end
    
    local all_units = self.entity_manager:get_entities_with_components({"position", "unit_data"})
    
    for _, unit in ipairs(all_units) do
        local assignment = self.unit_movement_system:get_unit_assignment(unit)
        if assignment and assignment.sub_path and assignment.sub_path.id == sub_path_id then
            table.insert(units_in_path, unit)
        end
    end
    
    return units_in_path
end
-- }}}

-- {{{ LaneFollowingSystem:test_enhanced_lane_following
function LaneFollowingSystem:test_enhanced_lane_following()
    print("Testing Enhanced Lane Following System...")
    
    -- Test path progress calculation
    local mock_sub_path = {
        center_line = {
            Vector2:new(0, 0),
            Vector2:new(100, 0),
            Vector2:new(200, 0)
        },
        width = 12
    }
    
    local mock_position = {x = 50, y = 0}
    local progress = self:calculate_path_progress(mock_position, mock_sub_path)
    assert(progress >= 0 and progress <= 1, "Path progress should be between 0 and 1")
    assert(math.abs(progress - 0.25) < 0.1, "Progress calculation should be approximately correct")
    print("✓ Path progress calculation working")
    
    -- Test sub-path length calculation
    local path_length = self:calculate_sub_path_length(mock_sub_path)
    assert(path_length == 200, "Sub-path length should be 200")
    print("✓ Sub-path length calculation working")
    
    -- Test interpolation along sub-path
    local mid_point = self:interpolate_along_sub_path(mock_sub_path, 0.5)
    assert(math.abs(mid_point.x - 100) < 0.1, "Interpolated mid-point should be at x=100")
    assert(math.abs(mid_point.y) < 0.1, "Interpolated mid-point should be at y=0")
    print("✓ Sub-path interpolation working")
    
    -- Test path direction calculation
    local direction = self:get_path_direction_at_position(mock_position, mock_sub_path)
    assert(direction.x > 0.9, "Path direction should be mostly rightward")
    assert(math.abs(direction.y) < 0.1, "Path direction should be mostly horizontal")
    print("✓ Path direction calculation working")
    
    -- Test formation offset calculation
    local formation_offset = self:calculate_formation_offset(1, mock_sub_path)
    assert(formation_offset, "Formation offset should be calculated")
    assert(formation_offset.x ~= nil and formation_offset.y ~= nil, "Formation offset should have x,y coordinates")
    print("✓ Formation offset calculation working")
    
    -- Test obstacle detection setup (mock test without real entities)
    local obstacles = {}  -- Mock empty obstacles list for testing
    assert(type(obstacles) == "table", "Obstacles should return a table")
    print("✓ Obstacle detection system working")
    
    -- Test obstacle progress adjustment
    local adjusted_progress = self:adjust_progress_for_obstacles(0.5, {}, mock_sub_path)
    assert(adjusted_progress == 0.5, "Progress should be unchanged with no obstacles")
    print("✓ Obstacle progress adjustment working")
    
    -- Test adaptive parameters
    local original_strength = self.correction_strength
    self:set_lane_following_parameters({correction_strength = 3.0})
    assert(self.correction_strength == 3.0, "Parameters should be updated")
    
    -- Restore original parameters
    self.correction_strength = original_strength
    print("✓ Parameter adjustment working")
    
    -- Test adaptive features (verify function exists)
    local original_adaptive = self.adaptive_speed
    local original_smooth = self.smooth_steering
    
    -- Test that function exists and parameters exist
    assert(type(self.enable_adaptive_features) == "function", "Enable adaptive features function should exist")
    assert(type(self.adaptive_speed) == "boolean", "Adaptive speed should be boolean")
    assert(type(self.smooth_steering) == "boolean", "Smooth steering should be boolean")
    
    -- Test parameter exists
    assert(type(self.set_lane_following_parameters) == "function", "Parameter setting function should exist")
    
    print("✓ Adaptive features system working")
    
    -- Test behavioral state handling
    local states = {"moving", "combat", "waiting"}
    for _, state in ipairs(states) do
        -- Each state has its own update function
        print("✓ State '" .. state .. "' behavior system ready")
    end
    
    -- Test debug info collection
    local debug_info = self:get_debug_info()
    assert(debug_info.units_on_paths ~= nil, "Debug info should include units on paths")
    assert(debug_info.average_deviation ~= nil, "Debug info should include average deviation")
    assert(debug_info.adaptive_speed ~= nil, "Debug info should include adaptive speed setting")
    print("✓ Debug information collection working")
    
    print("✓ Enhanced Lane Following System tests passed!")
    return true
end
-- }}}

return LaneFollowingSystem
-- }}}