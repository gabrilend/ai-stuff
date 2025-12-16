# Issue #021: Add Lane Following Behavior

## Current Behavior
Units can move along sub-paths but lack sophisticated lane following that maintains proper positioning and handles lane interactions.

## Intended Behavior
Units should follow their lanes with intelligent behavior including lane discipline, proper spacing, and smooth transitions along complex path geometries.

## Implementation Details

### Lane Following System (src/systems/lane_following_system.lua)
```lua
-- {{{ local function update_lane_following
local function update_lane_following(unit_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if not sub_path then
        return
    end
    
    -- Update lane following behavior based on unit state
    if unit_data.state == "moving" then
        update_forward_movement(unit_id, sub_path, dt)
    elseif unit_data.state == "combat" then
        update_combat_positioning(unit_id, sub_path, dt)
    elseif unit_data.state == "waiting" then
        maintain_lane_position(unit_id, sub_path, dt)
    end
    
    -- Ensure unit stays within lane boundaries
    enforce_lane_boundaries(unit_id, sub_path)
end
-- }}}

-- {{{ local function update_forward_movement
local function update_forward_movement(unit_id, sub_path, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    -- Find current progress along sub-path
    local path_progress = calculate_path_progress(position, sub_path)
    
    -- Determine target progress based on desired speed
    local desired_speed = unit_data.speed
    local path_length = calculate_sub_path_length(sub_path)
    local progress_delta = (desired_speed * dt) / path_length
    
    local target_progress = math.min(1.0, path_progress + progress_delta)
    
    -- Check for obstacles ahead
    local obstacle_check_distance = 30
    local obstacles = find_obstacles_ahead(unit_id, sub_path, obstacle_check_distance)
    
    if #obstacles > 0 then
        -- Adjust target progress to avoid collision
        target_progress = adjust_progress_for_obstacles(path_progress, obstacles, sub_path)
    end
    
    -- Calculate target position
    local target_position = interpolate_along_sub_path(sub_path, target_progress)
    
    -- Apply lane offset to maintain formation position
    local lane_offset = calculate_lane_offset(unit_id, sub_path)
    target_position = target_position:add(lane_offset)
    
    -- Update movement toward target
    update_movement_toward_target(unit_id, target_position, dt)
    
    -- Store updated progress
    position.path_progress = target_progress
end
-- }}}

-- {{{ local function calculate_path_progress
local function calculate_path_progress(position, sub_path)
    local center_line = sub_path.center_line
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
                
                local total_length = calculate_sub_path_length(sub_path)
                best_progress = total_length > 0 and distance_to_segment / total_length or 0
            end
        end
    end
    
    return math.max(0, math.min(1, best_progress))
end
-- }}}

-- {{{ local function interpolate_along_sub_path
local function interpolate_along_sub_path(sub_path, progress)
    local center_line = sub_path.center_line
    
    if #center_line == 0 then
        return Vector2:new(0, 0)
    elseif #center_line == 1 then
        return center_line[1]
    end
    
    local total_length = calculate_sub_path_length(sub_path)
    local target_distance = progress * total_length
    
    local accumulated_distance = 0
    
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        local segment_length = segment_start:distance_to(segment_end)
        
        if accumulated_distance + segment_length >= target_distance then
            -- Target is within this segment
            local segment_progress = (target_distance - accumulated_distance) / segment_length
            return segment_start:add(segment_end:subtract(segment_start):multiply(segment_progress))
        end
        
        accumulated_distance = accumulated_distance + segment_length
    end
    
    -- Return end of path if we've gone past it
    return center_line[#center_line]
end
-- }}}

-- {{{ local function calculate_lane_offset
local function calculate_lane_offset(unit_id, sub_path)
    local formation_data = FormationSystem:get_unit_formation_data(unit_id)
    
    if not formation_data then
        return Vector2:new(0, 0)
    end
    
    -- Get perpendicular direction to path at current position
    local position = EntityManager:get_component(unit_id, "position")
    local path_direction = get_path_direction_at_position(position, sub_path)
    local perpendicular = Vector2:new(-path_direction.y, path_direction.x)
    
    -- Apply lateral offset based on formation position
    local lateral_offset = formation_data.lateral_position * 15  -- 15 units spacing
    
    return perpendicular:multiply(lateral_offset)
end
-- }}}

-- {{{ local function find_obstacles_ahead
local function find_obstacles_ahead(unit_id, sub_path, check_distance)
    local position = EntityManager:get_component(unit_id, "position")
    local current_pos = Vector2:new(position.x, position.y)
    
    -- Get all units in the same sub-path
    local units_in_path = get_units_in_sub_path(position.sub_path_id)
    local obstacles = {}
    
    for _, other_unit_id in ipairs(units_in_path) do
        if other_unit_id ~= unit_id then
            local other_position = EntityManager:get_component(other_unit_id, "position")
            local other_pos = Vector2:new(other_position.x, other_position.y)
            
            local distance = current_pos:distance_to(other_pos)
            
            -- Check if other unit is ahead and within check distance
            if distance <= check_distance and is_unit_ahead(unit_id, other_unit_id, sub_path) then
                table.insert(obstacles, {
                    unit_id = other_unit_id,
                    position = other_pos,
                    distance = distance
                })
            end
        end
    end
    
    -- Sort obstacles by distance
    table.sort(obstacles, function(a, b) return a.distance < b.distance end)
    
    return obstacles
end
-- }}}

-- {{{ local function is_unit_ahead
local function is_unit_ahead(unit_id, other_unit_id, sub_path)
    local position1 = EntityManager:get_component(unit_id, "position")
    local position2 = EntityManager:get_component(other_unit_id, "position")
    
    local progress1 = calculate_path_progress(position1, sub_path)
    local progress2 = calculate_path_progress(position2, sub_path)
    
    return progress2 > progress1
end
-- }}}

-- {{{ local function adjust_progress_for_obstacles
local function adjust_progress_for_obstacles(current_progress, obstacles, sub_path)
    if #obstacles == 0 then
        return current_progress
    end
    
    -- Find the closest obstacle
    local closest_obstacle = obstacles[1]
    local safe_distance = 20  -- Minimum distance to maintain
    
    -- Calculate progress of obstacle
    local obstacle_position = EntityManager:get_component(closest_obstacle.unit_id, "position")
    local obstacle_progress = calculate_path_progress(obstacle_position, sub_path)
    
    -- Calculate safe following distance in progress units
    local total_length = calculate_sub_path_length(sub_path)
    local safe_progress_distance = safe_distance / total_length
    
    -- Don't advance beyond safe distance from obstacle
    local max_safe_progress = math.max(current_progress, obstacle_progress - safe_progress_distance)
    
    return max_safe_progress
end
-- }}}

-- {{{ local function maintain_lane_position
local function maintain_lane_position(unit_id, sub_path, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    -- Calculate ideal position on lane
    local progress = calculate_path_progress(position, sub_path)
    local ideal_center = interpolate_along_sub_path(sub_path, progress)
    local lane_offset = calculate_lane_offset(unit_id, sub_path)
    local ideal_position = ideal_center:add(lane_offset)
    
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
```

### Lane Following Features
1. **Path Progress Tracking**: Accurate position along sub-path
2. **Obstacle Avoidance**: Maintain safe following distance
3. **Formation Maintenance**: Preserve lateral positioning
4. **Smooth Interpolation**: Fluid movement along curved paths
5. **Lane Discipline**: Stay within designated sub-path

### Behavioral States
- **Moving**: Active forward progress along lane
- **Combat**: Positioning for engagement while respecting lane
- **Waiting**: Maintain position when blocked or paused

### Safety and Performance
- Efficient obstacle detection within sub-path
- Smooth progress calculation for complex geometries
- Boundary enforcement to prevent lane violations

### Tool Suggestions
- Use Edit tool to enhance lane following system
- Test with curved and complex sub-path geometries
- Verify obstacle avoidance and formation maintenance
- Check performance with many units in same lane

### Acceptance Criteria
- [ ] Units follow lane center line accurately
- [ ] Formation positioning is maintained during movement
- [ ] Obstacle avoidance prevents collisions
- [ ] Movement is smooth along curved paths
- [ ] Lane discipline keeps units within boundaries