# Issue #023: Create Formation Preservation Logic

## Current Behavior
Units move individually without coordinating to maintain tactical formations during movement and positioning.

## Intended Behavior
Units should work together to preserve formation structure while moving, adapting to obstacles and maintaining relative positioning as intended by the player's deployment strategy.

## Implementation Details

### Formation System Enhancement (src/systems/formation_system.lua)
```lua
-- {{{ local function update_formation_preservation
local function update_formation_preservation(formation_id, dt)
    local formation = get_formation(formation_id)
    if not formation or #formation.units == 0 then
        return
    end
    
    -- Calculate formation center and update target positions
    local formation_center = calculate_formation_center(formation)
    local formation_direction = calculate_formation_direction(formation)
    
    -- Update each unit's target position within formation
    for _, unit_data in ipairs(formation.units) do
        local target_pos = calculate_formation_position(
            formation_center, formation_direction, unit_data.relative_position
        )
        
        update_unit_formation_target(unit_data.unit_id, target_pos, formation)
    end
    
    -- Handle formation cohesion
    maintain_formation_cohesion(formation, dt)
end
-- }}}

-- {{{ local function calculate_formation_center
local function calculate_formation_center(formation)
    local total_x, total_y = 0, 0
    local valid_units = 0
    
    for _, unit_data in ipairs(formation.units) do
        local position = EntityManager:get_component(unit_data.unit_id, "position")
        if position then
            total_x = total_x + position.x
            total_y = total_y + position.y
            valid_units = valid_units + 1
        end
    end
    
    if valid_units == 0 then
        return Vector2:new(0, 0)
    end
    
    return Vector2:new(total_x / valid_units, total_y / valid_units)
end
-- }}}

-- {{{ local function calculate_formation_direction
local function calculate_formation_direction(formation)
    -- Use average movement direction of formation units
    local total_velocity = Vector2:new(0, 0)
    local moving_units = 0
    
    for _, unit_data in ipairs(formation.units) do
        local moveable = EntityManager:get_component(unit_data.unit_id, "moveable")
        if moveable and moveable.is_moving then
            local velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
            if velocity:length() > 0.1 then
                total_velocity = total_velocity:add(velocity)
                moving_units = moving_units + 1
            end
        end
    end
    
    if moving_units == 0 then
        -- Fallback to formation's intended direction
        return formation.intended_direction or Vector2:new(1, 0)
    end
    
    return total_velocity:normalize()
end
-- }}}

-- {{{ local function calculate_formation_position
local function calculate_formation_position(center, direction, relative_position)
    -- Calculate perpendicular direction for lateral positioning
    local perpendicular = Vector2:new(-direction.y, direction.x)
    
    -- Apply relative positioning
    local forward_offset = direction:multiply(relative_position.forward)
    local lateral_offset = perpendicular:multiply(relative_position.lateral)
    
    return center:add(forward_offset):add(lateral_offset)
end
-- }}}

-- {{{ local function maintain_formation_cohesion
local function maintain_formation_cohesion(formation, dt)
    local max_cohesion_distance = formation.max_spread or 50
    local cohesion_strength = 2.0
    
    for _, unit_data in ipairs(formation.units) do
        local position = EntityManager:get_component(unit_data.unit_id, "position")
        local moveable = EntityManager:get_component(unit_data.unit_id, "moveable")
        
        if position and moveable then
            local unit_pos = Vector2:new(position.x, position.y)
            local formation_center = calculate_formation_center(formation)
            
            local distance_from_center = unit_pos:distance_to(formation_center)
            
            if distance_from_center > max_cohesion_distance then
                -- Apply cohesion force to pull unit back toward formation
                local cohesion_direction = formation_center:subtract(unit_pos):normalize()
                local cohesion_force = cohesion_direction:multiply(cohesion_strength)
                
                -- Blend with current movement
                local current_velocity = Vector2:new(moveable.velocity_x, moveable.velocity_y)
                local blended_velocity = current_velocity:add(cohesion_force:multiply(dt))
                
                moveable.velocity_x = blended_velocity.x
                moveable.velocity_y = blended_velocity.y
            end
        end
    end
end
-- }}}

-- {{{ local function create_formation_from_units
local function create_formation_from_units(unit_ids, formation_type)
    local formation = {
        id = generate_formation_id(),
        type = formation_type,
        units = {},
        max_spread = 60,
        intended_direction = Vector2:new(1, 0),
        creation_time = love.timer.getTime()
    }
    
    -- Calculate relative positions based on formation type
    local relative_positions = calculate_formation_layout(formation_type, #unit_ids)
    
    for i, unit_id in ipairs(unit_ids) do
        table.insert(formation.units, {
            unit_id = unit_id,
            relative_position = relative_positions[i],
            formation_role = get_unit_formation_role(unit_id, formation_type)
        })
        
        -- Mark unit as part of formation
        local unit_data = EntityManager:get_component(unit_id, "unit")
        if unit_data then
            unit_data.formation_id = formation.id
        end
    end
    
    register_formation(formation)
    return formation
end
-- }}}

-- {{{ local function calculate_formation_layout
local function calculate_formation_layout(formation_type, unit_count)
    local positions = {}
    
    if formation_type == "line" then
        -- Units arranged in a horizontal line
        local spacing = 15
        local start_offset = -(unit_count - 1) * spacing / 2
        
        for i = 1, unit_count do
            table.insert(positions, {
                forward = 0,
                lateral = start_offset + (i - 1) * spacing
            })
        end
        
    elseif formation_type == "column" then
        -- Units arranged in a vertical column
        local spacing = 18
        
        for i = 1, unit_count do
            table.insert(positions, {
                forward = -(i - 1) * spacing,
                lateral = 0
            })
        end
        
    elseif formation_type == "wedge" then
        -- V-shaped formation
        local spacing = 15
        
        for i = 1, unit_count do
            local row = math.floor((i - 1) / 2)
            local side = (i - 1) % 2 == 0 and -1 or 1
            
            table.insert(positions, {
                forward = -row * spacing,
                lateral = side * row * spacing / 2
            })
        end
        
    elseif formation_type == "box" then
        -- Rectangular formation
        local cols = math.ceil(math.sqrt(unit_count))
        local rows = math.ceil(unit_count / cols)
        local spacing = 15
        
        for i = 1, unit_count do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            
            table.insert(positions, {
                forward = -row * spacing,
                lateral = (col - (cols - 1) / 2) * spacing
            })
        end
        
    else
        -- Default: loose cluster
        for i = 1, unit_count do
            table.insert(positions, {
                forward = 0,
                lateral = 0
            })
        end
    end
    
    return positions
end
-- }}}

-- {{{ local function get_unit_formation_role
local function get_unit_formation_role(unit_id, formation_type)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return "standard"
    end
    
    -- Assign roles based on unit type and formation
    if formation_type == "wedge" then
        if unit_data.unit_type == "melee" then
            return "front_line"
        else
            return "support"
        end
    elseif formation_type == "line" then
        return "front_line"
    elseif formation_type == "column" then
        return "file"
    else
        return "standard"
    end
end
-- }}}

-- {{{ local function adapt_formation_to_terrain
local function adapt_formation_to_terrain(formation, sub_path)
    if not sub_path or not sub_path.boundaries then
        return
    end
    
    -- Check if formation fits within sub-path width
    local formation_width = calculate_formation_width(formation)
    local path_width = sub_path.width
    
    if formation_width > path_width * 0.8 then  -- 80% of path width
        -- Compress formation laterally
        compress_formation_laterally(formation, path_width * 0.8)
    end
    
    -- Handle path curves
    local path_curvature = calculate_path_curvature(sub_path)
    if path_curvature > 0.1 then  -- Significant curve
        adjust_formation_for_curve(formation, path_curvature)
    end
end
-- }}}

-- {{{ local function compress_formation_laterally
local function compress_formation_laterally(formation, max_width)
    local current_width = calculate_formation_width(formation)
    local compression_ratio = max_width / current_width
    
    for _, unit_data in ipairs(formation.units) do
        unit_data.relative_position.lateral = unit_data.relative_position.lateral * compression_ratio
    end
end
-- }}}

-- {{{ local function dissolve_formation
local function dissolve_formation(formation_id, reason)
    local formation = get_formation(formation_id)
    if not formation then
        return
    end
    
    -- Remove formation assignment from units
    for _, unit_data in ipairs(formation.units) do
        local unit_component = EntityManager:get_component(unit_data.unit_id, "unit")
        if unit_component then
            unit_component.formation_id = nil
        end
    end
    
    -- Log formation dissolution
    Debug:log("Formation " .. formation_id .. " dissolved: " .. reason)
    
    -- Remove from registry
    unregister_formation(formation_id)
end
-- }}}
```

### Formation Features
1. **Dynamic Layout**: Multiple formation types (line, column, wedge, box)
2. **Cohesion Maintenance**: Keep units together during movement
3. **Terrain Adaptation**: Adjust formation to sub-path constraints
4. **Role Assignment**: Different roles based on unit type and formation
5. **Preservation Logic**: Maintain structure through obstacles

### Formation Types
- **Line**: Horizontal spread for maximum front coverage
- **Column**: Vertical arrangement for narrow passages
- **Wedge**: V-shape for breakthrough tactics
- **Box**: Rectangular for balanced coverage

### Adaptive Behaviors
- Compress when sub-path is narrow
- Adjust spacing for path curvature
- Maintain relative positioning during combat
- Reform after obstacle navigation

### Tool Suggestions
- Use Edit tool to enhance formation system
- Test different formation types in various sub-path widths
- Verify formation preservation during movement
- Check cohesion maintenance with obstacles

### Acceptance Criteria
- [ ] Units maintain formation structure during movement
- [ ] Formations adapt to sub-path width constraints
- [ ] Different formation types work correctly
- [ ] Cohesion is preserved through obstacles
- [ ] Formation dissolution handles edge cases gracefully