# Issue #017: Implement Basic Movement Along Sub-Paths

## Current Behavior
Units exist but lack proper movement along the generated sub-paths in lanes.

## Intended Behavior
Units should smoothly follow their assigned sub-path center lines with proper speed control and path progression tracking.

## Implementation Details

### Enhanced Movement System (src/systems/unit_movement_system.lua)
```lua
-- {{{ local function update_unit_movement
local function update_unit_movement(unit_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    -- Skip movement if unit is not in moving state
    if unit_data.state ~= "moving" then
        return
    end
    
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if not sub_path or #sub_path.center_line < 2 then
        return
    end
    
    -- Calculate next target point along path
    local next_target = calculate_next_path_target(position, sub_path, unit_data.speed * dt)
    
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
        else
            -- Reached target, stop movement
            moveable.velocity_x = 0
            moveable.velocity_y = 0
            moveable.is_moving = false
        end
    end
end
-- }}}

-- {{{ local function calculate_next_path_target
local function calculate_next_path_target(position, sub_path, max_distance)
    local current_pos = Vector2:new(position.x, position.y)
    local center_line = sub_path.center_line
    
    -- Find current position on path
    local closest_segment_index = find_closest_path_segment(current_pos, center_line)
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
    local projected = segment_start:add(segment_vector:multiply(t))
    
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

-- {{{ local function find_closest_path_segment
local function find_closest_path_segment(position, center_line)
    local min_distance = math.huge
    local closest_index = nil
    
    for i = 1, #center_line - 1 do
        local segment_start = center_line[i]
        local segment_end = center_line[i + 1]
        
        local distance = point_to_line_segment_distance(position, segment_start, segment_end)
        
        if distance < min_distance then
            min_distance = distance
            closest_index = i
        end
    end
    
    return closest_index
end
-- }}}
```

### Path Following Features
1. **Smooth Movement**: Units follow center line with interpolation
2. **Speed Control**: Configurable movement speed per unit
3. **Path Progress**: Tracking current position along path
4. **Target Calculation**: Look-ahead for smooth movement
5. **Boundary Respect**: Stay within sub-path boundaries

### Considerations
- Optimize for many units moving simultaneously
- Handle edge cases like empty paths or disconnected segments
- Consider future integration with obstacle avoidance
- Plan for dynamic path updates during gameplay

### Tool Suggestions
- Use Edit tool to enhance movement system
- Test with units spawned on different sub-paths
- Verify smooth movement and speed consistency
- Check performance with many moving units

### Acceptance Criteria
- [ ] Units follow their assigned sub-path center lines
- [ ] Movement speed is consistent and configurable
- [ ] Units handle path segments and curves smoothly
- [ ] Path following works for all valid sub-paths
- [ ] System performs well with multiple units