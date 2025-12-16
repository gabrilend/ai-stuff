# Issue #039: Create Shield Destruction Mechanics

## Current Behavior
Shield destruction exists but needs comprehensive mechanics for timing, sequencing, and strategic implications.

## Intended Behavior
Shield destruction should follow specific mechanics that create strategic depth, including destruction order, timing effects, and tactical opportunities.

## Implementation Details

### Shield Destruction Mechanics (src/systems/shield_destruction_mechanics.lua)
```lua
-- {{{ local function initialize_shield_destruction_system
local function initialize_shield_destruction_system()
    shield_destruction_data = {
        destruction_queue = {},
        shield_vulnerability_windows = {},
        destruction_sequence_active = false,
        last_destruction_time = 0,
        destruction_cooldown = 30.0  // 30 seconds between potential destructions
    }
end
-- }}}

-- {{{ local function update_shield_destruction_mechanics
local function update_shield_destruction_mechanics(dt)
    if not shield_destruction_data then
        initialize_shield_destruction_system()
    end
    
    // Update vulnerability windows
    update_shield_vulnerability_windows(dt)
    
    // Process destruction queue
    process_shield_destruction_queue(dt)
    
    // Update shield weakening effects
    update_shield_weakening_effects(dt)
    
    // Check for destruction opportunities
    check_destruction_opportunities()
end
-- }}}

-- {{{ local function update_shield_vulnerability_windows
local function update_shield_vulnerability_windows(dt)
    local current_time = love.timer.getTime()
    
    for shield_id, window_data in pairs(shield_destruction_data.shield_vulnerability_windows) do
        // Update window timer
        window_data.remaining_time = window_data.remaining_time - dt
        
        if window_data.remaining_time <= 0 then
            // Vulnerability window expired
            end_shield_vulnerability_window(shield_id)
        else
            // Apply vulnerability effects
            apply_vulnerability_effects(shield_id, window_data)
        end
    end
end
-- }}}

-- {{{ local function trigger_shield_vulnerability_window
local function trigger_shield_vulnerability_window(shield_id, trigger_type)
    local shield_data = EntityManager:get_component(shield_id, "shield")
    local shield_health = EntityManager:get_component(shield_id, "health")
    
    if not shield_data or not shield_health or not shield_health.is_alive then
        return
    end
    
    // Calculate vulnerability parameters based on trigger type
    local vulnerability_data = calculate_vulnerability_parameters(trigger_type, shield_health)
    
    shield_destruction_data.shield_vulnerability_windows[shield_id] = {
        trigger_type = trigger_type,
        start_time = love.timer.getTime(),
        duration = vulnerability_data.duration,
        remaining_time = vulnerability_data.duration,
        damage_multiplier = vulnerability_data.damage_multiplier,
        visual_intensity = vulnerability_data.visual_intensity,
        warning_given = false
    }
    
    // Create vulnerability start effect
    create_vulnerability_start_effect(shield_id, vulnerability_data)
    
    Debug:log("Shield " .. shield_id .. " vulnerability window started: " .. trigger_type)
end
-- }}}

-- {{{ local function calculate_vulnerability_parameters
local function calculate_vulnerability_parameters(trigger_type, shield_health)
    local base_duration = 10.0  // 10 seconds base vulnerability
    local base_multiplier = 1.5  // 50% extra damage
    
    local params = {
        duration = base_duration,
        damage_multiplier = base_multiplier,
        visual_intensity = 0.5
    }
    
    if trigger_type == "concentrated_fire" then
        // Multiple units attacking same shield
        params.damage_multiplier = 1.8  // 80% extra damage
        params.visual_intensity = 0.7
        
    elseif trigger_type == "shield_overload" then
        // Shield has taken sustained damage
        params.duration = 15.0
        params.damage_multiplier = 2.0  // 100% extra damage
        params.visual_intensity = 0.9
        
    elseif trigger_type == "critical_health" then
        // Shield below 25% health
        params.duration = 8.0
        params.damage_multiplier = 1.6  // 60% extra damage
        params.visual_intensity = 0.8
        
    elseif trigger_type == "synchronized_assault" then
        // Multiple shields under attack simultaneously
        params.duration = 12.0
        params.damage_multiplier = 1.7  // 70% extra damage
        params.visual_intensity = 0.6
    end
    
    return params
end
-- }}}

-- {{{ local function apply_vulnerability_effects
local function apply_vulnerability_effects(shield_id, window_data)
    local shield_data = EntityManager:get_component(shield_id, "shield")
    
    if shield_data then
        // Store original values if not already stored
        if not shield_data.original_values then
            shield_data.original_values = {
                absorption_rate = shield_data.absorption_rate,
                regeneration_rate = shield_data.regeneration_rate
            }
        end
        
        // Apply vulnerability effects
        shield_data.damage_multiplier = window_data.damage_multiplier
        shield_data.absorption_rate = shield_data.original_values.absorption_rate * 0.5  // Reduced absorption
        shield_data.regeneration_rate = 0  // No regeneration during vulnerability
        
        // Visual effects
        update_vulnerability_visual_effects(shield_id, window_data)
        
        // Warning at halfway point
        if window_data.remaining_time <= window_data.duration * 0.5 and not window_data.warning_given then
            create_vulnerability_warning_effect(shield_id)
            window_data.warning_given = true
        end
    end
end
-- }}}

-- {{{ local function end_shield_vulnerability_window
local function end_shield_vulnerability_window(shield_id)
    local shield_data = EntityManager:get_component(shield_id, "shield")
    
    if shield_data then
        // Restore original values
        if shield_data.original_values then
            shield_data.absorption_rate = shield_data.original_values.absorption_rate
            shield_data.regeneration_rate = shield_data.original_values.regeneration_rate
            shield_data.original_values = nil
        end
        
        // Clear vulnerability effects
        shield_data.damage_multiplier = 1.0
        
        // Create vulnerability end effect
        create_vulnerability_end_effect(shield_id)
    end
    
    // Remove from tracking
    shield_destruction_data.shield_vulnerability_windows[shield_id] = nil
    
    Debug:log("Shield " .. shield_id .. " vulnerability window ended")
end
-- }}}

-- {{{ local function check_destruction_opportunities
local function check_destruction_opportunities()
    local current_time = love.timer.getTime()
    
    // Cooldown check
    if current_time - shield_destruction_data.last_destruction_time < shield_destruction_data.destruction_cooldown then
        return
    end
    
    // Check all active shields for destruction triggers
    local all_shields = EntityManager:get_entities_with_component("shield")
    
    for _, shield_id in ipairs(all_shields) do
        check_shield_for_destruction_triggers(shield_id)
    end
end
-- }}}

-- {{{ local function check_shield_for_destruction_triggers
local function check_shield_for_destruction_triggers(shield_id)
    local shield_health = EntityManager:get_component(shield_id, "health")
    local shield_data = EntityManager:get_component(shield_id, "shield")
    
    if not shield_health or not shield_data or not shield_health.is_alive then
        return
    end
    
    local health_ratio = shield_health.current / shield_health.maximum
    
    // Trigger: Critical health
    if health_ratio <= 0.25 and not is_shield_vulnerable(shield_id) then
        trigger_shield_vulnerability_window(shield_id, "critical_health")
        return
    end
    
    // Trigger: Sustained damage
    local damage_intensity = calculate_recent_damage_intensity(shield_id)
    if damage_intensity > 0.8 and not is_shield_vulnerable(shield_id) then
        trigger_shield_vulnerability_window(shield_id, "shield_overload")
        return
    end
    
    // Trigger: Concentrated fire
    local attacking_units = count_units_attacking_shield(shield_id)
    if attacking_units >= 3 and not is_shield_vulnerable(shield_id) then
        trigger_shield_vulnerability_window(shield_id, "concentrated_fire")
        return
    end
end
-- }}}

-- {{{ local function calculate_recent_damage_intensity
local function calculate_recent_damage_intensity(shield_id)
    local shield_health = EntityManager:get_component(shield_id, "health")
    
    if not shield_health or not shield_health.damage_history then
        return 0
    end
    
    local current_time = love.timer.getTime()
    local time_window = 5.0  // Last 5 seconds
    local total_damage = 0
    
    // Sum damage in recent time window
    for _, damage_event in ipairs(shield_health.damage_history) do
        if current_time - damage_event.timestamp <= time_window then
            total_damage = total_damage + damage_event.amount
        end
    end
    
    // Calculate intensity (damage per second relative to max health)
    local damage_per_second = total_damage / time_window
    local max_health = shield_health.maximum
    
    return damage_per_second / max_health
end
-- }}}

-- {{{ local function count_units_attacking_shield
local function count_units_attacking_shield(shield_id)
    local shield_position = EntityManager:get_component(shield_id, "position")
    local shield_team = EntityManager:get_component(shield_id, "team")
    
    if not shield_position or not shield_team then
        return 0
    end
    
    local shield_pos = Vector2:new(shield_position.x, shield_position.y)
    local attack_range = 40  // Range to consider units as attacking
    
    local nearby_enemies = find_enemy_units_in_range_from_position(shield_pos, attack_range, shield_team.id)
    local attacking_count = 0
    
    for _, enemy in ipairs(nearby_enemies) do
        // Check if enemy is actually targeting this shield
        local enemy_unit_data = EntityManager:get_component(enemy.unit_id, "unit")
        if enemy_unit_data and enemy_unit_data.combat_target == shield_id then
            attacking_count = attacking_count + 1
        end
    end
    
    return attacking_count
end
-- }}}

-- {{{ local function queue_shield_destruction
local function queue_shield_destruction(shield_id, destruction_delay)
    local destruction_time = love.timer.getTime() + destruction_delay
    
    table.insert(shield_destruction_data.destruction_queue, {
        shield_id = shield_id,
        destruction_time = destruction_time,
        warning_given = false
    })
    
    // Mark destruction sequence as active
    shield_destruction_data.destruction_sequence_active = true
    
    Debug:log("Shield " .. shield_id .. " queued for destruction in " .. destruction_delay .. " seconds")
end
-- }}}

-- {{{ local function process_shield_destruction_queue
local function process_shield_destruction_queue(dt)
    if #shield_destruction_data.destruction_queue == 0 then
        return
    end
    
    local current_time = love.timer.getTime()
    local destructions_to_process = {}
    
    for i, destruction_data in ipairs(shield_destruction_data.destruction_queue) do
        // Check for warning timing
        local time_until_destruction = destruction_data.destruction_time - current_time
        
        if time_until_destruction <= 3.0 and not destruction_data.warning_given then
            create_destruction_warning_effect(destruction_data.shield_id, time_until_destruction)
            destruction_data.warning_given = true
        end
        
        // Check for destruction timing
        if current_time >= destruction_data.destruction_time then
            table.insert(destructions_to_process, i)
        end
    end
    
    // Process destructions (in reverse order to maintain indices)
    for i = #destructions_to_process, 1, -1 do
        local index = destructions_to_process[i]
        local destruction_data = shield_destruction_data.destruction_queue[index]
        
        execute_delayed_shield_destruction(destruction_data.shield_id)
        table.remove(shield_destruction_data.destruction_queue, index)
    end
    
    // Update destruction sequence state
    if #shield_destruction_data.destruction_queue == 0 then
        shield_destruction_data.destruction_sequence_active = false
    end
end
-- }}}

-- {{{ local function execute_delayed_shield_destruction
local function execute_delayed_shield_destruction(shield_id)
    local shield_health = EntityManager:get_component(shield_id, "health")
    
    if shield_health and shield_health.is_alive then
        // Force shield destruction
        shield_health.current = 0
        trigger_shield_destruction(shield_id)
        
        // Update timing for cooldown
        shield_destruction_data.last_destruction_time = love.timer.getTime()
    end
end
-- }}}

-- {{{ local function create_vulnerability_start_effect
local function create_vulnerability_start_effect(shield_id, vulnerability_data)
    local position = EntityManager:get_component(shield_id, "position")
    
    if position then
        local shield_pos = Vector2:new(position.x, position.y)
        
        // Vulnerability aura effect
        local aura_effect = {
            type = "shield_vulnerability_aura",
            position = shield_pos,
            duration = vulnerability_data.duration,
            start_time = love.timer.getTime(),
            intensity = vulnerability_data.visual_intensity,
            color = Colors.ORANGE,
            pulsing = true
        }
        EffectSystem:add_effect(aura_effect)
        
        // Warning indicator
        local warning_effect = {
            type = "vulnerability_warning",
            position = shield_pos:add(Vector2:new(0, -20)),
            duration = 2.0,
            start_time = love.timer.getTime(),
            text = "VULNERABLE",
            color = Colors.RED
        }
        EffectSystem:add_effect(warning_effect)
    end
end
-- }}}

-- {{{ local function create_destruction_warning_effect
local function create_destruction_warning_effect(shield_id, time_remaining)
    local position = EntityManager:get_component(shield_id, "position")
    
    if position then
        local shield_pos = Vector2:new(position.x, position.y)
        
        // Critical warning effect
        local warning_effect = {
            type = "shield_destruction_warning",
            position = shield_pos,
            duration = time_remaining,
            start_time = love.timer.getTime(),
            intensity = 1.0,
            color = Colors.RED,
            flashing = true,
            countdown = math.ceil(time_remaining)
        }
        EffectSystem:add_effect(warning_effect)
        
        // Screen flash warning
        local flash_effect = {
            type = "warning_screen_flash",
            color = Colors.RED,
            intensity = 0.3,
            duration = 0.2,
            start_time = love.timer.getTime()
        }
        EffectSystem:add_effect(flash_effect)
    end
end
-- }}}

-- {{{ local function is_shield_vulnerable
local function is_shield_vulnerable(shield_id)
    return shield_destruction_data.shield_vulnerability_windows[shield_id] ~= nil
end
-- }}}

-- {{{ local function get_shield_vulnerability_status
local function get_shield_vulnerability_status(shield_id)
    local window_data = shield_destruction_data.shield_vulnerability_windows[shield_id]
    
    if not window_data then
        return {
            vulnerable = false,
            time_remaining = 0,
            damage_multiplier = 1.0
        }
    end
    
    return {
        vulnerable = true,
        time_remaining = window_data.remaining_time,
        damage_multiplier = window_data.damage_multiplier,
        trigger_type = window_data.trigger_type
    }
end
-- }}}
```

