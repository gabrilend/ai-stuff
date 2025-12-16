# Issue #026: Implement Unit-to-Unit Detection and Engagement

## Current Behavior
Units move along lanes but do not detect or engage enemy units, lacking the fundamental combat detection system.

## Intended Behavior
Units should automatically detect enemy units within their engagement range and transition to combat state when appropriate targets are found.

## Implementation Details

### Combat Detection System (src/systems/combat_detection_system.lua)
```lua
-- {{{ local function update_combat_detection
local function update_combat_detection(unit_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local team = EntityManager:get_component(unit_id, "team")
    
    if not position or not unit_data or not team then
        return
    end
    
    -- Skip detection if unit is dead or already in combat
    if unit_data.state == "dead" or unit_data.state == "combat" then
        return
    end
    
    -- Find enemy units within detection range
    local detection_range = get_unit_detection_range(unit_data)
    local enemy_units = find_enemy_units_in_range(unit_id, detection_range)
    
    if #enemy_units > 0 then
        -- Select best target
        local target = select_combat_target(unit_id, enemy_units)
        
        if target then
            initiate_combat_engagement(unit_id, target)
        end
    else
        -- Check if unit should exit combat state
        if unit_data.state == "combat" then
            check_combat_disengagement(unit_id)
        end
    end
end
-- }}}

-- {{{ local function get_unit_detection_range
local function get_unit_detection_range(unit_data)
    local base_range = 25  -- Base detection range
    
    if unit_data.unit_type == "ranged" then
        return base_range * 1.5  -- Ranged units detect further
    elseif unit_data.unit_type == "melee" then
        return base_range
    end
    
    return base_range
end
-- }}}

-- {{{ local function find_enemy_units_in_range
local function find_enemy_units_in_range(unit_id, detection_range)
    local position = EntityManager:get_component(unit_id, "position")
    local team = EntityManager:get_component(unit_id, "team")
    
    if not position or not team then
        return {}
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local enemy_units = {}
    
    -- Check units in current sub-path and adjacent sub-paths
    local relevant_sub_paths = get_detection_sub_paths(position.sub_path_id)
    
    for _, sub_path_id in ipairs(relevant_sub_paths) do
        local units_in_path = get_units_in_sub_path(sub_path_id)
        
        for _, other_unit_id in ipairs(units_in_path) do
            if other_unit_id ~= unit_id then
                local other_position = EntityManager:get_component(other_unit_id, "position")
                local other_team = EntityManager:get_component(other_unit_id, "team")
                local other_unit_data = EntityManager:get_component(other_unit_id, "unit")
                
                if other_position and other_team and other_unit_data then
                    -- Check if it's an enemy
                    if other_team.id ~= team.id and other_unit_data.state ~= "dead" then
                        local other_pos = Vector2:new(other_position.x, other_position.y)
                        local distance = unit_pos:distance_to(other_pos)
                        
                        if distance <= detection_range then
                            table.insert(enemy_units, {
                                unit_id = other_unit_id,
                                position = other_pos,
                                distance = distance,
                                unit_type = other_unit_data.unit_type
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(enemy_units, function(a, b) return a.distance < b.distance end)
    
    return enemy_units
end
-- }}}

-- {{{ local function select_combat_target
local function select_combat_target(unit_id, enemy_units)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data or #enemy_units == 0 then
        return nil
    end
    
    -- Target selection logic based on unit type and tactical priorities
    local best_target = nil
    local best_score = -1
    
    for _, enemy in ipairs(enemy_units) do
        local score = calculate_target_priority(unit_data, enemy)
        
        if score > best_score then
            best_score = score
            best_target = enemy
        end
    end
    
    return best_target
end
-- }}}

-- {{{ local function calculate_target_priority
local function calculate_target_priority(unit_data, enemy)
    local score = 0
    
    -- Distance factor (closer = higher priority)
    local distance_factor = math.max(0, 1 - (enemy.distance / 50))
    score = score + distance_factor * 50
    
    -- Type-based priorities
    if unit_data.unit_type == "melee" then
        -- Melee units prefer to engage other melee units first
        if enemy.unit_type == "melee" then
            score = score + 30
        elseif enemy.unit_type == "ranged" then
            score = score + 20  -- Still important to reach ranged units
        end
    elseif unit_data.unit_type == "ranged" then
        -- Ranged units prefer to target other ranged units or support
        if enemy.unit_type == "ranged" then
            score = score + 40
        elseif enemy.unit_type == "melee" then
            score = score + 10  -- Lower priority for melee
        end
    end
    
    -- Health-based targeting (prefer weakened enemies)
    local enemy_health = EntityManager:get_component(enemy.unit_id, "health")
    if enemy_health then
        local health_ratio = enemy_health.current / enemy_health.maximum
        score = score + (1 - health_ratio) * 15  -- Higher score for damaged enemies
    end
    
    -- Formation position factor (prefer front-line enemies)
    local formation_bonus = calculate_formation_priority_bonus(enemy.unit_id)
    score = score + formation_bonus
    
    return score
end
-- }}}

-- {{{ local function initiate_combat_engagement
local function initiate_combat_engagement(unit_id, target)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not unit_data or not moveable then
        return
    end
    
    -- Transition to combat state
    unit_data.state = "combat"
    unit_data.combat_target = target.unit_id
    unit_data.combat_engagement_time = love.timer.getTime()
    
    -- Stop current movement
    moveable.velocity_x = 0
    moveable.velocity_y = 0
    moveable.is_moving = false
    
    -- Calculate combat positioning
    local combat_position = calculate_combat_position(unit_id, target)
    if combat_position then
        moveable.target_x = combat_position.x
        moveable.target_y = combat_position.y
    end
    
    -- Notify combat system
    CombatSystem:register_combat_engagement(unit_id, target.unit_id)
    
    -- Create engagement effect
    create_engagement_effect(unit_id, target.unit_id)
    
    Debug:log("Unit " .. unit_id .. " engaging target " .. target.unit_id)
end
-- }}}

-- {{{ local function calculate_combat_position
local function calculate_combat_position(unit_id, target)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not unit_data then
        return nil
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local optimal_distance = get_optimal_combat_distance(unit_data.unit_type)
    
    -- Calculate direction to target
    local direction_to_target = target.position:subtract(unit_pos):normalize()
    
    -- Calculate ideal combat position
    local combat_position = target.position:subtract(
        direction_to_target:multiply(optimal_distance)
    )
    
    -- Ensure position is within sub-path boundaries
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if sub_path then
        local corrected_position = CollisionSystem:correct_unit_position(
            {position = combat_position}, sub_path
        )
        return corrected_position
    end
    
    return combat_position
end
-- }}}

-- {{{ local function get_optimal_combat_distance
local function get_optimal_combat_distance(unit_type)
    if unit_type == "melee" then
        return 12  -- Close combat distance
    elseif unit_type == "ranged" then
        return 35  -- Maintain shooting distance
    end
    
    return 20  -- Default distance
end
-- }}}

-- {{{ local function check_combat_disengagement
local function check_combat_disengagement(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data or not unit_data.combat_target then
        return
    end
    
    local should_disengage = false
    
    -- Check if target is still valid
    local target_health = EntityManager:get_component(unit_data.combat_target, "health")
    if not target_health or not target_health.is_alive then
        should_disengage = true
    end
    
    -- Check if target is out of range
    if not should_disengage then
        local detection_range = get_unit_detection_range(unit_data)
        local enemy_units = find_enemy_units_in_range(unit_id, detection_range)
        
        local target_still_in_range = false
        for _, enemy in ipairs(enemy_units) do
            if enemy.unit_id == unit_data.combat_target then
                target_still_in_range = true
                break
            end
        end
        
        if not target_still_in_range then
            should_disengage = true
        end
    end
    
    if should_disengage then
        disengage_from_combat(unit_id)
    end
end
-- }}}

-- {{{ local function disengage_from_combat
local function disengage_from_combat(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    -- Clear combat state
    local old_target = unit_data.combat_target
    unit_data.state = "moving"
    unit_data.combat_target = nil
    unit_data.combat_engagement_time = nil
    
    -- Notify combat system
    CombatSystem:unregister_combat_engagement(unit_id, old_target)
    
    -- Resume movement behavior
    local moveable = EntityManager:get_component(unit_id, "moveable")
    if moveable then
        moveable.is_moving = true
    end
    
    Debug:log("Unit " .. unit_id .. " disengaged from combat")
end
-- }}}

-- {{{ local function get_detection_sub_paths
local function get_detection_sub_paths(current_sub_path_id)
    local sub_paths = {current_sub_path_id}
    
    -- Add adjacent sub-paths in same lane
    local lane = LaneSystem:get_lane_containing_sub_path(current_sub_path_id)
    if lane then
        for _, sub_path in ipairs(lane.sub_paths) do
            if sub_path.id ~= current_sub_path_id then
                table.insert(sub_paths, sub_path.id)
            end
        end
    end
    
    -- Add sub-paths from intersecting lanes
    local intersecting_lanes = LaneSystem:get_intersecting_lanes(current_sub_path_id)
    for _, intersecting_lane in ipairs(intersecting_lanes) do
        for _, sub_path in ipairs(intersecting_lane.sub_paths) do
            table.insert(sub_paths, sub_path.id)
        end
    end
    
    return sub_paths
end
-- }}}

-- {{{ local function create_engagement_effect
local function create_engagement_effect(unit_id, target_id)
    local unit_pos = EntityManager:get_component(unit_id, "position")
    local target_pos = EntityManager:get_component(target_id, "position")
    
    if unit_pos and target_pos then
        local effect = {
            type = "engagement",
            start_position = Vector2:new(unit_pos.x, unit_pos.y),
            end_position = Vector2:new(target_pos.x, target_pos.y),
            duration = 0.3,
            start_time = love.timer.getTime()
        }
        
        EffectSystem:add_effect(effect)
    end
end
-- }}}
```

### Detection Features
1. **Range-Based Detection**: Different detection ranges for unit types
2. **Multi-Lane Awareness**: Check adjacent and intersecting lanes
3. **Target Prioritization**: Smart target selection based on tactical factors
4. **State Management**: Smooth transitions between movement and combat
5. **Disengagement Logic**: Automatic exit from combat when appropriate

### Target Selection Criteria
- Distance to target (closer = higher priority)
- Unit type matchups (tactical advantages)
- Enemy health status (prefer weakened targets)
- Formation positioning (prioritize front-line units)

### Integration Points
- Works with movement system for positioning
- Interfaces with lane system for multi-lane detection
- Coordinates with combat system for engagement tracking
- Uses collision system for position validation

### Tool Suggestions
- Use Write tool to create combat detection system
- Test with mixed unit types and formations
- Verify target selection logic and priorities
- Check performance with many units in combat

### Acceptance Criteria
- [ ] Units detect enemies within appropriate ranges
- [ ] Target selection follows tactical priorities
- [ ] Combat engagement transitions work smoothly
- [ ] Disengagement occurs when targets are lost
- [ ] System performs well with multiple simultaneous combats