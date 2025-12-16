-- Backing-Up Behavior System
-- Handles intelligent retreat behavior for ranged units, allowing them to
-- back away from threats while maintaining fire capability (kiting)

local BackingUpBehaviorSystem = {}

-- Module requires
local Vector2 = require("src.utils.vector2")
local Colors = require("src.config.colors")
local Debug = require("src.utils.debug")

-- System state
local active_backing_units = {}

-- {{{ local function update_backing_up_behavior
local function update_backing_up_behavior(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position or unit_data.unit_type ~= "ranged" then
        return
    end
    
    -- Check if unit should engage backing-up behavior
    local threat_analysis = analyze_approaching_threats(unit_id)
    
    if threat_analysis.should_back_up then
        execute_backing_up_maneuver(unit_id, threat_analysis, dt)
    elseif unit_data.combat_state == "backing_up" then
        -- Check if backing up should continue or stop
        evaluate_backing_up_continuation(unit_id, dt)
    end
    
    -- Update backing-up state tracking
    update_backing_up_state(unit_id, dt)
end
-- }}}

-- {{{ local function analyze_approaching_threats
local function analyze_approaching_threats(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not unit_data then
        return {should_back_up = false}
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local threat_analysis = {
        should_back_up = false,
        primary_threat = nil,
        threat_distance = math.huge,
        threat_approach_speed = 0,
        threat_direction = Vector2:new(0, 0),
        time_to_contact = math.huge,
        backup_urgency = 0
    }
    
    -- Find all nearby enemy units
    local detection_range = 50
    local nearby_enemies = find_enemy_units_in_range(unit_id, detection_range)
    
    for _, enemy in ipairs(nearby_enemies) do
        local enemy_unit_data = EntityManager:get_component(enemy.unit_id, "unit")
        local enemy_moveable = EntityManager:get_component(enemy.unit_id, "moveable")
        
        if enemy_unit_data and enemy_moveable then
            local approach_analysis = analyze_enemy_approach(unit_id, enemy, enemy_unit_data, enemy_moveable)
            
            if approach_analysis.is_approaching and approach_analysis.urgency > threat_analysis.backup_urgency then
                threat_analysis.should_back_up = true
                threat_analysis.primary_threat = enemy.unit_id
                threat_analysis.threat_distance = enemy.distance
                threat_analysis.threat_approach_speed = approach_analysis.approach_speed
                threat_analysis.threat_direction = approach_analysis.approach_direction
                threat_analysis.time_to_contact = approach_analysis.time_to_contact
                threat_analysis.backup_urgency = approach_analysis.urgency
            end
        end
    end
    
    return threat_analysis
end
-- }}}

-- {{{ local function analyze_enemy_approach
local function analyze_enemy_approach(unit_id, enemy, enemy_unit_data, enemy_moveable)
    local position = EntityManager:get_component(unit_id, "position")
    local enemy_position = EntityManager:get_component(enemy.unit_id, "position")
    
    if not position or not enemy_position then
        return {is_approaching = false, urgency = 0}
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local enemy_pos = Vector2:new(enemy_position.x, enemy_position.y)
    local enemy_velocity = Vector2:new(enemy_moveable.velocity_x, enemy_moveable.velocity_y)
    
    -- Calculate if enemy is moving toward us
    local direction_to_unit = unit_pos:subtract(enemy_pos)
    local distance_to_unit = direction_to_unit:length()
    
    if distance_to_unit == 0 then
        return {is_approaching = false, urgency = 0}
    end
    
    direction_to_unit = direction_to_unit:normalize()
    
    -- Check velocity alignment with direction to unit
    local velocity_magnitude = enemy_velocity:length()
    
    if velocity_magnitude < 5 then  -- Enemy not moving significantly
        return {is_approaching = false, urgency = 0}
    end
    
    local velocity_direction = enemy_velocity:normalize()
    local approach_alignment = velocity_direction:dot(direction_to_unit)
    
    if approach_alignment < 0.3 then  -- Not approaching directly enough
        return {is_approaching = false, urgency = 0}
    end
    
    -- Calculate approach metrics
    local approach_speed = velocity_magnitude * approach_alignment
    local time_to_contact = distance_to_unit / approach_speed
    
    -- Calculate urgency based on multiple factors
    local urgency = 0
    
    -- Distance factor (closer = more urgent)
    urgency = urgency + (1 - (distance_to_unit / 50)) * 30
    
    -- Speed factor (faster approach = more urgent)
    urgency = urgency + (approach_speed / 30) * 25
    
    -- Unit type factor (melee threats are more urgent)
    if enemy_unit_data.unit_type == "melee" then
        urgency = urgency + 20
    end
    
    -- Time factor (imminent contact = very urgent)
    if time_to_contact < 3.0 then
        urgency = urgency + (3.0 - time_to_contact) * 15
    end
    
    return {
        is_approaching = true,
        urgency = urgency,
        approach_speed = approach_speed,
        approach_direction = direction_to_unit,
        time_to_contact = time_to_contact
    }
end
-- }}}

-- {{{ local function execute_backing_up_maneuver
local function execute_backing_up_maneuver(unit_id, threat_analysis, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not moveable or not unit_data then
        return
    end
    
    -- Initialize backing up data if needed
    if not unit_data.backing_up_data then
        unit_data.backing_up_data = {
            start_time = love.timer.getTime(),
            total_distance_backed = 0,
            last_fire_time = 0,
            direction_changes = 0,
            last_direction_change = 0
        }
    end
    
    local backing_data = unit_data.backing_up_data
    
    -- Calculate backing direction
    local backing_direction = calculate_backing_direction(unit_id, threat_analysis)
    
    -- Determine backing speed based on urgency
    local backing_speed = calculate_backing_speed(threat_analysis.backup_urgency)
    
    -- Apply movement while maintaining ability to fire
    apply_backing_movement(unit_id, backing_direction, backing_speed, dt)
    
    -- Attempt to maintain fire while backing up
    attempt_fire_while_backing(unit_id, backing_data)
    
    -- Update state
    unit_data.combat_state = "backing_up"
    backing_data.total_distance_backed = backing_data.total_distance_backed + backing_speed * dt
    
    Debug:log("Unit " .. unit_id .. " backing up from threat " .. (threat_analysis.primary_threat or "unknown"))
end
-- }}}

-- {{{ local function calculate_backing_direction
local function calculate_backing_direction(unit_id, threat_analysis)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return Vector2:new(-1, 0)  -- Default fallback
    end
    
    -- Primary direction: away from main threat
    local primary_direction = threat_analysis.threat_direction:multiply(-1)
    
    -- Check for obstacles in backing path
    local clear_backing_path = check_backing_path_clear(unit_id, primary_direction)
    
    if clear_backing_path then
        return primary_direction
    else
        -- Find alternative backing direction
        return find_alternative_backing_direction(unit_id, primary_direction, threat_analysis)
    end
end
-- }}}

-- {{{ local function find_alternative_backing_direction
local function find_alternative_backing_direction(unit_id, preferred_direction, threat_analysis)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return preferred_direction
    end
    
    -- Try angled retreat directions
    local angle_options = {-45, 45, -90, 90, -135, 135}  -- Degrees
    
    for _, angle_deg in ipairs(angle_options) do
        local angle_rad = math.rad(angle_deg)
        local cos_a = math.cos(angle_rad)
        local sin_a = math.sin(angle_rad)
        
        -- Rotate preferred direction by angle
        local test_direction = Vector2:new(
            preferred_direction.x * cos_a - preferred_direction.y * sin_a,
            preferred_direction.x * sin_a + preferred_direction.y * cos_a
        )
        
        if check_backing_path_clear(unit_id, test_direction) then
            return test_direction
        end
    end
    
    -- If no clear path found, use lateral movement
    local lateral_direction = Vector2:new(-threat_analysis.threat_direction.y, threat_analysis.threat_direction.x)
    return lateral_direction
end
-- }}}

-- {{{ local function check_backing_path_clear
local function check_backing_path_clear(unit_id, direction)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local check_distance = 25  -- Look ahead distance
    local check_position = unit_pos:add(direction:multiply(check_distance))
    
    -- Check lane boundaries
    local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
    if sub_path then
        if not CollisionSystem:check_unit_in_bounds({position = check_position}, sub_path) then
            return false
        end
    end
    
    -- Check for other units in the way
    local units_in_path = get_units_near_position(check_position, 15)
    return #units_in_path == 0
end
-- }}}

-- {{{ local function get_units_near_position
local function get_units_near_position(position, search_radius)
    local nearby_units = {}
    local all_units = EntityManager:get_entities_with_component("position")
    
    for _, unit_id in ipairs(all_units) do
        local unit_pos = EntityManager:get_component(unit_id, "position")
        if unit_pos then
            local unit_position = Vector2:new(unit_pos.x, unit_pos.y)
            local distance = position:distance_to(unit_position)
            
            if distance <= search_radius then
                table.insert(nearby_units, unit_id)
            end
        end
    end
    
    return nearby_units
end
-- }}}

-- {{{ local function calculate_backing_speed
local function calculate_backing_speed(urgency)
    local base_speed = 15
    local max_speed = 30
    
    -- Scale speed based on urgency (0-100)
    local urgency_factor = math.min(100, urgency) / 100
    local speed = base_speed + (max_speed - base_speed) * urgency_factor
    
    return speed
end
-- }}}

-- {{{ local function apply_backing_movement
local function apply_backing_movement(unit_id, direction, speed, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not position or not moveable then
        return
    end
    
    -- Apply movement
    moveable.velocity_x = direction.x * speed
    moveable.velocity_y = direction.y * speed
    moveable.is_moving = true
    
    -- Update position
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    -- Ensure unit stays within bounds
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

-- {{{ local function attempt_fire_while_backing
local function attempt_fire_while_backing(unit_id, backing_data)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local current_time = love.timer.getTime()
    
    if not unit_data or not unit_data.combat_target then
        return
    end
    
    -- Reduced fire rate while backing up
    local backing_fire_cooldown = 1.5  -- Slower than normal fire rate
    
    if current_time - backing_data.last_fire_time >= backing_fire_cooldown then
        -- Check if target is still in range and valid
        local target_in_range = check_target_in_firing_range(unit_id, unit_data.combat_target)
        
        if target_in_range then
            -- Fire at target while backing up
            execute_backing_fire(unit_id, unit_data.combat_target)
            backing_data.last_fire_time = current_time
        end
    end
end
-- }}}

-- {{{ local function check_target_in_firing_range
local function check_target_in_firing_range(unit_id, target_id)
    local position = EntityManager:get_component(unit_id, "position")
    local target_position = EntityManager:get_component(target_id, "position")
    local target_health = EntityManager:get_component(target_id, "health")
    
    if not position or not target_position or not target_health or not target_health.is_alive then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local distance = unit_pos:distance_to(target_pos)
    
    local max_range = 45  -- Maximum firing range
    return distance <= max_range
end
-- }}}

-- {{{ local function execute_backing_fire
local function execute_backing_fire(unit_id, target_id)
    -- Create projectile with reduced accuracy due to movement
    local accuracy_penalty = 0.8  -- 20% accuracy reduction while backing up
    
    -- Normal ranged attack but with penalty
    local projectile_id = ProjectileSystem:create_projectile(unit_id, target_id, "basic_arrow")
    
    if projectile_id then
        -- Apply accuracy penalty by slightly randomizing projectile direction
        apply_movement_accuracy_penalty(projectile_id, accuracy_penalty)
        
        -- Create backing fire effect
        create_backing_fire_effect(unit_id)
    end
    
    Debug:log("Unit " .. unit_id .. " fired while backing up at " .. target_id)
end
-- }}}

-- {{{ local function apply_movement_accuracy_penalty
local function apply_movement_accuracy_penalty(projectile_id, accuracy)
    local active_projectiles = ProjectileSystem:get_active_projectiles()
    if not active_projectiles then
        return
    end
    
    for _, projectile in ipairs(active_projectiles) do
        if projectile.id == projectile_id then
            -- Add random deviation to velocity
            local deviation_angle = (math.random() - 0.5) * 2 * math.pi * (1 - accuracy) * 0.1
            local cos_dev = math.cos(deviation_angle)
            local sin_dev = math.sin(deviation_angle)
            
            local original_vel = projectile.velocity
            projectile.velocity = Vector2:new(
                original_vel.x * cos_dev - original_vel.y * sin_dev,
                original_vel.x * sin_dev + original_vel.y * cos_dev
            )
            break
        end
    end
end
-- }}}

-- {{{ local function evaluate_backing_up_continuation
local function evaluate_backing_up_continuation(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data or not unit_data.backing_up_data then
        return
    end
    
    -- Re-analyze threats to see if backing up should continue
    local threat_analysis = analyze_approaching_threats(unit_id)
    
    if not threat_analysis.should_back_up then
        -- No more immediate threats, stop backing up
        stop_backing_up_behavior(unit_id)
    elseif unit_data.backing_up_data.total_distance_backed > 40 then
        -- Backed up far enough, try to re-engage
        attempt_re_engagement(unit_id)
    end
end
-- }}}

-- {{{ local function stop_backing_up_behavior
local function stop_backing_up_behavior(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    
    if not unit_data then
        return
    end
    
    -- Clear backing up state
    unit_data.combat_state = "firing"
    unit_data.backing_up_data = nil
    
    -- Stop movement
    if moveable then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
    
    Debug:log("Unit " .. unit_id .. " stopped backing up")
end
-- }}}

-- {{{ local function attempt_re_engagement
local function attempt_re_engagement(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    -- Look for new targets or re-engage current target
    if unit_data.combat_target then
        local target_still_valid = check_target_in_firing_range(unit_id, unit_data.combat_target)
        
        if target_still_valid then
            stop_backing_up_behavior(unit_id)
        else
            -- Look for new target
            local detection_range = 35
            local enemy_units = find_enemy_units_in_range(unit_id, detection_range)
            
            if #enemy_units > 0 then
                local new_target = select_combat_target(unit_id, enemy_units)
                if new_target then
                    unit_data.combat_target = new_target
                    stop_backing_up_behavior(unit_id)
                end
            end
        end
    end
end
-- }}}

-- {{{ local function update_backing_up_state
local function update_backing_up_state(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    -- Track units that are backing up
    if unit_data.combat_state == "backing_up" then
        active_backing_units[unit_id] = true
    else
        active_backing_units[unit_id] = nil
    end
    
    -- Update visual state for backing up units
    if unit_data.combat_state == "backing_up" then
        update_backing_visual_state(unit_id)
    end
end
-- }}}

-- {{{ local function update_backing_visual_state
local function update_backing_visual_state(unit_id)
    local renderable = EntityManager:get_component(unit_id, "renderable")
    
    if renderable then
        -- Add visual indicator for backing up
        renderable.tint_color = Colors.CYAN
        renderable.tint_intensity = 0.3
        
        -- Slight scale variation to show movement stress
        local time = love.timer.getTime()
        renderable.scale = 1 + 0.1 * math.sin(time * 8)
    end
end
-- }}}

-- {{{ local function create_backing_fire_effect
local function create_backing_fire_effect(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local effect = {
            type = "backing_fire",
            position = Vector2:new(position.x, position.y),
            duration = 0.3,
            start_time = love.timer.getTime(),
            color = Colors.ORANGE
        }
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- Public API
function BackingUpBehaviorSystem:update(dt)
    -- Get all ranged units
    local all_units = EntityManager:get_entities_with_component("unit")
    
    for _, unit_id in ipairs(all_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        if unit_data and unit_data.unit_type == "ranged" then
            update_backing_up_behavior(unit_id, dt)
        end
    end
end

function BackingUpBehaviorSystem:is_unit_backing_up(unit_id)
    return active_backing_units[unit_id] or false
end

function BackingUpBehaviorSystem:force_stop_backing_up(unit_id)
    stop_backing_up_behavior(unit_id)
end

function BackingUpBehaviorSystem:get_backing_units()
    local backing_units = {}
    for unit_id, _ in pairs(active_backing_units) do
        table.insert(backing_units, unit_id)
    end
    return backing_units
end

return BackingUpBehaviorSystem