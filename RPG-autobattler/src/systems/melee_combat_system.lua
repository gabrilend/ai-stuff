-- {{{ MeleeCombatSystem
local MeleeCombatSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- {{{ MeleeCombatSystem:new
function MeleeCombatSystem:new(entity_manager, combat_detection_system)
    local system = {
        entity_manager = entity_manager,
        combat_detection_system = combat_detection_system,
        name = "melee_combat",
        
        -- Combat parameters
        base_attack_damage = 15,      -- Base damage for melee attacks
        attack_cooldown = 1.0,        -- Seconds between attacks
        damage_variance = 0.2,        -- ±20% damage variation
        optimal_range = 12,           -- Optimal melee engagement distance
        max_attack_range = 15,        -- Maximum range for melee attacks
        positioning_speed = 20,       -- Movement speed during combat positioning
        
        -- Combat effects
        attack_effect_duration = 0.2,
        damage_number_duration = 1.5,
        death_effect_duration = 1.0,
        unit_removal_delay = 3.0,
        
        -- Combat state tracking
        active_combats = {},          -- Track active melee combats
        combat_timers = {},           -- Track attack cooldowns
        fatigue_factors = {},         -- Track combat fatigue
        
        -- Update frequency
        update_frequency = 1/30,      -- Update 30 times per second for smooth combat
        last_update = 0
    }
    setmetatable(system, {__index = MeleeCombatSystem})
    
    debug.log("MeleeCombatSystem created", "MELEE_COMBAT")
    return system
end
-- }}}

-- {{{ MeleeCombatSystem:update
function MeleeCombatSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Get all units in combat state
    local units_in_combat = self:get_melee_combat_units()
    
    -- Process each melee combat unit
    for _, unit in ipairs(units_in_combat) do
        self:update_melee_combat(unit, self.last_update)
    end
    
    -- Clean up finished combats
    self:cleanup_finished_combats()
    
    self.last_update = 0
end
-- }}}

-- {{{ MeleeCombatSystem:get_melee_combat_units
function MeleeCombatSystem:get_melee_combat_units()
    local combat_units = {}
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "health", "unit_data", "team"
    })
    
    for _, unit in ipairs(units) do
        if Unit.is_alive(self.entity_manager, unit) then
            local unit_data = self.entity_manager:get_component(unit, "unit_data")
            
            if unit_data and unit_data.unit_type == "melee" and
               self.combat_detection_system:is_unit_in_combat(unit) then
                table.insert(combat_units, unit)
            end
        end
    end
    
    return combat_units
end
-- }}}

-- {{{ MeleeCombatSystem:update_melee_combat
function MeleeCombatSystem:update_melee_combat(unit, dt)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    local position = self.entity_manager:get_component(unit, "position")
    
    if not unit_data or not position then
        return
    end
    
    -- Get combat target from detection system
    local target = self.combat_detection_system:get_unit_target(unit)
    if not target or not Unit.is_alive(self.entity_manager, target) then
        self:disengage_from_combat(unit)
        return
    end
    
    -- Initialize combat data if needed
    if not self.combat_timers[unit.id] then
        self:initialize_combat_data(unit)
    end
    
    -- Update combat positioning
    self:update_melee_positioning(unit, target, dt)
    
    -- Process melee attacks
    self:process_melee_attacks(unit, target, dt)
    
    -- Update combat state
    self:update_combat_state(unit, dt)
end
-- }}}

-- {{{ MeleeCombatSystem:initialize_combat_data
function MeleeCombatSystem:initialize_combat_data(unit)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not unit_data then
        return
    end
    
    self.combat_timers[unit.id] = {
        last_attack_time = 0,
        attack_cooldown = self.attack_cooldown,
        combat_start_time = love.timer.getTime()
    }
    
    self.fatigue_factors[unit.id] = 1.0
    
    -- Initialize unit combat data
    if not unit_data.combat_data then
        unit_data.combat_data = {
            base_damage = self.base_attack_damage,
            attack_range = self.max_attack_range,
            total_damage_dealt = 0,
            attacks_made = 0
        }
    end
end
-- }}}

-- {{{ MeleeCombatSystem:update_melee_positioning
function MeleeCombatSystem:update_melee_positioning(unit, target, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local moveable = self.entity_manager:get_component(unit, "moveable")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    local distance_to_target = unit_pos:distance_to(target_pos)
    
    if distance_to_target > self.optimal_range + 2 then
        -- Move closer to target
        local direction = target_pos:subtract(unit_pos):normalize()
        
        moveable.velocity_x = direction.x * self.positioning_speed
        moveable.velocity_y = direction.y * self.positioning_speed
        moveable.moving = true
        
        -- Update position with collision checking
        self:update_position_with_collision_check(unit, moveable, dt)
        
    elseif distance_to_target < self.optimal_range - 2 then
        -- Move away to maintain optimal distance
        local direction = unit_pos:subtract(target_pos):normalize()
        
        moveable.velocity_x = direction.x * (self.positioning_speed * 0.5)
        moveable.velocity_y = direction.y * (self.positioning_speed * 0.5)
        moveable.moving = true
        
        self:update_position_with_collision_check(unit, moveable, dt)
        
    else
        -- In optimal range, stop moving
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.moving = false
    end
end
-- }}}

-- {{{ MeleeCombatSystem:update_position_with_collision_check
function MeleeCombatSystem:update_position_with_collision_check(unit, moveable, dt)
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
    
    -- Simple boundary checking (this would integrate with collision system)
    -- For now, just ensure units don't move too far from their sub-path
    local max_displacement = 25
    if position.sub_path_id then
        -- This would be more sophisticated with actual lane system integration
        -- For now, just basic bounds checking
        if math.abs(position.x - (position.previous_x or position.x)) > max_displacement then
            position.x = position.previous_x
        end
        if math.abs(position.y - (position.previous_y or position.y)) > max_displacement then
            position.y = position.previous_y
        end
    end
end
-- }}}

-- {{{ MeleeCombatSystem:process_melee_attacks
function MeleeCombatSystem:process_melee_attacks(unit, target, dt)
    local position = self.entity_manager:get_component(unit, "position")
    local target_position = self.entity_manager:get_component(target, "position")
    
    if not position or not target_position then
        return
    end
    
    local combat_timer = self.combat_timers[unit.id]
    if not combat_timer then
        return
    end
    
    local current_time = love.timer.getTime()
    
    -- Check if unit can attack
    if current_time - combat_timer.last_attack_time >= combat_timer.attack_cooldown then
        local unit_pos = Vector2:new(position.x, position.y)
        local target_pos = Vector2:new(target_position.x, target_position.y)
        local distance = unit_pos:distance_to(target_pos)
        
        if distance <= self.max_attack_range then
            self:perform_melee_attack(unit, target)
            combat_timer.last_attack_time = current_time
        end
    end
end
-- }}}

-- {{{ MeleeCombatSystem:perform_melee_attack
function MeleeCombatSystem:perform_melee_attack(attacker, target)
    local target_health = self.entity_manager:get_component(target, "health")
    local unit_data = self.entity_manager:get_component(attacker, "unit_data")
    
    if not target_health or not target_health.is_alive or not unit_data then
        return
    end
    
    -- Calculate damage with variance and fatigue
    local base_damage = unit_data.combat_data.base_damage
    local fatigue_factor = self.fatigue_factors[attacker.id] or 1.0
    local random_factor = 1 + (math.random() - 0.5) * 2 * self.damage_variance
    local final_damage = math.floor(base_damage * random_factor * fatigue_factor)
    
    -- Apply damage
    local damage_dealt = self:apply_damage_to_unit(target, final_damage, attacker)
    
    -- Update attacker stats
    unit_data.combat_data.total_damage_dealt = unit_data.combat_data.total_damage_dealt + damage_dealt
    unit_data.combat_data.attacks_made = unit_data.combat_data.attacks_made + 1
    
    -- Create combat effects
    self:create_melee_attack_effect(attacker, target, damage_dealt)
    self:create_damage_number_effect(target, damage_dealt)
    
    debug.log("Unit " .. attacker.name .. " attacks " .. target.name .. " for " .. damage_dealt .. " damage", "MELEE_COMBAT")
    
    -- Check if target was killed
    if not target_health.is_alive then
        self:handle_target_death(attacker, target)
    end
end
-- }}}

-- {{{ MeleeCombatSystem:apply_damage_to_unit
function MeleeCombatSystem:apply_damage_to_unit(target, damage, attacker)
    local health = self.entity_manager:get_component(target, "health")
    
    if not health or not health.is_alive then
        return 0
    end
    
    -- Calculate actual damage dealt
    local damage_dealt = math.min(damage, health.current_hp)
    
    -- Apply damage
    health.current_hp = health.current_hp - damage_dealt
    health.last_damage_time = love.timer.getTime()
    health.last_attacker_id = attacker.id
    
    -- Check if unit dies
    if health.current_hp <= 0 then
        health.current_hp = 0
        health.is_alive = false
        self:handle_unit_death(target, attacker)
    end
    
    return damage_dealt
end
-- }}}

-- {{{ MeleeCombatSystem:handle_unit_death
function MeleeCombatSystem:handle_unit_death(dead_unit, killer)
    local unit_data = self.entity_manager:get_component(dead_unit, "unit_data")
    local position = self.entity_manager:get_component(dead_unit, "position")
    
    if unit_data then
        unit_data.combat_state = "dead"
        unit_data.death_time = love.timer.getTime()
    end
    
    -- Update visual appearance
    local renderable = self.entity_manager:get_component(dead_unit, "renderable")
    if renderable then
        renderable.color = {0.4, 0.4, 0.4}  -- Dark gray
        renderable.alpha = 0.5
    end
    
    -- Stop movement
    local moveable = self.entity_manager:get_component(dead_unit, "moveable")
    if moveable then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.moving = false
    end
    
    -- Clear combat data
    if self.combat_timers[dead_unit.id] then
        self.combat_timers[dead_unit.id] = nil
    end
    if self.fatigue_factors[dead_unit.id] then
        self.fatigue_factors[dead_unit.id] = nil
    end
    
    -- Force disengage from combat detection
    self.combat_detection_system:force_disengage(dead_unit)
    
    -- Create death effect
    self:create_death_effect(dead_unit, position)
    
    -- Schedule removal
    self:schedule_unit_removal(dead_unit, self.unit_removal_delay)
    
    debug.log("Unit " .. dead_unit.name .. " was killed by " .. (killer and killer.name or "unknown"), "MELEE_COMBAT")
end
-- }}}

-- {{{ MeleeCombatSystem:handle_target_death
function MeleeCombatSystem:handle_target_death(attacker, dead_target)
    -- The combat detection system will handle finding new targets
    -- We just need to clean up our combat tracking
    if self.combat_timers[attacker.id] then
        -- Reset attack timer for immediate re-engagement if new target found
        self.combat_timers[attacker.id].last_attack_time = love.timer.getTime() - self.attack_cooldown
    end
    
    debug.log("Unit " .. attacker.name .. " completed kill, looking for new targets", "MELEE_COMBAT")
end
-- }}}

-- {{{ MeleeCombatSystem:disengage_from_combat
function MeleeCombatSystem:disengage_from_combat(unit)
    -- Clean up combat data
    if self.combat_timers[unit.id] then
        self.combat_timers[unit.id] = nil
    end
    if self.fatigue_factors[unit.id] then
        self.fatigue_factors[unit.id] = nil
    end
    
    -- Resume normal movement
    local moveable = self.entity_manager:get_component(unit, "moveable")
    if moveable then
        moveable.moving = true
    end
    
    debug.log("Unit " .. unit.name .. " disengaged from melee combat", "MELEE_COMBAT")
end
-- }}}

-- {{{ MeleeCombatSystem:update_combat_state
function MeleeCombatSystem:update_combat_state(unit, dt)
    local combat_timer = self.combat_timers[unit.id]
    if not combat_timer then
        return
    end
    
    local current_time = love.timer.getTime()
    local combat_duration = current_time - combat_timer.combat_start_time
    
    -- Apply fatigue after prolonged combat
    if combat_duration > 10.0 then  -- 10 seconds of combat
        local fatigue_reduction = math.max(0.7, 1.0 - (combat_duration - 10.0) * 0.02)
        self.fatigue_factors[unit.id] = fatigue_reduction
    end
end
-- }}}

-- {{{ MeleeCombatSystem:cleanup_finished_combats
function MeleeCombatSystem:cleanup_finished_combats()
    local units_to_cleanup = {}
    
    for unit_id, _ in pairs(self.combat_timers) do
        local unit = self.entity_manager:get_entity_by_id(unit_id)
        
        if not unit or not Unit.is_alive(self.entity_manager, unit) or
           not self.combat_detection_system:is_unit_in_combat(unit) then
            table.insert(units_to_cleanup, unit_id)
        end
    end
    
    for _, unit_id in ipairs(units_to_cleanup) do
        self.combat_timers[unit_id] = nil
        self.fatigue_factors[unit_id] = nil
    end
end
-- }}}

-- {{{ MeleeCombatSystem:create_melee_attack_effect
function MeleeCombatSystem:create_melee_attack_effect(attacker, target, damage)
    local attacker_pos = self.entity_manager:get_component(attacker, "position")
    local target_pos = self.entity_manager:get_component(target, "position")
    
    if attacker_pos and target_pos then
        local effect = {
            type = "melee_attack",
            attacker_position = Vector2:new(attacker_pos.x, attacker_pos.y),
            target_position = Vector2:new(target_pos.x, target_pos.y),
            damage = damage,
            duration = self.attack_effect_duration,
            start_time = love.timer.getTime(),
            color = {1.0, 0.9, 0.2, 0.8}  -- Yellow slash effect
        }
        
        debug.log("Created melee attack effect: " .. damage .. " damage", "MELEE_COMBAT")
    end
end
-- }}}

-- {{{ MeleeCombatSystem:create_damage_number_effect
function MeleeCombatSystem:create_damage_number_effect(target, damage)
    local position = self.entity_manager:get_component(target, "position")
    
    if position then
        local effect = {
            type = "damage_number",
            position = Vector2:new(position.x, position.y - 10),  -- Slightly above unit
            damage = damage,
            duration = self.damage_number_duration,
            start_time = love.timer.getTime(),
            velocity = Vector2:new((math.random() - 0.5) * 10, -25),  -- Float upward with slight random
            color = {1.0, 0.3, 0.3, 1.0}  -- Red damage numbers
        }
        
        debug.log("Created damage number: " .. damage, "MELEE_COMBAT")
    end
end
-- }}}

-- {{{ MeleeCombatSystem:create_death_effect
function MeleeCombatSystem:create_death_effect(unit, position)
    if position then
        local effect = {
            type = "unit_death",
            position = Vector2:new(position.x, position.y),
            duration = self.death_effect_duration,
            start_time = love.timer.getTime(),
            expansion_rate = 15,  -- How fast the effect expands
            color = {0.8, 0.8, 0.8, 0.6}  -- Gray death effect
        }
        
        debug.log("Created death effect for unit " .. unit.name, "MELEE_COMBAT")
    end
end
-- }}}

-- {{{ MeleeCombatSystem:schedule_unit_removal
function MeleeCombatSystem:schedule_unit_removal(unit, delay)
    -- This would integrate with a unit manager or entity removal system
    -- For now, just mark for removal
    local removal_time = love.timer.getTime() + delay
    
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.scheduled_removal_time = removal_time
    end
    
    debug.log("Scheduled removal of unit " .. unit.name .. " in " .. delay .. " seconds", "MELEE_COMBAT")
end
-- }}}

-- {{{ MeleeCombatSystem:get_combat_stats
function MeleeCombatSystem:get_combat_stats(unit)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not unit_data or not unit_data.combat_data then
        return nil
    end
    
    return {
        total_damage_dealt = unit_data.combat_data.total_damage_dealt,
        attacks_made = unit_data.combat_data.attacks_made,
        average_damage = unit_data.combat_data.attacks_made > 0 and 
                        (unit_data.combat_data.total_damage_dealt / unit_data.combat_data.attacks_made) or 0,
        fatigue_factor = self.fatigue_factors[unit.id] or 1.0
    }
end
-- }}}

-- {{{ MeleeCombatSystem:get_debug_info
function MeleeCombatSystem:get_debug_info()
    local active_melee_combats = 0
    local total_fatigue_units = 0
    local average_fatigue = 0
    
    for _ in pairs(self.combat_timers) do
        active_melee_combats = active_melee_combats + 1
    end
    
    for _, fatigue in pairs(self.fatigue_factors) do
        total_fatigue_units = total_fatigue_units + 1
        average_fatigue = average_fatigue + fatigue
    end
    
    average_fatigue = total_fatigue_units > 0 and (average_fatigue / total_fatigue_units) or 1.0
    
    return {
        active_melee_combats = active_melee_combats,
        units_with_fatigue = total_fatigue_units,
        average_fatigue_factor = average_fatigue,
        base_attack_damage = self.base_attack_damage,
        attack_cooldown = self.attack_cooldown,
        optimal_range = self.optimal_range,
        damage_variance = self.damage_variance
    }
end
-- }}}

return MeleeCombatSystem
-- }}}