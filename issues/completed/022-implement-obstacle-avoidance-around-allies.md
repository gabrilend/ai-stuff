# Issue #022: Implement Obstacle Avoidance Around Allies

## Current Behavior
Units may collide with or stack on top of allied units during movement and positioning.

## Intended Behavior
Units should intelligently navigate around allied units while maintaining formation and lane discipline, using smooth avoidance behaviors.

## Implementation Details

### Obstacle Avoidance System (src/systems/obstacle_avoidance_system.lua)
```lua
-- {{{ local function update_obstacle_avoidance
local function update_obstacle_avoidance(unit_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or unit_data.state ~= "moving" then
        return
    end
    
    -- Find nearby units that could be obstacles
    local nearby_units = find_nearby_allied_units(unit_id, 40)  -- 40 unit detection radius
    
    if #nearby_units == 0 then
        return  -- No obstacles to avoid
    end
    
    -- Calculate avoidance force
    local avoidance_force = calculate_avoidance_force(unit_id, nearby_units)
    
    -- Apply avoidance to movement
    if avoidance_force:length() > 0.1 then
        apply_avoidance_force(unit_id, avoidance_force, dt)
    end
end
-- }}}

-- {{{ local function find_nearby_allied_units
local function find_nearby_allied_units(unit_id, detection_radius)
    local position = EntityManager:get_component(unit_id, "position")
    local team = EntityManager:get_component(unit_id, "team")
    
    if not position or not team then
        return {}
    end
    
    local current_pos = Vector2:new(position.x, position.y)
    local nearby_units = {}
    
    -- Get all units in the same sub-path and adjacent sub-paths
    local sub_path_ids = get_relevant_sub_paths(position.sub_path_id)
    
    for _, sub_path_id in ipairs(sub_path_ids) do
        local units_in_path = get_units_in_sub_path(sub_path_id)
        
        for _, other_unit_id in ipairs(units_in_path) do
            if other_unit_id ~= unit_id then
                local other_position = EntityManager:get_component(other_unit_id, "position")
                local other_team = EntityManager:get_component(other_unit_id, "team")
                
                if other_position and other_team and other_team.id == team.id then
                    local other_pos = Vector2:new(other_position.x, other_position.y)
                    local distance = current_pos:distance_to(other_pos)
                    
                    if distance <= detection_radius then
                        table.insert(nearby_units, {
                            unit_id = other_unit_id,
                            position = other_pos,
                            distance = distance
                        })
                    end
                end
            end
        end
    end
    
    return nearby_units
end
-- }}}

-- {{{ local function calculate_avoidance_force
local function calculate_avoidance_force(unit_id, nearby_units)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    local current_pos = Vector2:new(position.x, position.y)
    local total_force = Vector2:new(0, 0)
    
    local avoidance_strength = 100  -- How strong the avoidance force is
    local personal_space = unit_data.size * 2  -- Minimum comfortable distance
    
    for _, nearby_unit in ipairs(nearby_units) do
        local to_obstacle = current_pos:subtract(nearby_unit.position)
        local distance = to_obstacle:length()
        
        if distance < personal_space and distance > 0 then
            -- Calculate repulsive force (stronger when closer)
            local force_magnitude = avoidance_strength * (personal_space - distance) / personal_space
            local force_direction = to_obstacle:normalize()
            local repulsive_force = force_direction:multiply(force_magnitude)
            
            -- Weight by relative movement (avoid units moving toward us more strongly)
            local weight = calculate_collision_risk_weight(unit_id, nearby_unit.unit_id)
            repulsive_force = repulsive_force:multiply(weight)
            
            total_force = total_force:add(repulsive_force)
        end
    end
    
    -- Limit maximum avoidance force
    local max_force = 200
    if total_force:length() > max_force then
        total_force = total_force:normalize():multiply(max_force)
    end
    
    return total_force
end
-- }}}

-- {{{ local function calculate_collision_risk_weight
local function calculate_collision_risk_weight(unit_id, other_unit_id)
    local moveable1 = EntityManager:get_component(unit_id, "moveable")
    local moveable2 = EntityManager:get_component(other_unit_id, "moveable")
    local position1 = EntityManager:get_component(unit_id, "position")
    local position2 = EntityManager:get_component(other_unit_id, "position")
    
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

-- {{{ local function apply_avoidance_force
local function apply_avoidance_force(unit_id, avoidance_force, dt)
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not moveable or not position then
        return
    end
    
    -- Get sub-path constraints
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if not sub_path then
        return
    end
    
    -- Apply avoidance force while respecting lane boundaries
    local constrained_force = constrain_force_to_lane(avoidance_force, position, sub_path)
    
    -- Blend with current velocity (don't completely override intended movement)
    local blend_factor = 0.3  -- How much to blend avoidance vs intended movement
    
    local current_velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
    local avoidance_velocity = constrained_force:multiply(dt)
    
    local blended_velocity = current_velocity:multiply(1 - blend_factor):add(
        avoidance_velocity:multiply(blend_factor)
    )
    
    -- Update movement
    moveable.velocity_x = blended_velocity.x
    moveable.velocity_y = blended_velocity.y
    
    -- Update position
    position.previous_x = position.x
    position.previous_y = position.y
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    -- Ensure unit stays within sub-path boundaries
    local corrected_pos = CollisionSystem:correct_unit_position({position = Vector2:new(position.x, position.y)}, sub_path)
    position.x = corrected_pos.x
    position.y = corrected_pos.y
end
-- }}}

-- {{{ local function constrain_force_to_lane
local function constrain_force_to_lane(force, position, sub_path)
    -- Project force to stay within lane boundaries
    local current_pos = Vector2:new(position.x, position.y)
    local test_position = current_pos:add(force:multiply(0.1))  -- Small test step
    
    -- Check if force would take unit out of bounds
    if not CollisionSystem:check_unit_in_bounds({position = test_position}, sub_path) then
        -- Project force parallel to lane boundaries
        local path_direction = get_path_direction_at_position(position, sub_path)
        local parallel_component = force:dot(path_direction)
        
        -- Keep only the component parallel to the path
        return path_direction:multiply(parallel_component)
    end
    
    return force
end
-- }}}

-- {{{ local function get_relevant_sub_paths
local function get_relevant_sub_paths(current_sub_path_id)
    local relevant_paths = {current_sub_path_id}
    
    -- Add adjacent sub-paths in the same lane
    local lane = LaneSystem:get_lane_containing_sub_path(current_sub_path_id)
    if lane then
        for _, sub_path in ipairs(lane.sub_paths) do
            if sub_path.id ~= current_sub_path_id then
                table.insert(relevant_paths, sub_path.id)
            end
        end
    end
    
    return relevant_paths
end
-- }}}

-- {{{ local function create_flow_field_around_obstacle
local function create_flow_field_around_obstacle(obstacle_position, avoidance_radius)
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
```

### Avoidance Features
1. **Repulsive Forces**: Push units away from too-close allies
2. **Collision Risk Assessment**: Weight avoidance based on approach speed
3. **Lane Constraint**: Keep avoidance within sub-path boundaries
4. **Smooth Blending**: Integrate avoidance with intended movement
5. **Personal Space**: Maintain comfortable distance between units

### Behavioral Considerations
- Preserve formation structure while avoiding collisions
- Respect lane boundaries during avoidance maneuvers
- Balance avoidance strength with movement efficiency
- Handle clustered units gracefully

### Performance Optimization
- Spatial partitioning for efficient nearby unit detection
- Limit avoidance calculations to relevant units
- Use approximations for distant units

### Tool Suggestions
- Use Edit tool to enhance obstacle avoidance system
- Test with dense unit formations
- Verify lane boundary respect during avoidance
- Check performance with many units in close proximity

### Acceptance Criteria
- [ ] Units avoid colliding with allied units
- [ ] Avoidance behavior respects lane boundaries
- [ ] Formation integrity is maintained during avoidance
- [ ] System performs well with dense unit clusters
- [ ] Movement remains smooth and natural