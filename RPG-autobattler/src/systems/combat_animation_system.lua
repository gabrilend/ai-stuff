-- {{{ CombatAnimationSystem
local CombatAnimationSystem = {}

local Vector2 = require("src.utils.vector2")
local MathUtils = require("src.utils.math_utils")
local Unit = require("src.entities.unit")
local debug = require("src.utils.debug")

-- {{{ CombatAnimationSystem:new
function CombatAnimationSystem:new(entity_manager, combat_detection_system)
    local system = {
        entity_manager = entity_manager,
        combat_detection_system = combat_detection_system,
        name = "combat_animation",
        
        -- Animation durations (in seconds)
        animation_durations = {
            idle = math.huge,           -- Loops indefinitely
            combat_idle = math.huge,    -- Loops indefinitely
            melee_attack = 0.6,         -- Melee attack sequence
            ranged_attack = 0.4,        -- Ranged attack sequence
            death = 2.0,                -- Death animation
            retreat = 0.3,              -- Retreat animation
            strafe = 0.5,               -- Strafe animation
            hurt = 0.2,                 -- Damage reaction
            positioning = 0.8           -- Tactical positioning
        },
        
        -- Animation speeds (multipliers)
        animation_speeds = {
            idle = 1.0,
            combat_idle = 1.2,          -- Slightly faster for tension
            melee_attack = 1.5,         -- Quick melee strikes
            ranged_attack = 1.8,        -- Fast ranged attacks
            death = 0.8,                -- Slower for dramatic effect
            retreat = 2.0,              -- Fast retreat
            strafe = 1.5,               -- Dynamic strafing
            hurt = 2.0,                 -- Quick damage reaction
            positioning = 1.3           -- Moderate positioning
        },
        
        -- Attack hit timings (when in animation to trigger effects)
        attack_hit_timings = {
            melee_attack = 0.3,         -- 30% through melee animation
            ranged_attack = 0.1,        -- 10% through ranged animation (projectile launch)
            basic_attack = 0.25         -- 25% through basic animation
        },
        
        -- Animation states and events
        active_animations = {},         -- Track active animations per unit
        scheduled_events = {},          -- Scheduled animation events
        effect_queue = {},              -- Queue of effects to create
        
        -- Visual effect parameters
        damage_number_base_size = 12,
        damage_number_size_scaling = 0.3,
        screen_shake_threshold = 20,
        knockback_threshold = 25,
        
        -- Update frequency
        update_frequency = 1/60,        -- 60 FPS for smooth animations
        last_update = 0
    }
    setmetatable(system, {__index = CombatAnimationSystem})
    
    debug.log("CombatAnimationSystem created", "COMBAT_ANIMATION")
    return system
end
-- }}}

-- {{{ CombatAnimationSystem:update
function CombatAnimationSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update < self.update_frequency then
        return
    end
    
    -- Update all unit animations
    local units_with_animations = self:get_animated_units()
    
    for _, unit in ipairs(units_with_animations) do
        self:update_unit_combat_animation(unit, self.last_update)
    end
    
    -- Process scheduled animation events
    self:process_scheduled_events()
    
    -- Process effect queue
    self:process_effect_queue()
    
    -- Clean up finished animations
    self:cleanup_finished_animations()
    
    self.last_update = 0
end
-- }}}

-- {{{ CombatAnimationSystem:get_animated_units
function CombatAnimationSystem:get_animated_units()
    local animated_units = {}
    
    local units = self.entity_manager:get_entities_with_components({
        "position", "renderable", "unit_data"
    })
    
    for _, unit in ipairs(units) do
        if Unit.is_alive(self.entity_manager, unit) then
            table.insert(animated_units, unit)
        end
    end
    
    return animated_units
end
-- }}}

-- {{{ CombatAnimationSystem:update_unit_combat_animation
function CombatAnimationSystem:update_unit_combat_animation(unit, dt)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    local renderable = self.entity_manager:get_component(unit, "renderable")
    
    if not unit_data or not renderable then
        return
    end
    
    -- Initialize animation data if needed
    if not unit_data.animation_data then
        unit_data.animation_data = {
            current_animation = "idle",
            animation_time = 0,
            frame_index = 0,
            animation_speed = 1.0,
            pending_animations = {},
            last_animation_change = 0
        }
    end
    
    local anim_data = unit_data.animation_data
    anim_data.animation_time = anim_data.animation_time + dt * anim_data.animation_speed
    
    -- Update animation based on unit state
    self:update_animation_based_on_state(unit, unit_data, anim_data)
    
    -- Process pending animations
    self:process_pending_animations(unit, anim_data)
    
    -- Update visual representation
    self:update_animation_visuals(unit, renderable, anim_data)
    
    -- Check for animation events
    self:check_animation_events(unit, anim_data)
end
-- }}}

-- {{{ CombatAnimationSystem:update_animation_based_on_state
function CombatAnimationSystem:update_animation_based_on_state(unit, unit_data, anim_data)
    local is_in_combat = self.combat_detection_system:is_unit_in_combat(unit)
    
    if is_in_combat then
        local combat_state = unit_data.combat_state or "engaging"
        self:update_combat_state_animation(unit, unit_data, anim_data, combat_state)
    else
        -- Return to idle animation
        if anim_data.current_animation ~= "idle" then
            self:start_animation(unit, "idle")
        end
    end
end
-- }}}

-- {{{ CombatAnimationSystem:update_combat_state_animation
function CombatAnimationSystem:update_combat_state_animation(unit, unit_data, anim_data, combat_state)
    if combat_state == "attacking" then
        self:update_attack_animation(unit, unit_data, anim_data)
    elseif combat_state == "retreating" then
        self:ensure_animation(unit, "retreat", anim_data)
    elseif combat_state == "strafing" then
        self:ensure_animation(unit, "strafe", anim_data)
    elseif combat_state == "positioning" then
        self:ensure_animation(unit, "positioning", anim_data)
    else
        -- Default combat idle
        self:ensure_animation(unit, "combat_idle", anim_data)
    end
end
-- }}}

-- {{{ CombatAnimationSystem:update_attack_animation
function CombatAnimationSystem:update_attack_animation(unit, unit_data, anim_data)
    local attack_animation = self:get_attack_animation_for_unit(unit_data.unit_type)
    
    if anim_data.current_animation ~= attack_animation then
        self:start_animation(unit, attack_animation)
        
        -- Schedule hit effect at appropriate time in animation
        local hit_timing = self.attack_hit_timings[attack_animation] or 0.3
        self:schedule_animation_event(unit, "hit_effect", hit_timing)
    end
    
    -- Check if attack animation is complete
    local animation_duration = self.animation_durations[attack_animation] or 1.0
    if anim_data.animation_time >= animation_duration then
        -- Return to combat idle
        self:start_animation(unit, "combat_idle")
    end
end
-- }}}

-- {{{ CombatAnimationSystem:ensure_animation
function CombatAnimationSystem:ensure_animation(unit, animation_name, anim_data)
    if anim_data.current_animation ~= animation_name then
        self:start_animation(unit, animation_name)
    end
end
-- }}}

-- {{{ CombatAnimationSystem:get_attack_animation_for_unit
function CombatAnimationSystem:get_attack_animation_for_unit(unit_type)
    if unit_type == "melee" then
        return "melee_attack"
    elseif unit_type == "ranged" then
        return "ranged_attack"
    else
        return "basic_attack"
    end
end
-- }}}

-- {{{ CombatAnimationSystem:start_animation
function CombatAnimationSystem:start_animation(unit, animation_name)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not unit_data or not unit_data.animation_data then
        return
    end
    
    local anim_data = unit_data.animation_data
    anim_data.current_animation = animation_name
    anim_data.animation_time = 0
    anim_data.frame_index = 0
    anim_data.last_animation_change = love.timer.getTime()
    
    -- Set animation speed based on type
    anim_data.animation_speed = self.animation_speeds[animation_name] or 1.0
    
    -- Store active animation
    self.active_animations[unit.id] = {
        animation = animation_name,
        start_time = love.timer.getTime(),
        duration = self.animation_durations[animation_name] or 1.0
    }
    
    debug.log("Unit " .. unit.name .. " starting animation: " .. animation_name, "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:schedule_animation_event
function CombatAnimationSystem:schedule_animation_event(unit, event_type, delay)
    local event_time = love.timer.getTime() + delay
    
    table.insert(self.scheduled_events, {
        unit = unit,
        event_type = event_type,
        trigger_time = event_time
    })
end
-- }}}

-- {{{ CombatAnimationSystem:process_scheduled_events
function CombatAnimationSystem:process_scheduled_events()
    local current_time = love.timer.getTime()
    local events_to_remove = {}
    
    for i, event in ipairs(self.scheduled_events) do
        if current_time >= event.trigger_time then
            self:execute_animation_event(event)
            table.insert(events_to_remove, i)
        end
    end
    
    -- Remove processed events (in reverse order)
    for i = #events_to_remove, 1, -1 do
        table.remove(self.scheduled_events, events_to_remove[i])
    end
end
-- }}}

-- {{{ CombatAnimationSystem:execute_animation_event
function CombatAnimationSystem:execute_animation_event(event)
    if event.event_type == "hit_effect" then
        local target = self.combat_detection_system:get_unit_target(event.unit)
        if target then
            local unit_data = self.entity_manager:get_component(event.unit, "unit_data")
            if unit_data then
                self:create_attack_effect(event.unit, target, unit_data.unit_type)
            end
        end
    end
end
-- }}}

-- {{{ CombatAnimationSystem:create_attack_effect
function CombatAnimationSystem:create_attack_effect(attacker, target, attack_type)
    local attacker_pos = self.entity_manager:get_component(attacker, "position")
    local target_pos = self.entity_manager:get_component(target, "position")
    
    if not attacker_pos or not target_pos then
        return
    end
    
    local attacker_position = Vector2:new(attacker_pos.x, attacker_pos.y)
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    
    if attack_type == "melee" then
        self:create_melee_attack_effect(attacker_position, target_position)
    elseif attack_type == "ranged" then
        self:create_ranged_attack_effect(attacker_position, target_position)
    else
        self:create_basic_attack_effect(attacker_position, target_position)
    end
end
-- }}}

-- {{{ CombatAnimationSystem:create_melee_attack_effect
function CombatAnimationSystem:create_melee_attack_effect(attacker_pos, target_pos)
    -- Slash effect from attacker to target
    local slash_effect = {
        type = "melee_slash",
        start_position = attacker_pos,
        end_position = target_pos,
        duration = 0.3,
        start_time = love.timer.getTime(),
        color = {1.0, 1.0, 1.0, 0.9},  -- White slash
        thickness = 4,
        fade_in_time = 0.05,
        fade_out_time = 0.2
    }
    
    table.insert(self.effect_queue, slash_effect)
    
    -- Impact flash at target
    local impact_effect = {
        type = "impact_flash",
        position = target_pos,
        duration = 0.15,
        start_time = love.timer.getTime() + 0.1,  -- Slight delay
        max_radius = 15,
        color = {1.0, 0.9, 0.2, 0.8},  -- Yellow impact
        expansion_speed = 80
    }
    
    table.insert(self.effect_queue, impact_effect)
    
    debug.log("Created melee attack effect", "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:create_ranged_attack_effect
function CombatAnimationSystem:create_ranged_attack_effect(attacker_pos, target_pos)
    -- Projectile effect
    local travel_time = attacker_pos:distance_to(target_pos) / 200  -- 200 units/second
    
    local projectile_effect = {
        type = "projectile",
        start_position = attacker_pos,
        end_position = target_pos,
        duration = travel_time,
        start_time = love.timer.getTime(),
        color = {0.9, 0.9, 1.0, 1.0},  -- Light blue projectile
        size = 3,
        trail_length = 8,
        speed = 200
    }
    
    table.insert(self.effect_queue, projectile_effect)
    
    -- Muzzle flash at attacker
    local muzzle_effect = {
        type = "muzzle_flash",
        position = attacker_pos,
        duration = 0.1,
        start_time = love.timer.getTime(),
        color = {1.0, 0.7, 0.2, 1.0},  -- Orange muzzle flash
        max_size = 8,
        fade_speed = 10
    }
    
    table.insert(self.effect_queue, muzzle_effect)
    
    debug.log("Created ranged attack effect", "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:create_basic_attack_effect
function CombatAnimationSystem:create_basic_attack_effect(attacker_pos, target_pos)
    -- Simple energy blast effect
    local energy_effect = {
        type = "energy_blast",
        start_position = attacker_pos,
        end_position = target_pos,
        duration = 0.4,
        start_time = love.timer.getTime(),
        color = {0.8, 0.8, 1.0, 0.8},  -- Light purple energy
        thickness = 2
    }
    
    table.insert(self.effect_queue, energy_effect)
    
    debug.log("Created basic attack effect", "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:create_damage_feedback
function CombatAnimationSystem:create_damage_feedback(unit, damage_amount, damage_type)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    -- Damage number with scaling
    local font_size = self.damage_number_base_size + damage_amount * self.damage_number_size_scaling
    font_size = math.min(24, font_size)  -- Cap at 24
    
    local number_effect = {
        type = "damage_number",
        position = Vector2:new(unit_pos.x + math.random(-8, 8), unit_pos.y - 15),
        damage = damage_amount,
        duration = 1.5,
        start_time = love.timer.getTime(),
        velocity = Vector2:new(math.random(-15, 15), -30),
        color = self:get_damage_color(damage_type),
        font_size = font_size,
        gravity = 20
    }
    
    table.insert(self.effect_queue, number_effect)
    
    -- Screen shake for significant damage
    if damage_amount >= self.screen_shake_threshold then
        local shake_intensity = math.min(10, damage_amount / 4)
        local shake_effect = {
            type = "screen_shake",
            intensity = shake_intensity,
            duration = 0.25,
            start_time = love.timer.getTime(),
            frequency = 20
        }
        
        table.insert(self.effect_queue, shake_effect)
    end
    
    -- Unit hurt animation
    self:trigger_hurt_animation(unit, damage_type)
    
    -- Knockback for critical hits
    if damage_amount >= self.knockback_threshold or damage_type == "critical" then
        self:create_knockback_effect(unit, math.min(8, damage_amount / 5))
    end
    
    debug.log("Created damage feedback for " .. damage_amount .. " " .. damage_type .. " damage", "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:get_damage_color
function CombatAnimationSystem:get_damage_color(damage_type)
    local colors = {
        critical = {1.0, 0.6, 0.2, 1.0},    -- Orange for critical
        fire = {1.0, 0.3, 0.1, 1.0},        -- Red for fire
        poison = {0.2, 0.8, 0.2, 1.0},      -- Green for poison
        ice = {0.4, 0.8, 1.0, 1.0},         -- Light blue for ice
        magic = {0.7, 0.3, 1.0, 1.0},       -- Purple for magic
        healing = {0.2, 1.0, 0.2, 1.0},     -- Bright green for healing
        normal = {1.0, 1.0, 1.0, 1.0}       -- White for normal
    }
    
    return colors[damage_type] or colors.normal
end
-- }}}

-- {{{ CombatAnimationSystem:trigger_hurt_animation
function CombatAnimationSystem:trigger_hurt_animation(unit, damage_type)
    -- Add hurt animation to pending queue
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data and unit_data.animation_data then
        table.insert(unit_data.animation_data.pending_animations, "hurt")
    end
    
    -- Unit flash effect
    local flash_effect = {
        type = "unit_flash",
        unit_id = unit.id,
        duration = 0.2,
        start_time = love.timer.getTime(),
        flash_color = damage_type == "critical" and {1.0, 0.6, 0.2, 0.8} or {1.0, 0.2, 0.2, 0.8},
        flash_intensity = damage_type == "critical" and 0.9 or 0.7,
        flash_frequency = 15
    }
    
    table.insert(self.effect_queue, flash_effect)
end
-- }}}

-- {{{ CombatAnimationSystem:create_knockback_effect
function CombatAnimationSystem:create_knockback_effect(unit, knockback_distance)
    local position = self.entity_manager:get_component(unit, "position")
    
    if not position then
        return
    end
    
    -- Get knockback direction from combat target
    local target = self.combat_detection_system:get_unit_target(unit)
    local knockback_direction = Vector2:new(1, 0)  -- Default direction
    
    if target then
        local target_pos = self.entity_manager:get_component(target, "position")
        if target_pos then
            local unit_pos = Vector2:new(position.x, position.y)
            local target_position = Vector2:new(target_pos.x, target_pos.y)
            knockback_direction = unit_pos:subtract(target_position):normalize()
        end
    end
    
    -- Apply knockback effect
    local knockback_effect = {
        type = "knockback",
        unit_id = unit.id,
        direction = knockback_direction,
        distance = knockback_distance,
        duration = 0.3,
        start_time = love.timer.getTime(),
        easing = "ease_out"
    }
    
    table.insert(self.effect_queue, knockback_effect)
    
    debug.log("Created knockback effect for unit " .. unit.name, "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:create_death_animation
function CombatAnimationSystem:create_death_animation(unit)
    local position = self.entity_manager:get_component(unit, "position")
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    
    if not position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    -- Start death animation on unit
    self:start_animation(unit, "death")
    
    -- Death explosion effect
    local explosion_effect = {
        type = "death_explosion",
        position = unit_pos,
        duration = 1.2,
        start_time = love.timer.getTime(),
        max_radius = 25,
        color = {1.0, 0.9, 0.7, 0.8},  -- Warm explosion color
        ring_count = 3,
        expansion_speed = 40
    }
    
    table.insert(self.effect_queue, explosion_effect)
    
    -- Particle burst
    local particle_count = unit_data and unit_data.unit_type == "elite" and 12 or 8
    for i = 1, particle_count do
        local angle = (i / particle_count) * 2 * math.pi
        local speed = 30 + math.random() * 20
        local particle_velocity = Vector2:new(
            math.cos(angle) * speed,
            math.sin(angle) * speed
        )
        
        local particle_effect = {
            type = "death_particle",
            position = unit_pos,
            velocity = particle_velocity,
            duration = 1.0 + math.random() * 0.5,
            start_time = love.timer.getTime(),
            size = 2 + math.random() * 2,
            color = {0.8, 0.7, 0.6, 1.0},  -- Dust color
            gravity = 15,
            bounce = 0.3
        }
        
        table.insert(self.effect_queue, particle_effect)
    end
    
    -- Screen flash for elite units
    if unit_data and unit_data.unit_type == "elite" then
        local screen_flash = {
            type = "screen_flash",
            color = {1.0, 1.0, 1.0, 1.0},
            intensity = 0.4,
            duration = 0.3,
            start_time = love.timer.getTime(),
            fade_type = "exponential"
        }
        
        table.insert(self.effect_queue, screen_flash)
    end
    
    debug.log("Created death animation for unit " .. unit.name, "COMBAT_ANIMATION")
end
-- }}}

-- {{{ CombatAnimationSystem:update_animation_visuals
function CombatAnimationSystem:update_animation_visuals(unit, renderable, anim_data)
    if not renderable then
        return
    end
    
    local animation_name = anim_data.current_animation
    local animation_time = anim_data.animation_time
    
    -- Reset to defaults first
    renderable.scale = 1.0
    renderable.offset_x = 0
    renderable.offset_y = 0
    renderable.rotation = 0
    
    if animation_name == "melee_attack" then
        -- Scale up and slight forward movement during attack
        local attack_progress = animation_time / (self.animation_durations.melee_attack or 0.6)
        local scale_factor = 1 + 0.3 * math.sin(attack_progress * math.pi)
        renderable.scale = scale_factor
        renderable.offset_x = math.sin(attack_progress * math.pi) * 3
        
    elseif animation_name == "ranged_attack" then
        -- Slight recoil effect
        local attack_progress = animation_time / (self.animation_durations.ranged_attack or 0.4)
        local recoil = math.sin(attack_progress * math.pi * 2) * 2
        renderable.offset_x = -recoil
        
    elseif animation_name == "death" then
        -- Fade out and slight rotation
        local death_progress = animation_time / (self.animation_durations.death or 2.0)
        renderable.alpha = math.max(0, 1 - death_progress)
        renderable.rotation = death_progress * 0.3
        
    elseif animation_name == "hurt" then
        -- Quick shake effect
        local hurt_progress = animation_time / (self.animation_durations.hurt or 0.2)
        if hurt_progress < 1.0 then
            renderable.offset_x = math.sin(hurt_progress * math.pi * 8) * 2
        end
        
    elseif animation_name == "retreat" then
        -- Slight backward lean
        renderable.offset_x = -1
        renderable.scale = 0.95
        
    elseif animation_name == "strafe" then
        -- Subtle side-to-side movement
        local strafe_progress = animation_time / (self.animation_durations.strafe or 0.5)
        renderable.offset_x = math.sin(strafe_progress * math.pi * 2) * 1
        
    elseif animation_name == "combat_idle" then
        -- Subtle breathing/tension effect
        local idle_cycle = math.sin(animation_time * 2) * 0.02
        renderable.scale = 1 + idle_cycle
    end
end
-- }}}

-- {{{ CombatAnimationSystem:process_pending_animations
function CombatAnimationSystem:process_pending_animations(unit, anim_data)
    if not anim_data.pending_animations or #anim_data.pending_animations == 0 then
        return
    end
    
    -- Check if current animation can be interrupted
    local current_duration = self.animation_durations[anim_data.current_animation] or 1.0
    local can_interrupt = current_duration == math.huge or  -- Looping animations
                          anim_data.animation_time >= current_duration * 0.8  -- Near end
    
    if can_interrupt then
        local next_animation = table.remove(anim_data.pending_animations, 1)
        self:start_animation(unit, next_animation)
    end
end
-- }}}

-- {{{ CombatAnimationSystem:check_animation_events
function CombatAnimationSystem:check_animation_events(unit, anim_data)
    local animation_name = anim_data.current_animation
    local animation_time = anim_data.animation_time
    
    -- Check for animation completion
    local duration = self.animation_durations[animation_name]
    if duration and duration ~= math.huge and animation_time >= duration then
        self:on_animation_complete(unit, animation_name)
    end
end
-- }}}

-- {{{ CombatAnimationSystem:on_animation_complete
function CombatAnimationSystem:on_animation_complete(unit, animation_name)
    if animation_name == "hurt" then
        -- Return to previous animation or combat idle
        local is_in_combat = self.combat_detection_system:is_unit_in_combat(unit)
        self:start_animation(unit, is_in_combat and "combat_idle" or "idle")
    elseif animation_name == "death" then
        -- Mark animation as complete, keep death visuals
        debug.log("Death animation completed for unit " .. unit.name, "COMBAT_ANIMATION")
    end
end
-- }}}

-- {{{ CombatAnimationSystem:process_effect_queue
function CombatAnimationSystem:process_effect_queue()
    -- This would integrate with an actual effect system
    -- For now, just log the effects being created
    for _, effect in ipairs(self.effect_queue) do
        debug.log("Creating effect: " .. effect.type, "COMBAT_ANIMATION")
    end
    
    -- Clear the queue
    self.effect_queue = {}
end
-- }}}

-- {{{ CombatAnimationSystem:cleanup_finished_animations
function CombatAnimationSystem:cleanup_finished_animations()
    local current_time = love.timer.getTime()
    local animations_to_remove = {}
    
    for unit_id, animation_info in pairs(self.active_animations) do
        local elapsed = current_time - animation_info.start_time
        if elapsed >= animation_info.duration and animation_info.duration ~= math.huge then
            table.insert(animations_to_remove, unit_id)
        end
    end
    
    for _, unit_id in ipairs(animations_to_remove) do
        self.active_animations[unit_id] = nil
    end
end
-- }}}

-- {{{ CombatAnimationSystem:trigger_attack_animation
function CombatAnimationSystem:trigger_attack_animation(unit)
    local unit_data = self.entity_manager:get_component(unit, "unit_data")
    if unit_data then
        unit_data.combat_state = "attacking"
        debug.log("Triggered attack animation for unit " .. unit.name, "COMBAT_ANIMATION")
    end
end
-- }}}

-- {{{ CombatAnimationSystem:get_debug_info
function CombatAnimationSystem:get_debug_info()
    local active_animation_count = 0
    local animation_types = {}
    
    for unit_id, animation_info in pairs(self.active_animations) do
        active_animation_count = active_animation_count + 1
        local anim_type = animation_info.animation
        animation_types[anim_type] = (animation_types[anim_type] or 0) + 1
    end
    
    return {
        active_animations = active_animation_count,
        animation_distribution = animation_types,
        scheduled_events = #self.scheduled_events,
        queued_effects = #self.effect_queue,
        animation_durations = self.animation_durations,
        animation_speeds = self.animation_speeds
    }
end
-- }}}

return CombatAnimationSystem
-- }}}