# Issue #029: Implement Combat Positioning (Melee vs Ranged)

## Current Behavior
All units use the same basic combat positioning without considering the tactical differences between melee and ranged unit types.

## Intended Behavior
Melee and ranged units should use different combat positioning strategies, with melee units closing distance and ranged units maintaining optimal firing range while avoiding close combat.

## Implementation Details

### Combat Positioning System (src/systems/combat_positioning_system.lua)
```lua
-- {{{ local function update_combat_positioning
local function update_combat_positioning(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position or unit_data.state ~= "combat" then
        return
    end
    
    local target_id = unit_data.combat_target
    if not target_id then
        return
    end
    
    -- Apply positioning strategy based on unit type
    if unit_data.unit_type == "melee" then
        update_melee_positioning(unit_id, target_id, dt)
    elseif unit_data.unit_type == "ranged" then
        update_ranged_positioning(unit_id, target_id, dt)
    end
    
    -- Apply micro-positioning adjustments
    apply_micro_positioning(unit_id, target_id, dt)
end
-- }}}

-- {{{ local function update_melee_positioning
local function update_melee_positioning(unit_id, target_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local target_position = EntityManager:get_component(target_id, "position")
    local target_unit_data = EntityManager:get_component(target_id, "unit")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local distance_to_target = unit_pos:distance_to(target_pos)
    
    -- Define optimal positioning based on target type
    local optimal_distance
    local approach_speed
    
    if target_unit_data and target_unit_data.unit_type == "ranged" then
        -- Aggressive approach against ranged units
        optimal_distance = 8   -- Very close to prevent ranged attacks
        approach_speed = 35    -- Fast approach
    else
        -- Standard melee engagement
        optimal_distance = 12  -- Standard melee range
        approach_speed = 25    -- Normal approach speed
    end
    
    if distance_to_target > optimal_distance + 3 then
        -- Close distance aggressively
        local direction = target_pos:subtract(unit_pos):normalize()
        
        -- Check for obstacles in path
        local clear_path = check_path_to_target(unit_id, target_id)
        
        if clear_path then
            -- Direct approach
            moveable.velocity_x = direction.x * approach_speed
            moveable.velocity_y = direction.y * approach_speed
        else
            -- Find flanking route
            local flanking_direction = calculate_flanking_approach(unit_id, target_id)
            moveable.velocity_x = flanking_direction.x * approach_speed
            moveable.velocity_y = flanking_direction.y * approach_speed
        end
        
        moveable.is_moving = true
        
    elseif distance_to_target < optimal_distance - 1 then
        -- Back away slightly if too close
        local direction = unit_pos:subtract(target_pos):normalize()
        moveable.velocity_x = direction.x * 15
        moveable.velocity_y = direction.y * 15
        moveable.is_moving = true
        
    else
        -- In optimal range, adjust for tactical advantage
        adjust_melee_tactical_position(unit_id, target_id)
    end
    
    -- Update position
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    -- Ensure position stays within bounds
    enforce_positioning_bounds(unit_id)
end
-- }}}

-- {{{ local function update_ranged_positioning
local function update_ranged_positioning(unit_id, target_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local target_position = EntityManager:get_component(target_id, "position")
    local target_unit_data = EntityManager:get_component(target_id, "unit")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local distance_to_target = unit_pos:distance_to(target_pos)
    
    -- Define positioning parameters
    local optimal_distance = 30   -- Preferred firing range
    local minimum_distance = 18   -- Never get closer than this
    local maximum_distance = 45   -- Don't let target get too far
    
    -- Adjust behavior based on target type
    if target_unit_data and target_unit_data.unit_type == "melee" then
        -- Kiting behavior against melee units
        if distance_to_target < minimum_distance + 5 then
            -- Retreat immediately
            retreat_from_target(unit_id, target_id, 25)  -- Fast retreat
        elseif distance_to_target > maximum_distance then
            -- Close distance but carefully
            approach_target_cautiously(unit_id, target_id, 15)
        else
            -- Maintain distance with lateral movement
            maintain_ranged_distance(unit_id, target_id)
        end
    else
        -- Positioning against other ranged units
        if distance_to_target < optimal_distance - 5 then
            retreat_from_target(unit_id, target_id, 15)  -- Moderate retreat
        elseif distance_to_target > optimal_distance + 5 then
            approach_target_cautiously(unit_id, target_id, 20)
        else
            // Strafe for better positioning
            strafe_for_advantage(unit_id, target_id)
        end
    end
    
    -- Update position
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    // Ensure position stays within bounds
    enforce_positioning_bounds(unit_id)
end
-- }}}

-- {{{ local function retreat_from_target
local function retreat_from_target(unit_id, target_id, retreat_speed)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Calculate retreat direction
    local retreat_direction = unit_pos:subtract(target_pos):normalize()
    
    // Check for obstacles behind unit
    local retreat_path_clear = check_retreat_path(unit_id, retreat_direction)
    
    if not retreat_path_clear then
        // Find alternative retreat direction
        retreat_direction = find_alternative_retreat_direction(unit_id, target_id)
    end
    
    moveable.velocity_x = retreat_direction.x * retreat_speed
    moveable.velocity_y = retreat_direction.y * retreat_speed
    moveable.is_moving = true
    
    // Mark as retreating for other systems
    local unit_data = EntityManager:get_component(unit_id, "unit")
    if unit_data then
        unit_data.combat_state = "retreating"
    end
end
-- }}}

-- {{{ local function approach_target_cautiously
local function approach_target_cautiously(unit_id, target_id, approach_speed)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    // Calculate approach direction
    local approach_direction = target_pos:subtract(unit_pos):normalize()
    
    // Check if target is moving toward us (danger!)
    local target_moveable = EntityManager:get_component(target_id, "moveable")
    if target_moveable then
        local target_velocity = Vector2:new(target_moveable.velocity_x, target_moveable.velocity_y)
        local target_to_unit = unit_pos:subtract(target_pos):normalize()
        
        // If target is moving toward us, be more cautious
        local approach_factor = target_velocity:dot(target_to_unit)
        if approach_factor > 0.5 then  // Target approaching
            approach_speed = approach_speed * 0.5  // Slower approach
        end
    end
    
    moveable.velocity_x = approach_direction.x * approach_speed
    moveable.velocity_y = approach_direction.y * approach_speed
    moveable.is_moving = true
    
    // Mark as cautiously advancing
    local unit_data = EntityManager:get_component(unit_id, "unit")
    if unit_data then
        unit_data.combat_state = "advancing"
    end
end
-- }}}

-- {{{ local function maintain_ranged_distance
local function maintain_ranged_distance(unit_id, target_id)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not position or not moveable then
        return
    end
    
    // Use lateral movement to maintain distance while avoiding being static
    local lateral_movement_speed = 10
    local time = love.timer.getTime()
    
    // Create figure-8 or circular movement pattern
    local movement_pattern = math.sin(time * 2) * lateral_movement_speed
    local lateral_direction = calculate_lateral_direction(unit_id, target_id)
    
    moveable.velocity_x = lateral_direction.x * movement_pattern
    moveable.velocity_y = lateral_direction.y * movement_pattern
    moveable.is_moving = math.abs(movement_pattern) > 1
    
    // Mark as maintaining position
    local unit_data = EntityManager:get_component(unit_id, "unit")
    if unit_data then
        unit_data.combat_state = "maintaining"
    end
end
-- }}}

-- {{{ local function strafe_for_advantage
local function strafe_for_advantage(unit_id, target_id)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not position or not moveable then
        return
    end
    
    // Calculate strafe direction perpendicular to target line
    local lateral_direction = calculate_lateral_direction(unit_id, target_id)
    local strafe_speed = 18
    
    // Alternate strafe direction periodically
    local time = love.timer.getTime()
    local strafe_factor = math.sin(time * 1.5) > 0 and 1 or -1
    
    moveable.velocity_x = lateral_direction.x * strafe_speed * strafe_factor
    moveable.velocity_y = lateral_direction.y * strafe_speed * strafe_factor
    moveable.is_moving = true
    
    // Mark as strafing
    local unit_data = EntityManager:get_component(unit_id, "unit")
    if unit_data then
        unit_data.combat_state = "strafing"
    end
end
-- }}}

-- {{{ local function calculate_lateral_direction
local function calculate_lateral_direction(unit_id, target_id)
    local position = EntityManager:get_component(unit_id, "position")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not position or not target_position then
        return Vector2:new(1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    // Calculate direction to target
    local to_target = target_pos:subtract(unit_pos):normalize()
    
    // Calculate perpendicular direction
    local lateral = Vector2:new(-to_target.y, to_target.x)
    
    return lateral
end
-- }}}

-- {{{ local function check_path_to_target
local function check_path_to_target(unit_id, target_id)
    local position = EntityManager:get_component(unit_id, "position")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not position or not target_position then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    // Check for obstacles between unit and target
    local direction = target_pos:subtract(unit_pos)
    local distance = direction:length()
    direction = direction:normalize()
    
    local check_steps = math.ceil(distance / 5)  // Check every 5 units
    
    for i = 1, check_steps do
        local check_pos = unit_pos:add(direction:multiply(i * 5))
        
        // Check if position has obstacles
        if has_obstacle_at_position(check_pos, unit_id) then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ local function calculate_flanking_approach
local function calculate_flanking_approach(unit_id, target_id)
    local position = EntityManager:get_component(unit_id, "position")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not position or not target_position then
        return Vector2:new(1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    // Try flanking from left and right, choose best option
    local to_target = target_pos:subtract(unit_pos):normalize()
    local left_flank = Vector2:new(-to_target.y, to_target.x)
    local right_flank = Vector2:new(to_target.y, -to_target.x)
    
    // Test both flanking directions
    local left_clear = check_flanking_path(unit_id, left_flank)
    local right_clear = check_flanking_path(unit_id, right_flank)
    
    if left_clear and right_clear then
        // Choose based on some preference (e.g., formation position)
        return math.random() < 0.5 and left_flank or right_flank
    elseif left_clear then
        return left_flank
    elseif right_clear then
        return right_flank
    else
        // No flanking possible, direct approach
        return to_target
    end
end
-- }}}

-- {{{ local function adjust_melee_tactical_position
local function adjust_melee_tactical_position(unit_id, target_id)
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not moveable then
        return
    end
    
    // Make small adjustments for tactical advantage
    local adjustment_speed = 8
    
    // Try to get behind or to the side of target
    local tactical_direction = calculate_tactical_advantage_direction(unit_id, target_id)
    
    moveable.velocity_x = tactical_direction.x * adjustment_speed
    moveable.velocity_y = tactical_direction.y * adjustment_speed
    moveable.is_moving = tactical_direction:length() > 0.1
    
    // Mark as positioning
    local unit_data = EntityManager:get_component(unit_id, "unit")
    if unit_data then
        unit_data.combat_state = "positioning"
    end
end
-- }}}

-- {{{ local function enforce_positioning_bounds
local function enforce_positioning_bounds(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return
    end
    
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if sub_path then
        local corrected_pos = CollisionSystem:correct_unit_position(
            {position = Vector2:new(position.x, position.y)}, sub_path
        )
        position.x = corrected_pos.x
        position.y = corrected_pos.y
    end
end
-- }}}
```

### Combat Positioning Features
1. **Type-Specific Strategies**: Different positioning for melee vs ranged
2. **Dynamic Distance Management**: Optimal ranges based on unit matchups
3. **Tactical Movement**: Flanking, retreating, and strafing behaviors
4. **Obstacle Awareness**: Path checking and alternative route finding
5. **Micro-Positioning**: Fine adjustments for tactical advantage

### Melee Positioning Tactics
- Aggressive approach against ranged units
- Standard engagement distance for melee vs melee
- Flanking maneuvers when direct path is blocked
- Tactical positioning for advantage

### Ranged Positioning Tactics
- Kiting behavior against melee units
- Distance maintenance with lateral movement
- Cautious approach when target is far
- Strafing for positional advantage

### Tool Suggestions
- Use Write tool to create combat positioning system
- Test with different unit type matchups
- Verify positioning strategies and movement patterns
- Check tactical behavior and obstacle handling

### Acceptance Criteria
- [ ] Melee units close distance effectively against all target types
- [ ] Ranged units maintain optimal firing distance
- [ ] Kiting behavior works against approaching melee units
- [ ] Tactical positioning provides combat advantages
- [ ] Movement respects lane boundaries and obstacles