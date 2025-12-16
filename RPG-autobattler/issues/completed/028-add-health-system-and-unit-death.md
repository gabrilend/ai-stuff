# Issue #028: Add Health System and Unit Death

## Current Behavior
Units can take damage but need a comprehensive health management system with proper death handling and lifecycle management.

## Intended Behavior
Units should have robust health tracking, death state management, and proper cleanup when defeated, with visual and gameplay feedback.

## Implementation Details

### Health Management System (src/systems/health_system.lua)
```lua
-- {{{ local function update_health_system
local function update_health_system(dt)
    local all_units = EntityManager:get_entities_with_component("health")
    
    for _, unit_id in ipairs(all_units) do
        update_unit_health(unit_id, dt)
    end
    
    -- Process scheduled unit removals
    process_unit_removals()
end
-- }}}

-- {{{ local function update_unit_health
local function update_unit_health(unit_id, dt)
    local health = EntityManager:get_component(unit_id, "health")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not health or not unit_data then
        return
    end
    
    -- Update health regeneration
    update_health_regeneration(unit_id, health, dt)
    
    -- Update damage over time effects
    update_damage_over_time(unit_id, health, dt)
    
    -- Check for death conditions
    check_death_conditions(unit_id, health, unit_data)
    
    -- Update health display
    update_health_display(unit_id, health)
end
-- }}}

-- {{{ local function update_health_regeneration
local function update_health_regeneration(unit_id, health, dt)
    if not health.is_alive or health.current >= health.maximum then
        return
    end
    
    -- Base regeneration rate (very slow)
    local base_regen_rate = 0.5  -- HP per second
    local time_since_damage = love.timer.getTime() - (health.last_damage_time or 0)
    
    -- Only regenerate if no damage taken recently
    if time_since_damage > 5.0 then  -- 5 seconds without damage
        local regen_amount = base_regen_rate * dt
        health.current = math.min(health.maximum, health.current + regen_amount)
        
        -- Create regeneration effect
        if math.random() < 0.1 then  -- 10% chance per frame
            create_regeneration_effect(unit_id)
        end
    end
end
-- }}}

-- {{{ local function update_damage_over_time
local function update_damage_over_time(unit_id, health, dt)
    if not health.damage_over_time_effects then
        return
    end
    
    local current_time = love.timer.getTime()
    local effects_to_remove = {}
    
    for i, effect in ipairs(health.damage_over_time_effects) do
        if current_time >= effect.next_tick_time then
            -- Apply damage
            local damage_dealt = apply_damage_to_unit(unit_id, effect.damage_per_tick, effect.source_id)
            
            -- Create DOT effect visual
            create_dot_damage_effect(unit_id, damage_dealt, effect.type)
            
            -- Update next tick time
            effect.next_tick_time = current_time + effect.tick_interval
            effect.remaining_duration = effect.remaining_duration - effect.tick_interval
            
            -- Check if effect has expired
            if effect.remaining_duration <= 0 then
                table.insert(effects_to_remove, i)
            end
        end
    end
    
    -- Remove expired effects
    for i = #effects_to_remove, 1, -1 do
        table.remove(health.damage_over_time_effects, effects_to_remove[i])
    end
end
-- }}}

-- {{{ local function check_death_conditions
local function check_death_conditions(unit_id, health, unit_data)
    if health.current <= 0 and health.is_alive then
        trigger_unit_death(unit_id, health, unit_data)
    end
end
-- }}}

-- {{{ local function trigger_unit_death
local function trigger_unit_death(unit_id, health, unit_data)
    health.is_alive = false
    health.death_time = love.timer.getTime()
    unit_data.state = "dead"
    
    -- Stop all movement
    local moveable = EntityManager:get_component(unit_id, "moveable")
    if moveable then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
    
    -- Update visual appearance
    update_death_appearance(unit_id)
    
    -- Handle combat disengagement
    handle_death_combat_cleanup(unit_id, unit_data)
    
    -- Create death effects
    create_comprehensive_death_effect(unit_id)
    
    -- Notify other systems
    notify_unit_death(unit_id, health.last_attacker)
    
    -- Schedule removal
    schedule_corpse_removal(unit_id, 5.0)  -- Remove after 5 seconds
    
    Debug:log("Unit " .. unit_id .. " has died")
end
-- }}}

-- {{{ local function update_death_appearance
local function update_death_appearance(unit_id)
    local renderable = EntityManager:get_component(unit_id, "renderable")
    
    if renderable then
        -- Change appearance to indicate death
        renderable.color = Colors.DARK_GRAY
        renderable.alpha = 0.6
        renderable.render_layer = "corpses"  -- Render behind living units
        
        -- Add death marker shape
        renderable.death_marker = true
    end
end
-- }}}

-- {{{ local function handle_death_combat_cleanup
local function handle_death_combat_cleanup(dead_unit_id, unit_data)
    -- Remove from any active combat
    if unit_data.combat_target then
        CombatSystem:unregister_combat_engagement(dead_unit_id, unit_data.combat_target)
        unit_data.combat_target = nil
    end
    
    -- Notify any units targeting this unit
    local all_units = EntityManager:get_entities_with_component("unit")
    for _, other_unit_id in ipairs(all_units) do
        local other_unit_data = EntityManager:get_component(other_unit_id, "unit")
        if other_unit_data and other_unit_data.combat_target == dead_unit_id then
            -- Clear target and look for new one
            other_unit_data.combat_target = nil
            
            -- Try to find new target
            local detection_range = get_unit_detection_range(other_unit_data)
            local enemy_units = find_enemy_units_in_range(other_unit_id, detection_range)
            
            if #enemy_units > 0 then
                local new_target = select_combat_target(other_unit_id, enemy_units)
                if new_target then
                    initiate_combat_engagement(other_unit_id, new_target)
                else
                    other_unit_data.state = "moving"
                end
            else
                other_unit_data.state = "moving"
            end
        end
    end
end
-- }}}

-- {{{ local function create_comprehensive_death_effect
local function create_comprehensive_death_effect(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
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
        max_radius = 25,
        unit_type = unit_data and unit_data.unit_type or "unknown"
    }
    EffectSystem:add_effect(explosion_effect)
    
    -- Particle effects
    for i = 1, 8 do
        local angle = (i / 8) * 2 * math.pi
        local particle_velocity = Vector2:new(
            math.cos(angle) * 30,
            math.sin(angle) * 30
        )
        
        local particle_effect = {
            type = "death_particle",
            position = unit_pos,
            velocity = particle_velocity,
            duration = 0.8,
            start_time = love.timer.getTime(),
            size = 3
        }
        EffectSystem:add_effect(particle_effect)
    end
    
    -- Screen shake for dramatic deaths
    if unit_data and unit_data.unit_type == "elite" then
        local shake_effect = {
            type = "screen_shake",
            intensity = 5,
            duration = 0.3,
            start_time = love.timer.getTime()
        }
        EffectSystem:add_effect(shake_effect)
    end
end
-- }}}

-- {{{ local function notify_unit_death
local function notify_unit_death(dead_unit_id, killer_id)
    -- Update statistics
    StatsSystem:record_unit_death(dead_unit_id, killer_id)
    
    -- Check for special death conditions
    local unit_data = EntityManager:get_component(dead_unit_id, "unit")
    if unit_data then
        -- Award experience or resources to killer
        if killer_id then
            award_kill_rewards(killer_id, unit_data)
        end
        
        -- Check for formation disruption
        if unit_data.formation_id then
            FormationSystem:handle_unit_death(unit_data.formation_id, dead_unit_id)
        end
        
        -- Trigger any death-based abilities or effects
        trigger_death_abilities(dead_unit_id, killer_id)
    end
end
-- }}}

-- {{{ local function award_kill_rewards
local function award_kill_rewards(killer_id, dead_unit_data)
    local killer_unit_data = EntityManager:get_component(killer_id, "unit")
    
    if killer_unit_data then
        -- Add kill count
        if not killer_unit_data.combat_stats then
            killer_unit_data.combat_stats = {
                kills = 0,
                damage_dealt = 0,
                experience = 0
            }
        end
        
        killer_unit_data.combat_stats.kills = killer_unit_data.combat_stats.kills + 1
        
        -- Award small experience boost
        killer_unit_data.combat_stats.experience = killer_unit_data.combat_stats.experience + 10
        
        -- Create reward effect
        create_kill_reward_effect(killer_id)
    end
end
-- }}}

-- {{{ local function schedule_corpse_removal
local function schedule_corpse_removal(unit_id, delay)
    local removal_time = love.timer.getTime() + delay
    
    if not scheduled_removals then
        scheduled_removals = {}
    end
    
    table.insert(scheduled_removals, {
        unit_id = unit_id,
        removal_time = removal_time
    })
end
-- }}}

-- {{{ local function process_unit_removals
local function process_unit_removals()
    if not scheduled_removals then
        return
    end
    
    local current_time = love.timer.getTime()
    local removals_to_process = {}
    
    for i, removal in ipairs(scheduled_removals) do
        if current_time >= removal.removal_time then
            table.insert(removals_to_process, i)
            
            -- Create fade-out effect before removal
            create_corpse_fade_effect(removal.unit_id)
            
            -- Remove unit entity
            EntityManager:remove_entity(removal.unit_id)
            
            Debug:log("Removed corpse: " .. removal.unit_id)
        end
    end
    
    -- Remove processed removals (in reverse order to maintain indices)
    for i = #removals_to_process, 1, -1 do
        table.remove(scheduled_removals, removals_to_process[i])
    end
end
-- }}}

-- {{{ local function create_regeneration_effect
local function create_regeneration_effect(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local effect = {
            type = "regeneration",
            position = Vector2:new(position.x, position.y - 5),
            duration = 0.5,
            start_time = love.timer.getTime(),
            color = Colors.GREEN
        }
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function create_dot_damage_effect
local function create_dot_damage_effect(unit_id, damage, dot_type)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local color = Colors.RED
        if dot_type == "poison" then
            color = Colors.GREEN
        elseif dot_type == "fire" then
            color = Colors.ORANGE
        end
        
        local effect = {
            type = "dot_damage",
            position = Vector2:new(position.x + math.random(-5, 5), position.y - 10),
            damage = damage,
            duration = 1.0,
            start_time = love.timer.getTime(),
            color = color,
            velocity = Vector2:new(0, -15)
        }
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function add_damage_over_time_effect
local function add_damage_over_time_effect(unit_id, damage_per_tick, tick_interval, duration, source_id, effect_type)
    local health = EntityManager:get_component(unit_id, "health")
    
    if not health or not health.is_alive then
        return false
    end
    
    if not health.damage_over_time_effects then
        health.damage_over_time_effects = {}
    end
    
    local dot_effect = {
        damage_per_tick = damage_per_tick,
        tick_interval = tick_interval,
        remaining_duration = duration,
        next_tick_time = love.timer.getTime() + tick_interval,
        source_id = source_id,
        type = effect_type or "generic"
    }
    
    table.insert(health.damage_over_time_effects, dot_effect)
    
    Debug:log("Applied DOT effect to unit " .. unit_id .. ": " .. damage_per_tick .. " damage every " .. tick_interval .. "s")
    return true
end
-- }}}
```

### Health System Features
1. **Comprehensive Health Tracking**: Current/max health with damage history
2. **Death State Management**: Proper death handling and cleanup
3. **Health Regeneration**: Slow healing when out of combat
4. **Damage Over Time**: Support for DOT effects like poison/fire
5. **Visual Feedback**: Health bars, damage numbers, death effects

### Death Handling
- Immediate state transition to dead
- Combat cleanup and target switching
- Visual appearance changes
- Corpse removal after delay
- Reward system for killers

### Integration Points
- Works with combat system for damage application
- Coordinates with movement system for death stops
- Interfaces with effect system for visual feedback
- Integrates with stats system for tracking

### Tool Suggestions
- Use Write tool to create comprehensive health system
- Test with various damage scenarios and DOT effects
- Verify death handling and cleanup processes
- Check health regeneration and visual feedback

### Acceptance Criteria
- [ ] Units track health accurately with damage/healing
- [ ] Death transitions work smoothly with proper cleanup
- [ ] Health regeneration occurs when out of combat
- [ ] DOT effects apply damage over time correctly
- [ ] Visual feedback clearly shows health status and death