# Issue #037: Implement Defense Shield System (3 Shields)

## Current Behavior
Bases exist but lack the defense shield system that provides layered protection and strategic reset mechanics.

## Intended Behavior
Each base should have three defense shields that provide additional protection, with each shield destruction triggering a unit reset mechanic to prevent snowball situations.

## Implementation Details

### Defense Shield System (src/systems/defense_shield_system.lua)
```lua
-- {{{ local function create_defense_shields
local function create_defense_shields(base_id)
    local base_position = EntityManager:get_component(base_id, "position")
    local base_team = EntityManager:get_component(base_id, "team")
    local base_data = EntityManager:get_component(base_id, "base")
    
    if not base_position or not base_team or not base_data then
        return {}
    end
    
    local shield_ids = {}
    local base_pos = Vector2:new(base_position.x, base_position.y)
    
    // Create three shields around the base
    for i = 1, 3 do
        local shield_id = create_single_shield(base_id, base_pos, base_team.id, i)
        table.insert(shield_ids, shield_id)
    end
    
    // Register shields with base
    base_data.defense_shields = shield_ids
    
    Debug:log("Created " .. #shield_ids .. " defense shields for base " .. base_id)
    return shield_ids
end
-- }}}

-- {{{ local function create_single_shield
local function create_single_shield(base_id, base_position, team_id, shield_index)
    local shield_id = EntityManager:create_entity()
    
    // Calculate shield position around base
    local shield_position = calculate_shield_position(base_position, shield_index)
    
    EntityManager:add_component(shield_id, "position", {
        x = shield_position.x,
        y = shield_position.y,
        is_static = true,
        shield_index = shield_index
    })
    
    // Shield health - equivalent to ~5 average units
    EntityManager:add_component(shield_id, "health", {
        current = 100,
        maximum = 100,
        is_alive = true,
        last_damage_time = 0,
        shield_type = "defense"
    })
    
    EntityManager:add_component(shield_id, "team", {
        id = team_id,
        alliance = team_id == 1 and "player" or "enemy"
    })
    
    EntityManager:add_component(shield_id, "shield", {
        base_id = base_id,
        shield_index = shield_index,
        shield_state = "active",
        activation_time = love.timer.getTime(),
        protection_radius = 15,
        absorption_rate = 0.3,  // Absorbs 30% of incoming damage to base
        regeneration_rate = 2   // HP per second when not under attack
    })
    
    EntityManager:add_component(shield_id, "renderable", {
        shape = "shield_generator",
        color = team_id == 1 and Colors.LIGHT_BLUE or Colors.LIGHT_RED,
        size = 12,
        visible = true,
        render_layer = "shields",
        glow_intensity = 0.5,
        shield_energy_effect = true
    })
    
    return shield_id
end
-- }}}

-- {{{ local function calculate_shield_position
local function calculate_shield_position(base_position, shield_index)
    // Position shields in a triangle around the base
    local distance_from_base = 35
    local angle_offset = (shield_index - 1) * (2 * math.pi / 3)  // 120 degrees apart
    
    local shield_x = base_position.x + math.cos(angle_offset) * distance_from_base
    local shield_y = base_position.y + math.sin(angle_offset) * distance_from_base
    
    return Vector2:new(shield_x, shield_y)
end
-- }}}

-- {{{ local function update_defense_shields
local function update_defense_shields(dt)
    local all_shields = EntityManager:get_entities_with_component("shield")
    
    for _, shield_id in ipairs(all_shields) do
        update_shield_system(shield_id, dt)
    end
end
-- }}}

-- {{{ local function update_shield_system
local function update_shield_system(shield_id, dt)
    local shield_data = EntityManager:get_component(shield_id, "shield")
    local health = EntityManager:get_component(shield_id, "health")
    
    if not shield_data or not health then
        return
    end
    
    // Update shield regeneration
    update_shield_regeneration(shield_id, health, shield_data, dt)
    
    // Update shield visual effects
    update_shield_visual_effects(shield_id, health, shield_data)
    
    // Check for shield destruction
    if health.current <= 0 and health.is_alive then
        trigger_shield_destruction(shield_id)
    end
end
-- }}}

-- {{{ local function update_shield_regeneration
local function update_shield_regeneration(shield_id, health, shield_data, dt)
    if not health.is_alive or health.current >= health.maximum then
        return
    end
    
    // Regenerate shield when not under attack
    local time_since_damage = love.timer.getTime() - (health.last_damage_time or 0)
    
    if time_since_damage > 5.0 then  // 5 seconds without damage
        local regen_amount = shield_data.regeneration_rate * dt
        health.current = math.min(health.maximum, health.current + regen_amount)
        
        // Create regeneration effect
        if math.random() < 0.1 then  // 10% chance per frame
            create_shield_regeneration_effect(shield_id)
        end
    end
end
-- }}}

-- {{{ local function apply_damage_to_shield
local function apply_damage_to_shield(shield_id, damage, attacker_id)
    local health = EntityManager:get_component(shield_id, "health")
    local shield_data = EntityManager:get_component(shield_id, "shield")
    
    if not health or not health.is_alive or not shield_data then
        return 0
    end
    
    // Apply damage
    local damage_dealt = math.min(damage, health.current)
    health.current = health.current - damage_dealt
    health.last_damage_time = love.timer.getTime()
    health.last_attacker = attacker_id
    
    // Create shield damage effect
    create_shield_damage_effect(shield_id, damage_dealt)
    
    // Update shield state based on health
    update_shield_state_from_damage(shield_id, health, shield_data)
    
    Debug:log("Shield " .. shield_id .. " took " .. damage_dealt .. " damage")
    return damage_dealt
end
-- }}}

-- {{{ local function trigger_shield_destruction
local function trigger_shield_destruction(shield_id)
    local shield_data = EntityManager:get_component(shield_id, "shield")
    local health = EntityManager:get_component(shield_id, "health")
    local team = EntityManager:get_component(shield_id, "team")
    
    if not shield_data or not health or not team then
        return
    end
    
    health.is_alive = false
    health.destruction_time = love.timer.getTime()
    shield_data.shield_state = "destroyed"
    
    // Create shield destruction effect
    create_shield_destruction_effect(shield_id)
    
    // Trigger unit reset mechanic
    trigger_unit_reset_on_shield_destruction(team.id, shield_data.shield_index)
    
    // Check if this was the last shield
    check_for_last_shield_destruction(shield_data.base_id, shield_id)
    
    // Schedule shield removal
    schedule_shield_removal(shield_id, 3.0)
    
    Debug:log("Shield " .. shield_id .. " destroyed, triggering unit reset for team " .. team.id)
end
-- }}}

-- {{{ local function trigger_unit_reset_on_shield_destruction
local function trigger_unit_reset_on_shield_destruction(team_id, shield_index)
    // Remove all enemy units from the map
    local enemy_team_id = team_id == 1 and 2 or 1
    local enemy_units = get_all_units_of_team(enemy_team_id)
    
    Debug:log("Resetting " .. #enemy_units .. " enemy units due to shield " .. shield_index .. " destruction")
    
    for _, unit_id in ipairs(enemy_units) do
        // Create unit removal effect
        create_unit_reset_effect(unit_id)
        
        // Remove unit entity
        EntityManager:remove_entity(unit_id)
    end
    
    // Create global reset effect
    create_global_reset_effect(team_id, shield_index)
    
    // Notify players of the reset
    notify_shield_reset_event(team_id, shield_index)
end
-- }}}

-- {{{ local function check_for_last_shield_destruction
local function check_for_last_shield_destruction(base_id, destroyed_shield_id)
    local base_data = EntityManager:get_component(base_id, "base")
    
    if not base_data or not base_data.defense_shields then
        return
    end
    
    // Count remaining active shields
    local active_shields = 0
    for _, shield_id in ipairs(base_data.defense_shields) do
        if shield_id ~= destroyed_shield_id then
            local shield_health = EntityManager:get_component(shield_id, "health")
            if shield_health and shield_health.is_alive then
                active_shields = active_shields + 1
            end
        end
    end
    
    if active_shields == 0 then
        // All shields destroyed - base is now vulnerable
        notify_base_vulnerability(base_id)
        create_base_vulnerability_effect(base_id)
    end
end
-- }}}

-- {{{ local function intercept_base_damage
local function intercept_base_damage(base_id, incoming_damage, attacker_id)
    local base_data = EntityManager:get_component(base_id, "base")
    
    if not base_data or not base_data.defense_shields then
        return incoming_damage  // No shields, full damage to base
    end
    
    // Find active shields that can absorb damage
    local active_shields = get_active_shields_for_base(base_id)
    
    if #active_shields == 0 then
        return incoming_damage  // No active shields
    end
    
    // Calculate damage absorption
    local total_absorption = 0
    for _, shield_id in ipairs(active_shields) do
        local shield_data = EntityManager:get_component(shield_id, "shield")
        if shield_data then
            total_absorption = total_absorption + shield_data.absorption_rate
        end
    end
    
    // Cap absorption at 80%
    total_absorption = math.min(0.8, total_absorption)
    
    // Distribute absorbed damage among shields
    local absorbed_damage = incoming_damage * total_absorption
    local damage_per_shield = absorbed_damage / #active_shields
    
    for _, shield_id in ipairs(active_shields) do
        apply_damage_to_shield(shield_id, damage_per_shield, attacker_id)
    end
    
    // Create shield absorption effect
    create_shield_absorption_effect(base_id, absorbed_damage)
    
    // Return remaining damage that goes to base
    local remaining_damage = incoming_damage - absorbed_damage
    Debug:log("Shields absorbed " .. absorbed_damage .. " damage, " .. remaining_damage .. " reaching base")
    
    return remaining_damage
end
-- }}}

-- {{{ local function get_active_shields_for_base
local function get_active_shields_for_base(base_id)
    local base_data = EntityManager:get_component(base_id, "base")
    local active_shields = {}
    
    if base_data and base_data.defense_shields then
        for _, shield_id in ipairs(base_data.defense_shields) do
            local shield_health = EntityManager:get_component(shield_id, "health")
            if shield_health and shield_health.is_alive then
                table.insert(active_shields, shield_id)
            end
        end
    end
    
    return active_shields
end
-- }}}

-- {{{ local function create_shield_destruction_effect
local function create_shield_destruction_effect(shield_id)
    local position = EntityManager:get_component(shield_id, "position")
    
    if not position then
        return
    end
    
    local shield_pos = Vector2:new(position.x, position.y)
    
    // Shield collapse effect
    local collapse_effect = {
        type = "shield_collapse",
        position = shield_pos,
        duration = 2.0,
        start_time = love.timer.getTime(),
        max_radius = 25,
        color = Colors.CYAN,
        intensity = 0.8
    }
    EffectSystem:add_effect(collapse_effect)
    
    // Energy discharge
    for i = 1, 8 do
        local angle = (i / 8) * 2 * math.pi
        local discharge_velocity = Vector2:new(
            math.cos(angle) * 30,
            math.sin(angle) * 30
        )
        
        local discharge_effect = {
            type = "shield_energy_discharge",
            position = shield_pos,
            velocity = discharge_velocity,
            duration = 1.5,
            start_time = love.timer.getTime(),
            color = Colors.ELECTRIC_BLUE
        }
        EffectSystem:add_effect(discharge_effect)
    end
    
    // Screen shake
    local shake_effect = {
        type = "screen_shake",
        intensity = 8,
        duration = 1.0,
        start_time = love.timer.getTime()
    }
    EffectSystem:add_effect(shake_effect)
end
-- }}}

-- {{{ local function create_global_reset_effect
local function create_global_reset_effect(defending_team_id, shield_index)
    // Create map-wide visual effect to indicate unit reset
    local reset_effect = {
        type = "global_unit_reset",
        defending_team = defending_team_id,
        shield_index = shield_index,
        duration = 3.0,
        start_time = love.timer.getTime(),
        color = defending_team_id == 1 and Colors.BLUE or Colors.RED,
        intensity = 0.6
    }
    EffectSystem:add_effect(reset_effect)
    
    // Notification text effect
    local notification_text = "Shield " .. shield_index .. " Destroyed - Enemy Units Reset!"
    local text_effect = {
        type = "notification_text",
        text = notification_text,
        duration = 4.0,
        start_time = love.timer.getTime(),
        position = Vector2:new(400, 100),  // Screen position
        color = Colors.YELLOW,
        font_size = 24
    }
    EffectSystem:add_effect(text_effect)
end
-- }}}

-- {{{ local function create_unit_reset_effect
local function create_unit_reset_effect(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local unit_pos = Vector2:new(position.x, position.y)
        
        // Unit vanish effect
        local vanish_effect = {
            type = "unit_reset_vanish",
            position = unit_pos,
            duration = 0.8,
            start_time = love.timer.getTime(),
            color = Colors.WHITE,
            fade_out = true
        }
        EffectSystem:add_effect(vanish_effect)
    end
end
-- }}}

-- {{{ local function create_shield_absorption_effect
local function create_shield_absorption_effect(base_id, absorbed_damage)
    local base_position = EntityManager:get_component(base_id, "position")
    
    if base_position then
        local base_pos = Vector2:new(base_position.x, base_position.y)
        
        // Shield protection effect
        local protection_effect = {
            type = "shield_absorption",
            position = base_pos,
            absorbed_damage = absorbed_damage,
            duration = 0.5,
            start_time = love.timer.getTime(),
            color = Colors.CYAN,
            radius = 30
        }
        EffectSystem:add_effect(protection_effect)
    end
end
-- }}}

-- {{{ local function notify_shield_reset_event
local function notify_shield_reset_event(defending_team_id, shield_index)
    // Notify UI and game systems about the reset
    GameEventSystem:broadcast_event("shield_destroyed", {
        defending_team = defending_team_id,
        shield_index = shield_index,
        timestamp = love.timer.getTime()
    })
    
    // Update game statistics
    StatsSystem:record_shield_destruction(defending_team_id, shield_index)
end
-- }}}

-- {{{ local function get_shield_count_for_base
local function get_shield_count_for_base(base_id)
    local active_shields = get_active_shields_for_base(base_id)
    return #active_shields
end
-- }}}
```

### Defense Shield Features
1. **Three-Shield System**: Each base protected by three shield generators
2. **Damage Absorption**: Shields absorb percentage of incoming base damage
3. **Unit Reset Mechanic**: Shield destruction removes all enemy units
4. **Regeneration**: Shields slowly repair when not under attack
5. **Strategic Positioning**: Shields positioned around base in protective formation

### Shield Mechanics
- **Health Pool**: Each shield has ~5 average units worth of health
- **Absorption Rate**: 30% damage reduction per active shield
- **Regeneration**: 2 HP/second when not taking damage
- **Reset Trigger**: Each shield destruction clears enemy units

### Anti-Snowball Design
- Unit reset prevents overwhelming advantages
- Gives defending team fresh opportunities
- Maintains competitive balance throughout game
- Forces attackers to commit to sustained pressure

### Tool Suggestions
- Use Write tool to create defense shield system
- Test shield destruction and unit reset mechanics
- Verify damage absorption calculations
- Check visual effects and notifications

### Acceptance Criteria
- [ ] Three shields protect each base with substantial health
- [ ] Shields absorb percentage of incoming base damage
- [ ] Shield destruction triggers enemy unit reset
- [ ] Shields regenerate health when not under attack
- [ ] Visual effects clearly communicate shield status