-- {{{ HealthSystem
local HealthSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- {{{ HealthSystem:new
function HealthSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        name = "health_system",
        
        -- Health parameters
        base_regen_rate = 0.5,        -- HP per second regeneration
        regen_delay = 5.0,            -- Seconds after damage before regeneration
        corpse_lifetime = 5.0,        -- How long corpses remain visible
        
        -- DOT parameters
        max_dot_effects = 5,          -- Maximum DOT effects per unit
        dot_stack_types = {           -- Types that can stack
            "poison", "fire", "bleed"
        },
        
        -- Death parameters
        death_effect_radius = 25,     -- Radius of death explosion
        screen_shake_threshold = "elite", -- Unit types that cause screen shake
        
        -- Scheduled operations
        scheduled_removals = {},      -- Units scheduled for removal
        scheduled_effects = {},       -- Delayed effects to apply
        
        -- Health tracking
        health_change_log = {},       -- Track health changes for analytics
        death_notifications = {},     -- Death events to process
        
        -- Update frequency
        update_frequency = 1/20,      -- Update 20 times per second
        last_update = 0
    }
    setmetatable(system, {__index = HealthSystem})
    
    debug.log("HealthSystem created", "HEALTH")
    return system
end
-- }}}

-- {{{ HealthSystem:update
function HealthSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Get all units with health components
    local units_with_health = self.entity_manager:get_entities_with_components({
        "health", "unit_data"
    })
    
    -- Process each unit's health
    for _, unit in ipairs(units_with_health) do
        if Unit.is_alive(self.entity_manager, unit) then
            self:update_unit_health(unit, self.last_update)
        else
            self:update_dead_unit(unit, self.last_update)
        end
    end
    
    -- Process scheduled operations
    self:process_scheduled_removals()
    self:process_death_notifications()
    
    self.last_update = 0
end
-- }}}

-- {{{ HealthSystem:update_unit_health
function HealthSystem:update_unit_health(unit, dt)
    local health = self.entity_manager:get_component(unit, "health")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not health or not unit_data then
        return
    end
    
    -- Update health regeneration
    self:update_health_regeneration(unit, health, dt)
    
    -- Update damage over time effects
    self:update_damage_over_time(unit, health, dt)
    
    -- Check for death conditions
    self:check_death_conditions(unit, health, unit_data)
    
    -- Update health display/UI
    self:update_health_display(unit, health)
end
-- }}}

-- {{{ HealthSystem:update_dead_unit
function HealthSystem:update_dead_unit(unit, dt)
    local health = self.entity_manager:get_component(unit, "health")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not health or not unit_data then
        return
    end
    
    -- Update corpse decay
    if health.death_time then
        local time_since_death = love.timer.getTime() - health.death_time
        
        -- Fade corpse over time
        local renderable = self.entity_manager:get_component(unit, "renderable")
        if renderable then
            local fade_progress = time_since_death / self.corpse_lifetime
            renderable.alpha = math.max(0.2, 0.6 - fade_progress * 0.4)
        end
    end
end
-- }}}

-- {{{ HealthSystem:update_health_regeneration
function HealthSystem:update_health_regeneration(unit, health, dt)
    if not health.is_alive or health.current_hp >= health.max_hp then
        return
    end
    
    local current_time = love.timer.getTime()
    local time_since_damage = current_time - (health.last_damage_time or 0)
    
    -- Only regenerate if no damage taken recently
    if time_since_damage > self.regen_delay then
        local regen_amount = self.base_regen_rate * dt
        local old_health = health.current_hp
        health.current_hp = math.min(health.max_hp, health.current_hp + regen_amount)
        
        -- Log health change
        self:log_health_change(unit, old_health, health.current_hp, "regeneration")
        
        -- Create regeneration effect occasionally
        if math.random() < 0.1 then  -- 10% chance per update
            self:create_regeneration_effect(unit)
        end
    end
end
-- }}}

-- {{{ HealthSystem:update_damage_over_time
function HealthSystem:update_damage_over_time(unit, health, dt)
    if not health.damage_over_time_effects or #health.damage_over_time_effects == 0 then
        return
    end
    
    local current_time = love.timer.getTime()
    local effects_to_remove = {}
    
    for i, effect in ipairs(health.damage_over_time_effects) do
        if current_time >= effect.next_tick_time then
            -- Apply DOT damage
            local damage_dealt = self:apply_damage_to_unit(unit, effect.damage_per_tick, effect.source_id, "dot")
            
            -- Create DOT visual effect
            self:create_dot_damage_effect(unit, damage_dealt, effect.type)
            
            -- Update effect timing
            effect.next_tick_time = current_time + effect.tick_interval
            effect.remaining_duration = effect.remaining_duration - effect.tick_interval
            
            -- Check if effect has expired
            if effect.remaining_duration <= 0 then
                table.insert(effects_to_remove, i)
                debug.log("DOT effect " .. effect.type .. " expired on unit " .. unit.name, "HEALTH")
            end
        end
    end
    
    -- Remove expired effects (in reverse order to maintain indices)
    for i = #effects_to_remove, 1, -1 do
        table.remove(health.damage_over_time_effects, effects_to_remove[i])
    end
end
-- }}}

-- {{{ HealthSystem:check_death_conditions
function HealthSystem:check_death_conditions(unit, health, unit_data)
    if health.current_hp <= 0 and health.is_alive then
        self:trigger_unit_death(unit, health, unit_data)
    end
end
-- }}}

-- {{{ HealthSystem:trigger_unit_death
function HealthSystem:trigger_unit_death(unit, health, unit_data)
    health.is_alive = false
    health.death_time = love.timer.getTime()
    unit_data.combat_state = "dead"
    
    -- Stop all movement immediately
    local moveable = self.entity_manager:get_component(unit, "moveable")
    if moveable then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.moving = false
    end
    
    -- Update visual appearance
    self:update_death_appearance(unit)
    
    -- Schedule death notifications and cleanup
    table.insert(self.death_notifications, {
        unit = unit,
        killer_id = health.last_attacker_id,
        death_time = health.death_time
    })
    
    -- Create comprehensive death effects
    self:create_comprehensive_death_effect(unit, unit_data)
    
    -- Schedule corpse removal
    self:schedule_corpse_removal(unit, self.corpse_lifetime)
    
    debug.log("Unit " .. unit.name .. " has died", "HEALTH")
end
-- }}}

-- {{{ HealthSystem:update_death_appearance
function HealthSystem:update_death_appearance(unit)
    local renderable = self.entity_manager:get_component(unit, "renderable")
    
    if renderable then
        -- Change appearance to indicate death
        renderable.color = {0.4, 0.4, 0.4}  -- Dark gray
        renderable.alpha = 0.6
        renderable.render_layer = "corpses"  -- Render behind living units
        renderable.death_marker = true
    end
end
-- }}}

-- {{{ HealthSystem:apply_damage_to_unit
function HealthSystem:apply_damage_to_unit(target, damage, attacker_id, damage_type)
    local health = self.entity_manager:get_component(target, "health")
    
    if not health or not health.is_alive or damage <= 0 then
        return 0
    end
    
    -- Calculate actual damage dealt
    local damage_dealt = math.min(damage, health.current_hp)
    local old_health = health.current_hp
    
    -- Apply damage
    health.current_hp = health.current_hp - damage_dealt
    health.last_damage_time = love.timer.getTime()
    health.last_attacker_id = attacker_id
    
    -- Log health change
    self:log_health_change(target, old_health, health.current_hp, damage_type or "direct", attacker_id)
    
    -- Create damage number effect
    self:create_damage_number_effect(target, damage_dealt, damage_type)
    
    -- Check if unit dies
    if health.current_hp <= 0 then
        health.current_hp = 0
        -- Death will be handled in next update cycle
    end
    
    return damage_dealt
end
-- }}}

-- {{{ HealthSystem:add_damage_over_time_effect
function HealthSystem:add_damage_over_time_effect(unit, damage_per_tick, tick_interval, duration, source_id, effect_type)
    local health = self.entity_manager:get_component(unit, "health")
    
    if not health or not health.is_alive then
        return false
    end
    
    -- Initialize DOT effects array if needed
    if not health.damage_over_time_effects then
        health.damage_over_time_effects = {}
    end
    
    -- Check if we can add more DOT effects
    if #health.damage_over_time_effects >= self.max_dot_effects then
        -- Remove oldest effect if at limit
        table.remove(health.damage_over_time_effects, 1)
        debug.log("Removed oldest DOT effect due to limit", "HEALTH")
    end
    
    -- Check for stacking of same type
    if effect_type and self:is_stackable_dot_type(effect_type) then
        self:stack_dot_effect(health, damage_per_tick, tick_interval, duration, source_id, effect_type)
    else
        self:add_new_dot_effect(health, damage_per_tick, tick_interval, duration, source_id, effect_type)
    end
    
    debug.log("Applied DOT effect to unit " .. unit.name .. ": " .. damage_per_tick .. " damage every " .. tick_interval .. "s", "HEALTH")
    return true
end
-- }}}

-- {{{ HealthSystem:is_stackable_dot_type
function HealthSystem:is_stackable_dot_type(effect_type)
    for _, stackable_type in ipairs(self.dot_stack_types) do
        if effect_type == stackable_type then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ HealthSystem:stack_dot_effect
function HealthSystem:stack_dot_effect(health, damage_per_tick, tick_interval, duration, source_id, effect_type)
    -- Find existing effect of same type
    for _, effect in ipairs(health.damage_over_time_effects) do
        if effect.type == effect_type then
            -- Stack damage and refresh duration
            effect.damage_per_tick = effect.damage_per_tick + damage_per_tick
            effect.remaining_duration = math.max(effect.remaining_duration, duration)
            debug.log("Stacked DOT effect: " .. effect_type, "HEALTH")
            return
        end
    end
    
    -- No existing effect found, add new one
    self:add_new_dot_effect(health, damage_per_tick, tick_interval, duration, source_id, effect_type)
end
-- }}}

-- {{{ HealthSystem:add_new_dot_effect
function HealthSystem:add_new_dot_effect(health, damage_per_tick, tick_interval, duration, source_id, effect_type)
    local dot_effect = {
        damage_per_tick = damage_per_tick,
        tick_interval = tick_interval,
        remaining_duration = duration,
        next_tick_time = love.timer.getTime() + tick_interval,
        source_id = source_id,
        type = effect_type or "generic"
    }
    
    table.insert(health.damage_over_time_effects, dot_effect)
end
-- }}}

-- {{{ HealthSystem:heal_unit
function HealthSystem:heal_unit(unit, heal_amount, source_id)
    local health = self.entity_manager:get_component(unit, "health")
    
    if not health or not health.is_alive or heal_amount <= 0 then
        return 0
    end
    
    local old_health = health.current_hp
    local healing_done = math.min(heal_amount, health.max_hp - health.current_hp)
    
    health.current_hp = health.current_hp + healing_done
    
    -- Log health change
    self:log_health_change(unit, old_health, health.current_hp, "healing", source_id)
    
    -- Create healing effect
    self:create_healing_effect(unit, healing_done)
    
    debug.log("Healed unit " .. unit.name .. " for " .. healing_done .. " HP", "HEALTH")
    return healing_done
end
-- }}}

-- {{{ HealthSystem:create_comprehensive_death_effect
function HealthSystem:create_comprehensive_death_effect(unit, unit_data)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    -- Main death explosion effect
    local explosion_effect = {
        type = "death_explosion",
        position = unit_pos,
        duration = 1.2,
        start_time = love.timer.getTime(),
        max_radius = self.death_effect_radius,
        unit_type = unit_data.unit_type or "unknown",
        color = {1.0, 0.8, 0.2, 0.8}  -- Orange explosion
    }
    debug.log("Created death explosion effect", "HEALTH")
    
    -- Particle burst effects
    local particle_count = unit_data.unit_type == "elite" and 12 or 8
    for i = 1, particle_count do
        local angle = (i / particle_count) * 2 * math.pi
        local speed = 25 + math.random() * 10
        local particle_velocity = Vector2:new(
            math.cos(angle) * speed,
            math.sin(angle) * speed
        )
        
        local particle_effect = {
            type = "death_particle",
            position = unit_pos,
            velocity = particle_velocity,
            duration = 0.8 + math.random() * 0.4,
            start_time = love.timer.getTime(),
            size = 2 + math.random() * 2,
            color = {0.9, 0.7, 0.3, 1.0}  -- Golden particles
        }
        debug.log("Created death particle effect", "HEALTH")
    end
    
    -- Screen shake for elite units
    if unit_data.unit_type == self.screen_shake_threshold then
        local shake_effect = {
            type = "screen_shake",
            intensity = 8,
            duration = 0.4,
            start_time = love.timer.getTime()
        }
        debug.log("Created screen shake effect for elite death", "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:create_damage_number_effect
function HealthSystem:create_damage_number_effect(target, damage, damage_type)
    local position = self.entity_manager:get_component(target, "position")
    
    if position then
        local color = {1.0, 0.3, 0.3, 1.0}  -- Red for normal damage
        
        if damage_type == "dot" then
            color = {0.8, 0.4, 0.8, 1.0}  -- Purple for DOT
        elseif damage_type == "critical" then
            color = {1.0, 1.0, 0.3, 1.0}  -- Yellow for critical
        end
        
        local effect = {
            type = "damage_number",
            position = Vector2:new(position.x + math.random(-8, 8), position.y - 15),
            damage = damage,
            duration = 1.5,
            start_time = love.timer.getTime(),
            velocity = Vector2:new((math.random() - 0.5) * 15, -30),
            color = color,
            size = damage_type == "critical" and 1.5 or 1.0
        }
        debug.log("Created damage number: " .. damage, "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:create_healing_effect
function HealthSystem:create_healing_effect(target, heal_amount)
    local position = self.entity_manager:get_component(target, "position")
    
    if position then
        local effect = {
            type = "healing_number",
            position = Vector2:new(position.x, position.y - 10),
            heal_amount = heal_amount,
            duration = 1.2,
            start_time = love.timer.getTime(),
            velocity = Vector2:new(0, -25),
            color = {0.3, 1.0, 0.3, 1.0},  -- Bright green
            size = 1.2
        }
        debug.log("Created healing effect: +" .. heal_amount .. " HP", "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:create_regeneration_effect
function HealthSystem:create_regeneration_effect(unit)
    local position = self.entity_manager:get_component(unit, "position")
    
    if position then
        local effect = {
            type = "regeneration",
            position = Vector2:new(position.x, position.y - 5),
            duration = 0.6,
            start_time = love.timer.getTime(),
            color = {0.4, 0.9, 0.4, 0.7},  -- Soft green
            size = 0.8
        }
        debug.log("Created regeneration effect", "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:create_dot_damage_effect
function HealthSystem:create_dot_damage_effect(target, damage, dot_type)
    local position = self.entity_manager:get_component(target, "position")
    
    if position then
        local color = {0.6, 0.3, 0.6, 1.0}  -- Purple for generic DOT
        
        if dot_type == "poison" then
            color = {0.3, 0.8, 0.3, 1.0}  -- Green for poison
        elseif dot_type == "fire" then
            color = {1.0, 0.5, 0.1, 1.0}  -- Orange for fire
        elseif dot_type == "bleed" then
            color = {0.8, 0.1, 0.1, 1.0}  -- Dark red for bleed
        end
        
        local effect = {
            type = "dot_damage",
            position = Vector2:new(position.x + math.random(-6, 6), position.y - 12),
            damage = damage,
            duration = 1.0,
            start_time = love.timer.getTime(),
            velocity = Vector2:new((math.random() - 0.5) * 8, -18),
            color = color,
            dot_type = dot_type
        }
        debug.log("Created DOT damage effect: " .. damage .. " " .. dot_type, "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:process_death_notifications
function HealthSystem:process_death_notifications()
    for _, death_event in ipairs(self.death_notifications) do
        self:notify_unit_death(death_event.unit, death_event.killer_id)
    end
    
    -- Clear processed notifications
    self.death_notifications = {}
end
-- }}}

-- {{{ HealthSystem:notify_unit_death
function HealthSystem:notify_unit_death(dead_unit, killer_id)
    local unit_data = self.entity_manager:get_component(dead_unit, "unit_data")
    
    if not unit_data then
        return
    end
    
    -- Award kill rewards to killer
    if killer_id then
        self:award_kill_rewards(killer_id, unit_data)
    end
    
    -- Handle formation disruption
    if unit_data.formation_id then
        -- This would integrate with formation system
        debug.log("Unit death disrupted formation " .. unit_data.formation_id, "HEALTH")
    end
    
    -- Handle combat cleanup
    self:handle_death_combat_cleanup(dead_unit, unit_data)
    
    debug.log("Processed death notification for unit " .. dead_unit.name, "HEALTH")
end
-- }}}

-- {{{ HealthSystem:award_kill_rewards
function HealthSystem:award_kill_rewards(killer_id, dead_unit_data)
    local killer = self.entity_manager:get_entity_by_id(killer_id)
    if not killer then
        return
    end
    
    local killer_unit_data = self.entity_manager:get_component(killer, "unit_data")
    
    if killer_unit_data then
        -- Initialize combat stats if needed
        if not killer_unit_data.combat_stats then
            killer_unit_data.combat_stats = {
                kills = 0,
                damage_dealt = 0,
                experience = 0
            }
        end
        
        -- Award kill count and experience
        killer_unit_data.combat_stats.kills = killer_unit_data.combat_stats.kills + 1
        killer_unit_data.combat_stats.experience = killer_unit_data.combat_stats.experience + 15
        
        -- Create reward effect
        self:create_kill_reward_effect(killer)
        
        debug.log("Awarded kill reward to " .. killer.name, "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:create_kill_reward_effect
function HealthSystem:create_kill_reward_effect(killer)
    local position = self.entity_manager:get_component(killer, "position")
    
    if position then
        local effect = {
            type = "kill_reward",
            position = Vector2:new(position.x, position.y - 20),
            duration = 1.0,
            start_time = love.timer.getTime(),
            velocity = Vector2:new(0, -15),
            color = {1.0, 1.0, 0.3, 1.0},  -- Gold color
            text = "+EXP"
        }
        debug.log("Created kill reward effect", "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:handle_death_combat_cleanup
function HealthSystem:handle_death_combat_cleanup(dead_unit, unit_data)
    -- This would integrate with combat detection system
    -- Clear any combat engagements involving this unit
    debug.log("Handling combat cleanup for dead unit " .. dead_unit.name, "HEALTH")
end
-- }}}

-- {{{ HealthSystem:schedule_corpse_removal
function HealthSystem:schedule_corpse_removal(unit, delay)
    local removal_time = love.timer.getTime() + delay
    
    table.insert(self.scheduled_removals, {
        unit = unit,
        removal_time = removal_time
    })
    
    debug.log("Scheduled removal of corpse " .. unit.name .. " in " .. delay .. " seconds", "HEALTH")
end
-- }}}

-- {{{ HealthSystem:process_scheduled_removals
function HealthSystem:process_scheduled_removals()
    local current_time = love.timer.getTime()
    local removals_to_process = {}
    
    for i, removal in ipairs(self.scheduled_removals) do
        if current_time >= removal.removal_time then
            table.insert(removals_to_process, i)
            
            -- Create fade-out effect before removal
            self:create_corpse_fade_effect(removal.unit)
            
            -- Remove unit entity
            self.entity_manager:remove_entity(removal.unit)
            
            debug.log("Removed corpse: " .. removal.unit.name, "HEALTH")
        end
    end
    
    -- Remove processed removals (in reverse order to maintain indices)
    for i = #removals_to_process, 1, -1 do
        table.remove(self.scheduled_removals, removals_to_process[i])
    end
end
-- }}}

-- {{{ HealthSystem:create_corpse_fade_effect
function HealthSystem:create_corpse_fade_effect(unit)
    local position = self.entity_manager:get_component(unit, "position")
    
    if position then
        local effect = {
            type = "corpse_fade",
            position = Vector2:new(position.x, position.y),
            duration = 0.5,
            start_time = love.timer.getTime(),
            color = {0.8, 0.8, 0.8, 0.5}
        }
        debug.log("Created corpse fade effect", "HEALTH")
    end
end
-- }}}

-- {{{ HealthSystem:update_health_display
function HealthSystem:update_health_display(unit, health)
    -- This would integrate with UI system to update health bars
    -- For now, just ensure health percentage is calculated
    health.health_percentage = health.current_hp / health.max_hp
end
-- }}}

-- {{{ HealthSystem:log_health_change
function HealthSystem:log_health_change(unit, old_health, new_health, change_type, source_id)
    local health_change = {
        unit_id = unit.id,
        old_health = old_health,
        new_health = new_health,
        change_amount = new_health - old_health,
        change_type = change_type,
        source_id = source_id,
        timestamp = love.timer.getTime()
    }
    
    table.insert(self.health_change_log, health_change)
    
    -- Limit log size
    if #self.health_change_log > 1000 then
        table.remove(self.health_change_log, 1)
    end
end
-- }}}

-- {{{ HealthSystem:get_unit_health_percentage
function HealthSystem:get_unit_health_percentage(unit)
    local health = self.entity_manager:get_component(unit, "health")
    
    if not health then
        return 0
    end
    
    return health.current_hp / health.max_hp
end
-- }}}

-- {{{ HealthSystem:get_debug_info
function HealthSystem:get_debug_info()
    local living_units = 0
    local dead_units = 0
    local total_dot_effects = 0
    local pending_removals = #self.scheduled_removals
    
    local units_with_health = self.entity_manager:get_entities_with_components({"health"})
    
    for _, unit in ipairs(units_with_health) do
        local health = self.entity_manager:get_component(unit, "health")
        if health then
            if health.is_alive then
                living_units = living_units + 1
            else
                dead_units = dead_units + 1
            end
            
            if health.damage_over_time_effects then
                total_dot_effects = total_dot_effects + #health.damage_over_time_effects
            end
        end
    end
    
    return {
        living_units = living_units,
        dead_units = dead_units,
        total_dot_effects = total_dot_effects,
        pending_removals = pending_removals,
        health_changes_logged = #self.health_change_log,
        base_regen_rate = self.base_regen_rate,
        regen_delay = self.regen_delay,
        corpse_lifetime = self.corpse_lifetime
    }
end
-- }}}

return HealthSystem
-- }}}