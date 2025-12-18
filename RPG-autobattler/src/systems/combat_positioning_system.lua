-- {{{ CombatPositioningSystem
local CombatPositioningSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- {{{ CombatPositioningSystem:new
function CombatPositioningSystem:new(entity_manager, combat_detection_system)
    local system = {
        entity_manager = entity_manager,
        combat_detection_system = combat_detection_system,
        name = "combat_positioning",
        
        -- Melee positioning parameters
        melee_vs_ranged_distance = 8,     -- Very close to prevent ranged attacks
        melee_vs_melee_distance = 12,     -- Standard melee engagement
        melee_approach_speed = 35,        -- Fast approach vs ranged
        melee_standard_speed = 25,        -- Normal approach speed
        
        -- Ranged positioning parameters
        ranged_optimal_distance = 30,     -- Preferred firing range
        ranged_minimum_distance = 18,     -- Never get closer than this
        ranged_maximum_distance = 45,     -- Don't let target get too far
        retreat_speed_fast = 25,          -- Fast retreat from melee
        retreat_speed_moderate = 15,      -- Moderate retreat from ranged
        
        -- Tactical movement parameters
        lateral_movement_speed = 10,      -- Speed for maintaining distance
        strafe_speed = 18,                -- Speed for strafing
        tactical_adjustment_speed = 8,     -- Fine positioning adjustments
        
        -- Path checking parameters
        path_check_interval = 5,          -- Distance between path checks
        obstacle_detection_radius = 8,    -- Radius for obstacle detection
        
        -- Positioning state tracking
        unit_positioning_states = {},     -- Track positioning behavior for each unit
        last_positioning_update = {},     -- Track last update time per unit
        
        -- Update frequency
        update_frequency = 1/30,          -- Update 30 times per second for smooth positioning
        last_update = 0
    }
    setmetatable(system, {__index = CombatPositioningSystem})
    
    debug.log("CombatPositioningSystem created", "COMBAT_POSITIONING")
    return system
end
-- }}}

-- {{{ CombatPositioningSystem:update
function CombatPositioningSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Get all units in combat that need positioning
    local combat_units = self:get_combat_units()
    
    -- Update positioning for each combat unit
    for _, unit in ipairs(combat_units) do
        self:update_combat_positioning(unit, self.last_update)
    end
    
    -- Clean up positioning states for non-combat units
    self:cleanup_positioning_states()
    
    self.last_update = 0
end
-- }}}

-- {{{ CombatPositioningSystem:get_combat_units
function CombatPositioningSystem:get_combat_units()
    local combat_units = {}
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "moveable", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        if Unit.is_alive(self.entity_manager, unit) and
           self.combat_detection_system:is_unit_in_combat(unit) then
            table.insert(combat_units, unit)
        end
    end
    
    return combat_units
end
-- }}}

-- {{{ CombatPositioningSystem:update_combat_positioning
function CombatPositioningSystem:update_combat_positioning(unit, dt)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    local position = self.entity_manager:get_component(unit, "position")
    
    if not unit_data or not position then
        return
    end
    
    -- Get combat target from detection system
    local target = self.combat_detection_system:get_unit_target(unit)
    if not target or not Unit.is_alive(self.entity_manager, target) then
        self:clear_positioning_state(unit)
        return
    end
    
    -- Initialize positioning state if needed
    if not self.unit_positioning_states[unit.id] then
        self:initialize_positioning_state(unit)
    end
    
    -- Apply positioning strategy based on unit type
    if unit_data.unit_type == "melee" then
        self:update_melee_positioning(unit, target, dt)
    elseif unit_data.unit_type == "ranged" then
        self:update_ranged_positioning(unit, target, dt)
    end
    
    -- Apply micro-positioning adjustments
    self:apply_micro_positioning(unit, target, dt)
    
    -- Update positioning state timestamp
    self.last_positioning_update[unit.id] = love.timer.getTime()
end
-- }}}

-- {{{ CombatPositioningSystem:initialize_positioning_state
function CombatPositioningSystem:initialize_positioning_state(unit)
    self.unit_positioning_states[unit.id] = {
        current_behavior = "engaging",
        last_direction_change = 0,
        preferred_side = math.random() < 0.5 and "left" or "right",
        retreat_direction = nil,
        positioning_start_time = love.timer.getTime()
    }
end
-- }}}

-- {{{ CombatPositioningSystem:update_melee_positioning
function CombatPositioningSystem:update_melee_positioning(unit, target, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local target_position = self.entity_manager:get_component(target, "position")
    local target_unit_data = self.entity_manager:get_component(target, "unit_data")
    
    if not position or not moveable or not target_position or not target_unit_data then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local distance_to_target = unit_pos:distance_to(target_pos)
    
    -- Define optimal positioning based on target type
    local optimal_distance, approach_speed
    
    if target_unit_data.unit_type == "ranged" then
        -- Aggressive approach against ranged units
        optimal_distance = self.melee_vs_ranged_distance
        approach_speed = self.melee_approach_speed
        self.unit_positioning_states[unit.id].current_behavior = "aggressive_approach"
    else
        -- Standard melee engagement
        optimal_distance = self.melee_vs_melee_distance
        approach_speed = self.melee_standard_speed
        self.unit_positioning_states[unit.id].current_behavior = "standard_approach"
    end
    
    if distance_to_target > optimal_distance + 3 then
        -- Close distance
        local approach_direction = self:calculate_approach_direction(unit, target)
        
        moveable.velocity_x = approach_direction.x * approach_speed
        moveable.velocity_y = approach_direction.y * approach_speed
        moveable.moving = true
        
    elseif distance_to_target < optimal_distance - 1 then
        -- Back away slightly if too close
        local retreat_direction = unit_pos:subtract(target_pos):normalize()
        
        moveable.velocity_x = retreat_direction.x * 15
        moveable.velocity_y = retreat_direction.y * 15
        moveable.moving = true
        self.unit_positioning_states[unit.id].current_behavior = "adjusting_distance"
        
    else
        -- In optimal range, make tactical adjustments
        self:adjust_melee_tactical_position(unit, target)
    end
    
    -- Update position with boundary enforcement
    self:update_position_with_bounds(unit, moveable, dt)
end
-- }}}

-- {{{ CombatPositioningSystem:update_ranged_positioning
function CombatPositioningSystem:update_ranged_positioning(unit, target, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local target_position = self.entity_manager:get_component(target, "position")
    local target_unit_data = self.entity_manager:get_component(target, "unit_data")
    
    if not position or not moveable or not target_position or not target_unit_data then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local distance_to_target = unit_pos:distance_to(target_pos)
    
    -- Adjust behavior based on target type
    if target_unit_data.unit_type == "melee" then
        -- Kiting behavior against melee units
        if distance_to_target < self.ranged_minimum_distance + 5 then
            -- Retreat immediately
            self:retreat_from_target(unit, target, self.retreat_speed_fast)
            self.unit_positioning_states[unit.id].current_behavior = "retreating"
            
        elseif distance_to_target > self.ranged_maximum_distance then
            -- Close distance but carefully
            self:approach_target_cautiously(unit, target, 15)
            self.unit_positioning_states[unit.id].current_behavior = "cautious_approach"
            
        else
            -- Maintain distance with lateral movement
            self:maintain_ranged_distance(unit, target)
            self.unit_positioning_states[unit.id].current_behavior = "kiting"
        end
    else
        -- Positioning against other ranged units
        if distance_to_target < self.ranged_optimal_distance - 5 then
            self:retreat_from_target(unit, target, self.retreat_speed_moderate)
            self.unit_positioning_states[unit.id].current_behavior = "repositioning"
            
        elseif distance_to_target > self.ranged_optimal_distance + 5 then
            self:approach_target_cautiously(unit, target, 20)
            self.unit_positioning_states[unit.id].current_behavior = "closing_distance"
            
        else
            -- Strafe for better positioning
            self:strafe_for_advantage(unit, target)
            self.unit_positioning_states[unit.id].current_behavior = "strafing"
        end
    end
    
    -- Update position with boundary enforcement
    self:update_position_with_bounds(unit, moveable, dt)
end
-- }}}

-- {{{ CombatPositioningSystem:calculate_approach_direction
function CombatPositioningSystem:calculate_approach_direction(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return Vector2:new(1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Check for clear path to target
    if self:check_path_to_target(unit, target) then
        -- Direct approach
        return target_pos:subtract(unit_pos):normalize()
    else
        -- Find flanking route
        return self:calculate_flanking_approach(unit, target)
    end
end
-- }}}

-- {{{ CombatPositioningSystem:retreat_from_target
function CombatPositioningSystem:retreat_from_target(unit, target, retreat_speed)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Calculate retreat direction
    local retreat_direction = unit_pos:subtract(target_pos):normalize()
    
    -- Check for obstacles behind unit
    if not self:check_retreat_path(unit, retreat_direction) then
        -- Find alternative retreat direction
        retreat_direction = self:find_alternative_retreat_direction(unit, target)
    end
    
    moveable.velocity_x = retreat_direction.x * retreat_speed
    moveable.velocity_y = retreat_direction.y * retreat_speed
    moveable.moving = true
    
    -- Store retreat direction for consistency
    self.unit_positioning_states[unit.id].retreat_direction = retreat_direction
end
-- }}}

-- {{{ CombatPositioningSystem:approach_target_cautiously
function CombatPositioningSystem:approach_target_cautiously(unit, target, approach_speed)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Calculate approach direction
    local approach_direction = target_pos:subtract(unit_pos):normalize()
    
    -- Check if target is moving toward us (danger!)
    local target_moveable = self.entity_manager:get_component(target, "moveable")
    if target_moveable and target_moveable.moving then
        local target_velocity = Vector2:new(target_moveable.velocity_x, target_moveable.velocity_y)
        local target_to_unit = unit_pos:subtract(target_pos):normalize()
        
        -- If target is moving toward us, be more cautious
        local approach_factor = target_velocity:normalize():dot(target_to_unit)
        if approach_factor > 0.5 then  -- Target approaching
            approach_speed = approach_speed * 0.5  -- Slower approach
        end
    end
    
    moveable.velocity_x = approach_direction.x * approach_speed
    moveable.velocity_y = approach_direction.y * approach_speed
    moveable.moving = true
end
-- }}}

-- {{{ CombatPositioningSystem:maintain_ranged_distance
function CombatPositioningSystem:maintain_ranged_distance(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    if not position or not moveable then
        return
    end
    
    -- Use lateral movement to maintain distance while avoiding being static
    local time = love.timer.getTime()
    local positioning_state = self.unit_positioning_states[unit.id]
    
    -- Create dynamic movement pattern
    local movement_frequency = 1.5 + (unit.id % 100) / 100  -- Slight variation per unit
    local movement_pattern = math.sin(time * movement_frequency) * self.lateral_movement_speed
    local lateral_direction = self:calculate_lateral_direction(unit, target)
    
    -- Add preferred side bias
    local side_factor = positioning_state.preferred_side == "left" and 1 or -1
    
    moveable.velocity_x = lateral_direction.x * movement_pattern * side_factor
    moveable.velocity_y = lateral_direction.y * movement_pattern * side_factor
    moveable.moving = math.abs(movement_pattern) > 1
end
-- }}}

-- {{{ CombatPositioningSystem:strafe_for_advantage
function CombatPositioningSystem:strafe_for_advantage(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    if not position or not moveable then
        return
    end
    
    -- Calculate strafe direction perpendicular to target line
    local lateral_direction = self:calculate_lateral_direction(unit, target)
    local time = love.timer.getTime()
    local positioning_state = self.unit_positioning_states[unit.id]
    
    -- Alternate strafe direction periodically
    local direction_change_interval = 2.0 + math.random()  -- 2-3 seconds
    if time - positioning_state.last_direction_change > direction_change_interval then
        positioning_state.preferred_side = positioning_state.preferred_side == "left" and "right" or "left"
        positioning_state.last_direction_change = time
    end
    
    local strafe_factor = positioning_state.preferred_side == "left" and 1 or -1
    
    moveable.velocity_x = lateral_direction.x * self.strafe_speed * strafe_factor
    moveable.velocity_y = lateral_direction.y * self.strafe_speed * strafe_factor
    moveable.moving = true
end
-- }}}

-- {{{ CombatPositioningSystem:adjust_melee_tactical_position
function CombatPositioningSystem:adjust_melee_tactical_position(unit, target)
    local moveable = self.entity_manager:get_component(unit, "moveable")
    
    if not moveable then
        return
    end
    
    -- Make small adjustments for tactical advantage
    local tactical_direction = self:calculate_tactical_advantage_direction(unit, target)
    
    moveable.velocity_x = tactical_direction.x * self.tactical_adjustment_speed
    moveable.velocity_y = tactical_direction.y * self.tactical_adjustment_speed
    moveable.moving = tactical_direction:length() > 0.1
    
    self.unit_positioning_states[unit.id].current_behavior = "tactical_positioning"
end
-- }}}

-- {{{ CombatPositioningSystem:calculate_lateral_direction
function CombatPositioningSystem:calculate_lateral_direction(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return Vector2:new(1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Calculate direction to target
    local to_target = target_pos:subtract(unit_pos):normalize()
    
    -- Calculate perpendicular direction (lateral)
    local lateral = Vector2:new(-to_target.y, to_target.x)
    
    return lateral
end
-- }}}

-- {{{ CombatPositioningSystem:calculate_tactical_advantage_direction
function CombatPositioningSystem:calculate_tactical_advantage_direction(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return Vector2:new(0, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local to_target = target_pos:subtract(unit_pos):normalize()
    
    -- Try to position slightly to the side/behind for tactical advantage
    local positioning_state = self.unit_positioning_states[unit.id]
    local side_offset = positioning_state.preferred_side == "left" and -0.3 or 0.3
    
    local tactical_direction = Vector2:new(to_target.x + side_offset, to_target.y)
    return tactical_direction:normalize():multiply(0.5)  -- Small adjustment
end
-- }}}

-- {{{ CombatPositioningSystem:check_path_to_target
function CombatPositioningSystem:check_path_to_target(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Check for obstacles between unit and target
    local direction = target_pos:subtract(unit_pos)
    local distance = direction:length()
    direction = direction:normalize()
    
    local check_steps = math.ceil(distance / self.path_check_interval)
    
    for i = 1, check_steps do
        local check_pos = unit_pos:add(direction:multiply(i * self.path_check_interval))
        
        -- Check if position has obstacles (other units)
        if self:has_obstacle_at_position(check_pos, unit) then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ CombatPositioningSystem:check_retreat_path
function CombatPositioningSystem:check_retreat_path(unit, retreat_direction)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local check_distance = 20  -- Check 20 units behind
    local check_pos = unit_pos:add(retreat_direction:multiply(check_distance))
    
    return not self:has_obstacle_at_position(check_pos, unit)
end
-- }}}

-- {{{ CombatPositioningSystem:has_obstacle_at_position
function CombatPositioningSystem:has_obstacle_at_position(check_pos, unit)
    -- Check for other units at the position
    local units = self.entity_manager:get_entities_with_components({"position", "unit_data"})
    
    for _, other_unit in ipairs(units) do
        if other_unit.id ~= unit.id and Unit.is_alive(self.entity_manager, other_unit) then
            local other_position = self.entity_manager:get_component(other_unit, "position")
            if other_position then
                local other_pos = Vector2:new(other_position.x, other_position.y)
                local distance = check_pos:distance_to(other_pos)
                
                if distance < self.obstacle_detection_radius then
                    return true
                end
            end
        end
    end
    
    return false
end
-- }}}

-- {{{ CombatPositioningSystem:calculate_flanking_approach
function CombatPositioningSystem:calculate_flanking_approach(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return Vector2:new(1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Try flanking from preferred side
    local to_target = target_pos:subtract(unit_pos):normalize()
    local positioning_state = self.unit_positioning_states[unit.id]
    
    local flank_direction
    if positioning_state.preferred_side == "left" then
        flank_direction = Vector2:new(-to_target.y, to_target.x)
    else
        flank_direction = Vector2:new(to_target.y, -to_target.x)
    end
    
    -- Test flanking direction
    if self:check_flanking_path(unit, flank_direction) then
        return flank_direction
    else
        -- Try opposite side
        flank_direction = Vector2:new(-flank_direction.x, -flank_direction.y)
        if self:check_flanking_path(unit, flank_direction) then
            return flank_direction
        else
            -- No flanking possible, direct approach
            return to_target
        end
    end
end
-- }}}

-- {{{ CombatPositioningSystem:check_flanking_path
function CombatPositioningSystem:check_flanking_path(unit, flank_direction)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return false
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local check_distance = 15  -- Check flanking route
    local check_pos = unit_pos:add(flank_direction:multiply(check_distance))
    
    return not self:has_obstacle_at_position(check_pos, unit)
end
-- }}}

-- {{{ CombatPositioningSystem:find_alternative_retreat_direction
function CombatPositioningSystem:find_alternative_retreat_direction(unit, target)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return Vector2:new(1, 0)
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    -- Try perpendicular retreat directions
    local to_target = target_pos:subtract(unit_pos):normalize()
    local retreat_options = {
        Vector2:new(-to_target.y, to_target.x),   -- Left perpendicular
        Vector2:new(to_target.y, -to_target.x),   -- Right perpendicular
        unit_pos:subtract(target_pos):normalize() -- Direct retreat
    }
    
    for _, retreat_direction in ipairs(retreat_options) do
        if self:check_retreat_path(unit, retreat_direction) then
            return retreat_direction
        end
    end
    
    -- If all else fails, use direct retreat
    return unit_pos:subtract(target_pos):normalize()
end
-- }}}

-- {{{ CombatPositioningSystem:update_position_with_bounds
function CombatPositioningSystem:update_position_with_bounds(unit, moveable, dt)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return
    end
    
    -- Store previous position
    position.previous_x = position.x
    position.previous_y = position.y
    
    -- Update position
    position.x = position.x + moveable.velocity_x * dt
    position.y = position.y + moveable.velocity_y * dt
    
    -- Enforce positioning bounds (lane boundaries)
    self:enforce_positioning_bounds(unit)
end
-- }}}

-- {{{ CombatPositioningSystem:enforce_positioning_bounds
function CombatPositioningSystem:enforce_positioning_bounds(unit)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return
    end
    
    -- Simple bounds checking - would integrate with actual lane system
    local max_lateral_displacement = 30  -- Maximum distance from lane center
    
    if position.sub_path_id then
        -- Basic bounds enforcement
        if math.abs(position.x - (position.previous_x or position.x)) > max_lateral_displacement then
            position.x = position.previous_x or position.x
        end
        if math.abs(position.y - (position.previous_y or position.y)) > max_lateral_displacement then
            position.y = position.previous_y or position.y
        end
    end
end
-- }}}

-- {{{ CombatPositioningSystem:apply_micro_positioning
function CombatPositioningSystem:apply_micro_positioning(unit, target, dt)
    -- Fine adjustments based on current positioning behavior
    local positioning_state = self.unit_positioning_states[unit.id]
    
    if not positioning_state then
        return
    end
    
    -- Add small random variations to prevent predictable movement
    if math.random() < 0.1 then  -- 10% chance per update
        local moveable = self.entity_manager:get_component(unit, "moveable")
        if moveable and moveable.moving then
            local micro_adjustment = Vector2:new(
                (math.random() - 0.5) * 2,
                (math.random() - 0.5) * 2
            )
            
            moveable.velocity_x = moveable.velocity_x + micro_adjustment.x
            moveable.velocity_y = moveable.velocity_y + micro_adjustment.y
        end
    end
end
-- }}}

-- {{{ CombatPositioningSystem:clear_positioning_state
function CombatPositioningSystem:clear_positioning_state(unit)
    self.unit_positioning_states[unit.id] = nil
    self.last_positioning_update[unit.id] = nil
end
-- }}}

-- {{{ CombatPositioningSystem:cleanup_positioning_states
function CombatPositioningSystem:cleanup_positioning_states()
    local current_time = love.timer.getTime()
    local units_to_cleanup = {}
    
    for unit_id, last_update in pairs(self.last_positioning_update) do
        if current_time - last_update > 2.0 then  -- 2 seconds without update
            table.insert(units_to_cleanup, unit_id)
        end
    end
    
    for _, unit_id in ipairs(units_to_cleanup) do
        self.unit_positioning_states[unit_id] = nil
        self.last_positioning_update[unit_id] = nil
    end
end
-- }}}

-- {{{ CombatPositioningSystem:get_unit_positioning_state
function CombatPositioningSystem:get_unit_positioning_state(unit)
    return self.unit_positioning_states[unit.id]
end
-- }}}

-- {{{ CombatPositioningSystem:get_debug_info
function CombatPositioningSystem:get_debug_info()
    local active_positioning_units = 0
    local behavior_counts = {}
    
    for unit_id, state in pairs(self.unit_positioning_states) do
        active_positioning_units = active_positioning_units + 1
        
        local behavior = state.current_behavior or "unknown"
        behavior_counts[behavior] = (behavior_counts[behavior] or 0) + 1
    end
    
    return {
        active_positioning_units = active_positioning_units,
        behavior_distribution = behavior_counts,
        melee_parameters = {
            vs_ranged_distance = self.melee_vs_ranged_distance,
            vs_melee_distance = self.melee_vs_melee_distance,
            approach_speed = self.melee_approach_speed
        },
        ranged_parameters = {
            optimal_distance = self.ranged_optimal_distance,
            minimum_distance = self.ranged_minimum_distance,
            maximum_distance = self.ranged_maximum_distance
        }
    }
end
-- }}}

return CombatPositioningSystem
-- }}}