### Shield Destruction Features
1. **Vulnerability Windows**: Temporary periods of increased shield weakness
2. **Destruction Triggers**: Specific conditions that activate vulnerabilities
3. **Strategic Timing**: Cooldowns and windows create tactical decisions
4. **Visual Warning System**: Clear indicators of vulnerability and danger
5. **Delayed Destruction**: Queued destruction with warning periods

### Destruction Triggers
- **Critical Health**: Shield below 25% health becomes vulnerable
- **Concentrated Fire**: Multiple units attacking triggers weakness
- **Shield Overload**: Sustained heavy damage creates vulnerability
- **Synchronized Assault**: Multiple shields under attack simultaneously

### Vulnerability Effects
- Increased damage taken (50-100% more)
- Reduced damage absorption
- No shield regeneration during vulnerability
- Clear visual indicators and warnings

### Tool Suggestions
- Use Write tool to create shield destruction mechanics
- Test various destruction trigger scenarios
- Verify vulnerability timing and effects
- Check warning systems and visual feedback

### Acceptance Criteria
- [ ] Shields become vulnerable under specific trigger conditions
- [ ] Vulnerability windows have clear timing and effects
- [ ] Visual warnings provide adequate notice of danger
- [ ] Destruction mechanics create strategic depth
- [ ] System prevents excessive shield destruction frequency