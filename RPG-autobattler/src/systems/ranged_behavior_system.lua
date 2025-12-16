-- Ranged Behavior System
-- Handles specialized behaviors for ranged units including distance management,
-- threat assessment, emergency retreat, and tactical positioning

local RangedBehaviorSystem = {}

-- Module requires
local Vector2 = require("src.utils.vector2")
local Colors = require("src.config.colors")
local Debug = require("src.utils.debug")

-- System state
local scheduled_removals = {}

-- {{{ local function update_ranged_behavior
local function update_ranged_behavior(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position or unit_data.unit_type ~= "ranged" then
        return
    end
    
    -- Update ranged unit behavior based on current state
    if unit_data.state == "combat" then
        update_ranged_combat_behavior(unit_id, dt)
    elseif unit_data.state == "moving" then
        update_ranged_movement_behavior(unit_id, dt)
    end
    
    -- Check for threats and opportunities
    assess_ranged_tactical_situation(unit_id)
    
    -- Update ranged unit specific animations and effects
    update_ranged_visual_state(unit_id)
end
-- }}}

-- {{{ local function update_ranged_combat_behavior
local function update_ranged_combat_behavior(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position then
        return
    end
    
    -- Initialize ranged combat data if needed
    if not unit_data.ranged_data then
        unit_data.ranged_data = {
            preferred_range = 30,
            minimum_safe_distance = 20,
            maximum_effective_range = 45,
            last_position_time = love.timer.getTime(),
            stationary_time = 0,
            retreat_cooldown = 0
        }
    end
    
    local ranged_data = unit_data.ranged_data
    local current_time = love.timer.getTime()
    
    -- Track how long unit has been stationary
    update_stationary_tracking(unit_id, ranged_data, current_time)
    
    -- Evaluate current combat situation
    local threat_assessment = assess_immediate_threats(unit_id)
    
    if threat_assessment.immediate_danger then
        execute_emergency_retreat(unit_id, threat_assessment)
    elseif threat_assessment.suboptimal_positioning then
        execute_tactical_repositioning(unit_id, threat_assessment)
    else
        maintain_firing_position(unit_id, ranged_data)
    end
    
    -- Update retreat cooldown
    if ranged_data.retreat_cooldown > 0 then
        ranged_data.retreat_cooldown = ranged_data.retreat_cooldown - dt
    end
end
-- }}}

-- {{{ local function update_ranged_movement_behavior
local function update_ranged_movement_behavior(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position then
        return
    end
    
    -- Check for enemies while moving
    local detection_range = get_unit_detection_range(unit_data)
    local enemy_units = find_enemy_units_in_range(unit_id, detection_range)
    
    if #enemy_units > 0 then
        -- Stop and assess situation
        local combat_target = select_combat_target(unit_id, enemy_units)
        if combat_target then
            initiate_combat_engagement(unit_id, combat_target)
        end
    end
end
-- }}}

-- {{{ local function update_stationary_tracking
local function update_stationary_tracking(unit_id, ranged_data, current_time)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not position or not moveable then
        return
    end
    
    -- Check if unit is moving
    if moveable.is_moving and (math.abs(moveable.velocity_x) > 1 or math.abs(moveable.velocity_y) > 1) then
        ranged_data.stationary_time = 0
        ranged_data.last_position_time = current_time
    else
        ranged_data.stationary_time = current_time - ranged_data.last_position_time
    end
end
-- }}}

-- {{{ local function assess_immediate_threats
local function assess_immediate_threats(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local team = EntityManager:get_component(unit_id, "team")
    
    if not position or not unit_data or not team then
        return {immediate_danger = false, suboptimal_positioning = false}
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local ranged_data = unit_data.ranged_data
    
    -- Find all nearby enemy units
    local nearby_enemies = find_enemy_units_in_range(unit_id, ranged_data.maximum_effective_range)
    
    local threat_assessment = {
        immediate_danger = false,
        suboptimal_positioning = false,
        closest_melee_distance = math.huge,
        closest_melee_unit = nil,
        enemies_in_optimal_range = 0,
        approaching_enemies = {}
    }
    
    for _, enemy in ipairs(nearby_enemies) do
        local enemy_unit_data = EntityManager:get_component(enemy.unit_id, "unit")
        
        if enemy_unit_data then
            if enemy_unit_data.unit_type == "melee" then
                -- Track closest melee threat
                if enemy.distance < threat_assessment.closest_melee_distance then
                    threat_assessment.closest_melee_distance = enemy.distance
                    threat_assessment.closest_melee_unit = enemy.unit_id
                end
                
                -- Check if melee unit is approaching
                if is_unit_approaching(unit_id, enemy.unit_id) then
                    table.insert(threat_assessment.approaching_enemies, enemy)
                end
                
                -- Immediate danger if melee unit is too close
                if enemy.distance < ranged_data.minimum_safe_distance then
                    threat_assessment.immediate_danger = true
                end
            end
            
            -- Count enemies in optimal firing range
            if enemy.distance >= ranged_data.minimum_safe_distance and 
               enemy.distance <= ranged_data.preferred_range then
                threat_assessment.enemies_in_optimal_range = threat_assessment.enemies_in_optimal_range + 1
            end
        end
    end
    
    -- Suboptimal positioning if no enemies in good range but enemies exist
    if threat_assessment.enemies_in_optimal_range == 0 and #nearby_enemies > 0 then
        threat_assessment.suboptimal_positioning = true
    end
    
    return threat_assessment
end
-- }}}

-- {{{ local function is_unit_approaching
local function is_unit_approaching(unit_id, other_unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local other_position = EntityManager:get_component(other_unit_id, "position")
    local other_moveable = EntityManager:get_component(other_unit_id, "moveable")
    
    if not position or not other_position or not other_moveable then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local other_pos = Vector2:new(other_position.x, other_position.y)
    local other_velocity = Vector2:new(other_moveable.velocity_x, other_moveable.velocity_y)
    
    -- Check if other unit is moving toward this unit
    local direction_to_unit = unit_pos:subtract(other_pos):normalize()
    local velocity_alignment = other_velocity:normalize():dot(direction_to_unit)
    
    return velocity_alignment > 0.5 and other_velocity:length() > 5
end
-- }}}

-- {{{ local function execute_emergency_retreat
local function execute_emergency_retreat(unit_id, threat_assessment)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local retreat_speed = 35  -- Fast retreat
    
    -- Calculate retreat direction away from closest threat
    local retreat_direction
    if threat_assessment.closest_melee_unit then
        local threat_pos = EntityManager:get_component(threat_assessment.closest_melee_unit, "position")
        if threat_pos then
            retreat_direction = unit_pos:subtract(Vector2:new(threat_pos.x, threat_pos.y)):normalize()
        end
    end
    
    if not retreat_direction then
        -- Fallback: retreat toward own team's spawn
        retreat_direction = calculate_retreat_toward_spawn(unit_id)
    end
    
    -- Check if retreat path is clear
    local clear_retreat_path = check_retreat_path_clear(unit_id, retreat_direction)
    
    if not clear_retreat_path then
        -- Find alternative retreat direction
        retreat_direction = find_alternative_retreat_direction(unit_id, threat_assessment)
    end
    
    -- Apply retreat movement
    moveable.velocity_x = retreat_direction.x * retreat_speed
    moveable.velocity_y = retreat_direction.y * retreat_speed
    moveable.is_moving = true
    
    -- Update unit state
    unit_data.combat_state = "emergency_retreat"
    unit_data.ranged_data.retreat_cooldown = 2.0  -- 2 second cooldown before re-engaging
    
    -- Create retreat effect
    create_retreat_effect(unit_id)
    
    Debug:log("Unit " .. unit_id .. " executing emergency retreat")
end
-- }}}

-- {{{ local function execute_tactical_repositioning
local function execute_tactical_repositioning(unit_id, threat_assessment)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    local ranged_data = unit_data.ranged_data
    local optimal_position = calculate_optimal_firing_position(unit_id, threat_assessment)
    
    if optimal_position then
        local unit_pos = Vector2:new(position.x, position.y)
        local direction_to_optimal = optimal_position:subtract(unit_pos):normalize()
        local repositioning_speed = 20
        
        moveable.velocity_x = direction_to_optimal.x * repositioning_speed
        moveable.velocity_y = direction_to_optimal.y * repositioning_speed
        moveable.is_moving = true
        
        unit_data.combat_state = "repositioning"
        
        Debug:log("Unit " .. unit_id .. " repositioning for better firing position")
    end
end
-- }}}

-- {{{ local function maintain_firing_position
local function maintain_firing_position(unit_id, ranged_data)
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not moveable or not unit_data then
        return
    end
    
    -- Stop movement to maintain accurate firing
    moveable.velocity_x = 0
    moveable.velocity_y = 0
    moveable.is_moving = false
    
    unit_data.combat_state = "firing"
    
    -- Small micro-adjustments for better positioning
    if ranged_data.stationary_time > 3.0 and math.random() < 0.1 then
        apply_micro_adjustment(unit_id)
    end
end
-- }}}

-- {{{ local function apply_micro_adjustment
local function apply_micro_adjustment(unit_id)
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not moveable then
        return
    end
    
    -- Small random adjustment to avoid being predictable
    local adjustment_strength = 5
    local random_direction = Vector2:new(
        (math.random() - 0.5) * 2,
        (math.random() - 0.5) * 2
    ):normalize()
    
    moveable.velocity_x = random_direction.x * adjustment_strength
    moveable.velocity_y = random_direction.y * adjustment_strength
    moveable.is_moving = true
    
    -- Schedule return to stationary after brief adjustment
    schedule_return_to_stationary(unit_id, 0.3)
end
-- }}}

-- {{{ local function calculate_optimal_firing_position
local function calculate_optimal_firing_position(unit_id, threat_assessment)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not unit_data or not unit_data.combat_target then
        return nil
    end
    
    local target_pos = EntityManager:get_component(unit_data.combat_target, "position")
    if not target_pos then
        return nil
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    local ranged_data = unit_data.ranged_data
    
    -- Calculate ideal position at preferred range from target
    local direction_to_target = target_position:subtract(unit_pos):normalize()
    local optimal_distance = ranged_data.preferred_range
    
    -- Account for threats - position further from melee threats
    if threat_assessment.closest_melee_unit then
        local threat_pos = EntityManager:get_component(threat_assessment.closest_melee_unit, "position")
        if threat_pos then
            local threat_position = Vector2:new(threat_pos.x, threat_pos.y)
            local direction_from_threat = unit_pos:subtract(threat_position):normalize()
            
            -- Bias optimal position away from threat
            direction_to_target = direction_to_target:add(direction_from_threat:multiply(0.5)):normalize()
            optimal_distance = optimal_distance * 1.2  -- Increase distance when threatened
        end
    end
    
    local optimal_position = target_position:subtract(direction_to_target:multiply(optimal_distance))
    
    -- Ensure position is within lane boundaries
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if sub_path then
        optimal_position = CollisionSystem:correct_unit_position(
            {position = optimal_position}, sub_path
        )
    end
    
    return optimal_position
end
-- }}}

-- {{{ local function check_retreat_path_clear
local function check_retreat_path_clear(unit_id, retreat_direction)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local check_distance = 20
    local check_position = unit_pos:add(retreat_direction:multiply(check_distance))
    
    -- Check if retreat position is within bounds
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if sub_path then
        return CollisionSystem:check_unit_in_bounds({position = check_position}, sub_path)
    end
    
    return true
end
-- }}}

-- {{{ local function calculate_retreat_toward_spawn
local function calculate_retreat_toward_spawn(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local team = EntityManager:get_component(unit_id, "team")
    
    if not position or not team then
        return Vector2:new(-1, 0)  -- Default fallback
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local spawn_position = TeamSystem:get_team_spawn_position(team.team_id)
    
    if spawn_position then
        return spawn_position:subtract(unit_pos):normalize()
    end
    
    -- Fallback based on team side
    if team.team_id == 1 then
        return Vector2:new(-1, 0)  -- Retreat left
    else
        return Vector2:new(1, 0)   -- Retreat right
    end
end
-- }}}

-- {{{ local function find_alternative_retreat_direction
local function find_alternative_retreat_direction(unit_id, threat_assessment)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return Vector2:new(-1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    -- Try perpendicular directions to main threat
    if threat_assessment.closest_melee_unit then
        local threat_pos = EntityManager:get_component(threat_assessment.closest_melee_unit, "position")
        if threat_pos then
            local threat_position = Vector2:new(threat_pos.x, threat_pos.y)
            local to_threat = threat_position:subtract(unit_pos):normalize()
            
            -- Try left and right perpendicular directions
            local left_perp = Vector2:new(-to_threat.y, to_threat.x)
            local right_perp = Vector2:new(to_threat.y, -to_threat.x)
            
            -- Check which direction is clearer
            if check_retreat_path_clear(unit_id, left_perp) then
                return left_perp
            elseif check_retreat_path_clear(unit_id, right_perp) then
                return right_perp
            end
        end
    end
    
    -- Fallback to spawn direction
    return calculate_retreat_toward_spawn(unit_id)
end
-- }}}

-- {{{ local function create_retreat_effect
local function create_retreat_effect(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local effect = {
            type = "retreat_indicator",
            position = Vector2:new(position.x, position.y),
            duration = 0.5,
            start_time = love.timer.getTime(),
            color = Colors.YELLOW
        }
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function assess_ranged_tactical_situation
local function assess_ranged_tactical_situation(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position then
        return
    end
    
    -- Check if current target is still valid
    if unit_data.combat_target then
        local target_health = EntityManager:get_component(unit_data.combat_target, "health")
        if not target_health or not target_health.is_alive then
            -- Target is dead, find new one
            unit_data.combat_target = nil
            unit_data.state = "moving"
            
            local detection_range = get_unit_detection_range(unit_data)
            local enemy_units = find_enemy_units_in_range(unit_id, detection_range)
            
            if #enemy_units > 0 then
                local new_target = select_combat_target(unit_id, enemy_units)
                if new_target then
                    initiate_combat_engagement(unit_id, new_target)
                end
            end
        end
    end
end
-- }}}

-- {{{ local function update_ranged_visual_state
local function update_ranged_visual_state(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local renderable = EntityManager:get_component(unit_id, "renderable")
    
    if not unit_data or not renderable or not unit_data.ranged_data then
        return
    end
    
    local ranged_data = unit_data.ranged_data
    local combat_state = unit_data.combat_state
    
    -- Visual indicators for different ranged states
    if combat_state == "firing" and ranged_data.stationary_time > 1.0 then
        -- Slight glow when in good firing position
        renderable.glow_intensity = 0.3
        renderable.glow_color = Colors.GREEN
    elseif combat_state == "emergency_retreat" then
        -- Red tint when retreating
        renderable.tint_color = Colors.RED
        renderable.tint_intensity = 0.4
    elseif combat_state == "repositioning" then
        -- Blue tint when repositioning
        renderable.tint_color = Colors.BLUE
        renderable.tint_intensity = 0.3
    else
        -- Clear any special effects
        renderable.glow_intensity = 0
        renderable.tint_intensity = 0
    end
end
-- }}}

-- {{{ local function schedule_return_to_stationary
local function schedule_return_to_stationary(unit_id, delay)
    local schedule_time = love.timer.getTime() + delay
    
    if not scheduled_removals[unit_id] then
        scheduled_removals[unit_id] = {}
    end
    
    table.insert(scheduled_removals[unit_id], {
        action = "return_to_stationary",
        schedule_time = schedule_time,
        callback = function()
            local moveable = EntityManager:get_component(unit_id, "moveable")
            local unit_data = EntityManager:get_component(unit_id, "unit")
            
            if moveable and unit_data and unit_data.combat_state == "firing" then
                moveable.velocity_x = 0
                moveable.velocity_y = 0
                moveable.is_moving = false
            end
        end
    })
end
-- }}}

-- {{{ local function process_scheduled_actions
local function process_scheduled_actions()
    local current_time = love.timer.getTime()
    
    for unit_id, actions in pairs(scheduled_removals) do
        local actions_to_remove = {}
        
        for i, action in ipairs(actions) do
            if current_time >= action.schedule_time then
                action.callback()
                table.insert(actions_to_remove, i)
            end
        end
        
        -- Remove processed actions
        for i = #actions_to_remove, 1, -1 do
            table.remove(actions, actions_to_remove[i])
        end
        
        -- Clean up empty action lists
        if #actions == 0 then
            scheduled_removals[unit_id] = nil
        end
    end
end
-- }}}

-- Public API
function RangedBehaviorSystem:update(dt)
    -- Get all ranged units
    local all_units = EntityManager:get_entities_with_component("unit")
    
    for _, unit_id in ipairs(all_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        if unit_data and unit_data.unit_type == "ranged" then
            update_ranged_behavior(unit_id, dt)
        end
    end
    
    -- Process scheduled actions
    process_scheduled_actions()
end

return RangedBehaviorSystem