# Issue #030: Add Basic Combat Animations and Feedback

## Current Behavior
Combat occurs with minimal visual feedback, making it difficult for players to understand what's happening during battles.

## Intended Behavior
Combat should have clear visual animations and feedback including attack animations, hit effects, damage indicators, and state transitions that enhance gameplay clarity.

## Implementation Details

### Combat Animation System (src/systems/combat_animation_system.lua)
```lua
-- {{{ local function update_combat_animations
local function update_combat_animations(dt)
    local units_in_combat = get_units_in_combat()
    
    for _, unit_id in ipairs(units_in_combat) do
        update_unit_combat_animation(unit_id, dt)
    end
    
    // Update combat effects
    update_combat_effects(dt)
end
-- }}}

-- {{{ local function update_unit_combat_animation
local function update_unit_combat_animation(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local renderable = EntityManager:get_component(unit_id, "renderable")
    
    if not unit_data or not renderable then
        return
    end
    
    // Initialize animation data if needed
    if not unit_data.animation_data then
        unit_data.animation_data = {
            current_animation = "idle",
            animation_time = 0,
            frame_index = 0,
            animation_speed = 1.0,
            pending_animations = {}
        }
    end
    
    local anim_data = unit_data.animation_data
    anim_data.animation_time = anim_data.animation_time + dt * anim_data.animation_speed
    
    // Update animation based on combat state
    if unit_data.state == "combat" then
        update_combat_state_animation(unit_id, unit_data, anim_data, dt)
    else
        // Return to idle animation
        if anim_data.current_animation ~= "idle" then
            start_animation(unit_id, "idle")
        end
    end
    
    // Process pending animations
    process_pending_animations(unit_id, anim_data)
    
    // Update visual representation
    update_animation_visuals(unit_id, renderable, anim_data)
end
-- }}}

-- {{{ local function update_combat_state_animation
local function update_combat_state_animation(unit_id, unit_data, anim_data, dt)
    local combat_state = unit_data.combat_state or "engaging"
    
    if combat_state == "attacking" then
        update_attack_animation(unit_id, unit_data, anim_data)
    elseif combat_state == "retreating" then
        update_retreat_animation(unit_id, anim_data)
    elseif combat_state == "strafing" then
        update_strafe_animation(unit_id, anim_data)
    elseif combat_state == "positioning" then
        update_positioning_animation(unit_id, anim_data)
    else
        // Default combat idle
        if anim_data.current_animation ~= "combat_idle" then
            start_animation(unit_id, "combat_idle")
        end
    end
end
-- }}}

-- {{{ local function update_attack_animation
local function update_attack_animation(unit_id, unit_data, anim_data)
    local attack_animation = get_attack_animation_for_unit(unit_data.unit_type)
    
    if anim_data.current_animation ~= attack_animation then
        start_animation(unit_id, attack_animation)
        
        // Schedule hit effect at appropriate time in animation
        local hit_timing = get_attack_hit_timing(attack_animation)
        schedule_animation_event(unit_id, "hit_effect", hit_timing)
    end
    
    // Check if attack animation is complete
    local animation_duration = get_animation_duration(attack_animation)
    if anim_data.animation_time >= animation_duration then
        // Return to combat idle
        start_animation(unit_id, "combat_idle")
    end
end
-- }}}

-- {{{ local function get_attack_animation_for_unit
local function get_attack_animation_for_unit(unit_type)
    if unit_type == "melee" then
        return "melee_attack"
    elseif unit_type == "ranged" then
        return "ranged_attack"
    else
        return "basic_attack"
    end
end
-- }}}

-- {{{ local function start_animation
local function start_animation(unit_id, animation_name)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data or not unit_data.animation_data then
        return
    end
    
    local anim_data = unit_data.animation_data
    anim_data.current_animation = animation_name
    anim_data.animation_time = 0
    anim_data.frame_index = 0
    
    // Set animation speed based on type
    anim_data.animation_speed = get_animation_speed(animation_name)
    
    Debug:log("Unit " .. unit_id .. " starting animation: " .. animation_name)
end
-- }}}

-- {{{ local function create_attack_effect
local function create_attack_effect(attacker_id, target_id, attack_type)
    local attacker_pos = EntityManager:get_component(attacker_id, "position")
    local target_pos = EntityManager:get_component(target_id, "position")
    
    if not attacker_pos or not target_pos then
        return
    end
    
    local attacker_position = Vector2:new(attacker_pos.x, attacker_pos.y)
    local target_position = Vector2:new(target_pos.x, target_pos.y)
    
    if attack_type == "melee" then
        create_melee_attack_effect(attacker_position, target_position)
    elseif attack_type == "ranged" then
        create_ranged_attack_effect(attacker_position, target_position)
    end
end
-- }}}

-- {{{ local function create_melee_attack_effect
local function create_melee_attack_effect(attacker_pos, target_pos)
    // Slash effect from attacker to target
    local slash_effect = {
        type = "melee_slash",
        start_position = attacker_pos,
        end_position = target_pos,
        duration = 0.3,
        start_time = love.timer.getTime(),
        color = Colors.WHITE,
        thickness = 3
    }
    EffectSystem:add_effect(slash_effect)
    
    // Impact flash at target
    local impact_effect = {
        type = "impact_flash",
        position = target_pos,
        duration = 0.15,
        start_time = love.timer.getTime() + 0.1,  // Slight delay
        max_radius = 15,
        color = Colors.YELLOW
    }
    EffectSystem:add_effect(impact_effect)
end
-- }}}

-- {{{ local function create_ranged_attack_effect
local function create_ranged_attack_effect(attacker_pos, target_pos)
    // Projectile effect
    local projectile_effect = {
        type = "projectile",
        start_position = attacker_pos,
        end_position = target_pos,
        duration = 0.5,
        start_time = love.timer.getTime(),
        color = Colors.WHITE,
        size = 3,
        trail_length = 8
    }
    EffectSystem:add_effect(projectile_effect)
    
    // Muzzle flash at attacker
    local muzzle_effect = {
        type = "muzzle_flash",
        position = attacker_pos,
        duration = 0.1,
        start_time = love.timer.getTime(),
        color = Colors.ORANGE,
        size = 8
    }
    EffectSystem:add_effect(muzzle_effect)
end
-- }}}

-- {{{ local function create_damage_feedback
local function create_damage_feedback(unit_id, damage_amount, damage_type)
    local position = EntityManager:get_component(unit_id, "position")
    
    if not position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    // Damage number
    local number_effect = {
        type = "damage_number",
        position = Vector2:new(unit_pos.x + math.random(-5, 5), unit_pos.y - 15),
        damage = damage_amount,
        duration = 1.5,
        start_time = love.timer.getTime(),
        velocity = Vector2:new(math.random(-10, 10), -25),
        color = get_damage_color(damage_type),
        font_size = math.min(16, 8 + damage_amount / 3)  // Larger numbers for more damage
    }
    EffectSystem:add_effect(number_effect)
    
    // Screen shake for significant damage
    if damage_amount > 20 then
        local shake_effect = {
            type = "screen_shake",
            intensity = math.min(8, damage_amount / 5),
            duration = 0.2,
            start_time = love.timer.getTime()
        }
        EffectSystem:add_effect(shake_effect)
    end
    
    // Unit hurt animation
    trigger_hurt_animation(unit_id, damage_type)
end
-- }}}

-- {{{ local function get_damage_color
local function get_damage_color(damage_type)
    if damage_type == "critical" then
        return Colors.ORANGE
    elseif damage_type == "fire" then
        return Colors.RED
    elseif damage_type == "poison" then
        return Colors.GREEN
    elseif damage_type == "magic" then
        return Colors.PURPLE
    else
        return Colors.WHITE  // Normal damage
    end
end
-- }}}

-- {{{ local function trigger_hurt_animation
local function trigger_hurt_animation(unit_id, damage_type)
    local renderable = EntityManager:get_component(unit_id, "renderable")
    
    if not renderable then
        return
    end
    
    // Flash effect
    local flash_effect = {
        type = "unit_flash",
        unit_id = unit_id,
        duration = 0.2,
        start_time = love.timer.getTime(),
        flash_color = Colors.RED,
        flash_intensity = 0.7
    }
    EffectSystem:add_effect(flash_effect)
    
    // Knockback effect for strong hits
    if damage_type == "critical" then
        create_knockback_effect(unit_id, 5)  // 5 unit knockback
    end
end
-- }}}

-- {{{ local function create_knockback_effect
local function create_knockback_effect(unit_id, knockback_distance)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position or not unit_data or not unit_data.combat_target then
        return
    end
    
    local target_pos = EntityManager:get_component(unit_data.combat_target, "position")
    if not target_pos then
        return
    end
    
    // Calculate knockback direction (away from attacker)
    local unit_pos = Vector2:new(position.x, position.y)
    local attacker_pos = Vector2:new(target_pos.x, target_pos.y)
    local knockback_direction = unit_pos:subtract(attacker_pos):normalize()
    
    // Apply knockback
    local knockback_effect = {
        type = "knockback",
        unit_id = unit_id,
        direction = knockback_direction,
        distance = knockback_distance,
        duration = 0.3,
        start_time = love.timer.getTime()
    }
    EffectSystem:add_effect(knockback_effect)
end
-- }}}

-- {{{ local function create_death_animation
local function create_death_animation(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    
    // Start death animation on unit
    start_animation(unit_id, "death")
    
    // Death explosion effect
    local explosion_effect = {
        type = "death_explosion",
        position = unit_pos,
        duration = 1.0,
        start_time = love.timer.getTime(),
        max_radius = 20,
        color = Colors.WHITE
    }
    EffectSystem:add_effect(explosion_effect)
    
    // Particle burst
    for i = 1, 6 do
        local angle = (i / 6) * 2 * math.pi
        local particle_velocity = Vector2:new(
            math.cos(angle) * 25,
            math.sin(angle) * 25
        )
        
        local particle_effect = {
            type = "death_particle",
            position = unit_pos,
            velocity = particle_velocity,
            duration = 0.8,
            start_time = love.timer.getTime(),
            size = 2,
            color = Colors.GRAY
        }
        EffectSystem:add_effect(particle_effect)
    end
    
    // Screen flash for dramatic effect
    if unit_data and unit_data.unit_type == "elite" then
        local screen_flash = {
            type = "screen_flash",
            color = Colors.WHITE,
            intensity = 0.3,
            duration = 0.2,
            start_time = love.timer.getTime()
        }
        EffectSystem:add_effect(screen_flash)
    end
end
-- }}}

-- {{{ local function update_animation_visuals
local function update_animation_visuals(unit_id, renderable, anim_data)
    if not renderable then
        return
    end
    
    // Update visual properties based on current animation
    local animation_name = anim_data.current_animation
    local animation_time = anim_data.animation_time
    
    if animation_name == "melee_attack" then
        // Scale up slightly during attack
        local scale_factor = 1 + 0.2 * math.sin(animation_time * 10)
        renderable.scale = math.max(1, scale_factor)
        
    elseif animation_name == "ranged_attack" then
        // Slight recoil effect
        local recoil = math.sin(animation_time * 8) * 2
        renderable.offset_x = recoil
        
    elseif animation_name == "death" then
        // Fade out over time
        renderable.alpha = math.max(0, 1 - (animation_time / 2))
        
    else
        // Reset to default values
        renderable.scale = 1
        renderable.offset_x = 0
        renderable.offset_y = 0
    end
end
-- }}}

-- {{{ local function get_animation_duration
local function get_animation_duration(animation_name)
    local durations = {
        idle = math.huge,  // Loops indefinitely
        combat_idle = math.huge,
        melee_attack = 0.6,
        ranged_attack = 0.4,
        death = 2.0,
        retreat = 0.3,
        strafe = 0.5
    }
    
    return durations[animation_name] or 1.0
end
-- }}}

-- {{{ local function get_animation_speed
local function get_animation_speed(animation_name)
    local speeds = {
        idle = 1.0,
        combat_idle = 1.2,  // Slightly faster for tension
        melee_attack = 1.5,
        ranged_attack = 1.8,
        death = 0.8,  // Slower for dramatic effect
        retreat = 2.0,  // Fast retreat
        strafe = 1.5
    }
    
    return speeds[animation_name] or 1.0
end
-- }}}
```

### Combat Animation Features
1. **Attack Animations**: Distinct animations for melee and ranged attacks
2. **Hit Effects**: Visual impact effects and damage feedback
3. **State Animations**: Different animations for combat states
4. **Death Sequences**: Comprehensive death animations and effects
5. **Visual Feedback**: Screen shake, flashes, and particle effects

### Animation Types
- **Idle/Combat Idle**: Default states with subtle animation
- **Attack Animations**: Weapon-specific attack sequences
- **Movement States**: Retreat, strafe, positioning animations
- **Damage Feedback**: Hurt animations and visual responses
- **Death Sequences**: Dramatic death effects

### Visual Feedback Elements
- Damage numbers with appropriate colors
- Screen shake for significant impacts
- Attack effects (slashes, projectiles)
- Status indicators through animation changes

### Tool Suggestions
- Use Write tool to create combat animation system
- Test with various combat scenarios and unit types
- Verify animation timing and visual clarity
- Check performance impact of effects system

### Acceptance Criteria
- [ ] Combat actions have clear visual animations
- [ ] Damage feedback is immediate and informative
- [ ] Attack effects distinguish between unit types
- [ ] Death animations provide satisfying closure
- [ ] Visual effects enhance without overwhelming gameplay