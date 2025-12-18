# Issue #040: Implement Unit Reset When Shields are Destroyed

## Current Behavior
Shield destruction exists but needs comprehensive unit reset mechanics that properly clear enemy forces and provide strategic resets.

## Intended Behavior
When a shield is destroyed, all enemy units should be removed from the map with appropriate effects and notifications, providing the defending team with a fresh tactical opportunity.

## Implementation Details

### Unit Reset System (src/systems/unit_reset_system.lua)
```lua
-- {{{ local function initialize_unit_reset_system
local function initialize_unit_reset_system()
    unit_reset_data = {
        reset_events = {},
        reset_in_progress = false,
        reset_start_time = 0,
        reset_duration = 3.0,  // 3 seconds for reset process
        last_reset_time = 0,
        reset_statistics = {
            total_resets = 0,
            units_reset_per_event = {},
            team_resets = {[1] = 0, [2] = 0}
        }
    }
end
-- }}}

-- {{{ local function trigger_unit_reset
local function trigger_unit_reset(defending_team_id, trigger_source, additional_data)
    if not unit_reset_data then
        initialize_unit_reset_system()
    end
    
    // Prevent multiple simultaneous resets
    if unit_reset_data.reset_in_progress then
        Debug:log("Unit reset already in progress, ignoring new trigger")
        return false
    end
    
    local enemy_team_id = defending_team_id == 1 and 2 or 1
    local enemy_units = get_all_units_of_team(enemy_team_id)
    
    if #enemy_units == 0 then
        Debug:log("No enemy units to reset")
        return false
    end
    
    // Create reset event
    local reset_event = {
        defending_team = defending_team_id,
        enemy_team = enemy_team_id,
        trigger_source = trigger_source,
        trigger_data = additional_data,
        start_time = love.timer.getTime(),
        units_to_reset = enemy_units,
        reset_phases = create_reset_phases(enemy_units),
        current_phase = 1,
        total_units = #enemy_units
    }
    
    // Start reset process
    unit_reset_data.reset_in_progress = true
    unit_reset_data.reset_start_time = reset_event.start_time
    table.insert(unit_reset_data.reset_events, reset_event)
    
    // Create initial reset effects
    create_reset_announcement_effect(reset_event)
    
    Debug:log("Unit reset triggered for " .. #enemy_units .. " units of team " .. enemy_team_id)
    return true
end
-- }}}

-- {{{ local function create_reset_phases
local function create_reset_phases(enemy_units)
    // Organize units into phases for staged removal
    local phases = {
        {
            name = "warning",
            duration = 1.0,
            units = {},
            effect_type = "warning"
        },
        {
            name = "collection",
            duration = 1.5,
            units = enemy_units,
            effect_type = "collection"
        },
        {
            name = "removal",
            duration = 0.5,
            units = enemy_units,
            effect_type = "removal"
        }
    }
    
    return phases
end
-- }}}

-- {{{ local function update_unit_reset_system
local function update_unit_reset_system(dt)
    if not unit_reset_data then
        initialize_unit_reset_system()
    end
    
    if not unit_reset_data.reset_in_progress then
        return
    end
    
    local current_time = love.timer.getTime()
    local active_reset = unit_reset_data.reset_events[#unit_reset_data.reset_events]
    
    if not active_reset then
        unit_reset_data.reset_in_progress = false
        return
    end
    
    // Update current reset phase
    update_reset_phase(active_reset, current_time, dt)
    
    // Check if reset is complete
    if current_time - active_reset.start_time >= unit_reset_data.reset_duration then
        complete_unit_reset(active_reset)
    end
end
-- }}}

-- {{{ local function update_reset_phase
local function update_reset_phase(reset_event, current_time, dt)
    local elapsed_time = current_time - reset_event.start_time
    local current_phase = reset_event.current_phase
    
    if current_phase > #reset_event.reset_phases then
        return
    end
    
    local phase = reset_event.reset_phases[current_phase]
    local phase_start_time = calculate_phase_start_time(reset_event, current_phase)
    
    // Check if phase should start
    if elapsed_time >= phase_start_time and not phase.started then
        start_reset_phase(reset_event, phase, current_phase)
        phase.started = true
    end
    
    // Update phase effects
    if phase.started then
        update_phase_effects(reset_event, phase, elapsed_time - phase_start_time)
    end
    
    // Check if phase is complete
    if elapsed_time >= phase_start_time + phase.duration and not phase.completed then
        complete_reset_phase(reset_event, phase, current_phase)
        phase.completed = true
        reset_event.current_phase = current_phase + 1
    end
end
-- }}}

-- {{{ local function calculate_phase_start_time
local function calculate_phase_start_time(reset_event, phase_index)
    local start_time = 0
    
    for i = 1, phase_index - 1 do
        local prev_phase = reset_event.reset_phases[i]
        start_time = start_time + prev_phase.duration
    end
    
    return start_time
end
-- }}}

-- {{{ local function start_reset_phase
local function start_reset_phase(reset_event, phase, phase_index)
    Debug:log("Starting reset phase " .. phase_index .. ": " .. phase.name)
    
    if phase.name == "warning" then
        create_reset_warning_effects(reset_event)
        
    elseif phase.name == "collection" then
        create_unit_collection_effects(reset_event, phase.units)
        disable_unit_actions(phase.units)
        
    elseif phase.name == "removal" then
        execute_unit_removal(reset_event, phase.units)
    end
end
-- }}}

-- {{{ local function create_reset_warning_effects
local function create_reset_warning_effects(reset_event)
    // Global warning effect
    local warning_effect = {
        type = "global_unit_reset_warning",
        duration = 1.0,
        start_time = love.timer.getTime(),
        defending_team = reset_event.defending_team,
        total_units = reset_event.total_units,
        color = Colors.YELLOW,
        intensity = 0.8
    }
    EffectSystem:add_effect(warning_effect)
    
    // Screen flash
    local flash_effect = {
        type = "reset_warning_flash",
        color = Colors.ORANGE,
        intensity = 0.4,
        duration = 0.3,
        start_time = love.timer.getTime()
    }
    EffectSystem:add_effect(flash_effect)
    
    // Notification text
    local notification_text = "SHIELD DESTROYED - ENEMY UNITS RECALLED"
    local text_effect = {
        type = "reset_notification",
        text = notification_text,
        duration = 2.0,
        start_time = love.timer.getTime(),
        position = Vector2:new(400, 50),  // Screen center top
        color = Colors.CYAN,
        font_size = 20
    }
    EffectSystem:add_effect(text_effect)
end
-- }}}

-- {{{ local function create_unit_collection_effects
local function create_unit_collection_effects(reset_event, units)
    for _, unit_id in ipairs(units) do
        local position = EntityManager:get_component(unit_id, "position")
        
        if position then
            // Unit collection beam effect
            local beam_effect = {
                type = "unit_collection_beam",
                unit_id = unit_id,
                start_position = Vector2:new(position.x, position.y),
                duration = 1.5,
                start_time = love.timer.getTime(),
                color = Colors.CYAN,
                beam_width = 3
            }
            EffectSystem:add_effect(beam_effect)
            
            // Unit glow effect
            local glow_effect = {
                type = "unit_reset_glow",
                unit_id = unit_id,
                duration = 1.5,
                start_time = love.timer.getTime(),
                color = Colors.WHITE,
                intensity = 0.8,
                pulsing = true
            }
            EffectSystem:add_effect(glow_effect)
        end
    end
end
-- }}}

-- {{{ local function disable_unit_actions
local function disable_unit_actions(units)
    for _, unit_id in ipairs(units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        local moveable = EntityManager:get_component(unit_id, "moveable")
        
        if unit_data then
            // Mark unit as being reset
            unit_data.reset_in_progress = true
            unit_data.state = "being_reset"
            
            // Clear combat targets
            unit_data.combat_target = nil
        end
        
        if moveable then
            // Stop all movement
            moveable.velocity_x = 0
            moveable.velocity_y = 0
            moveable.is_moving = false
        end
    end
end
-- }}}

-- {{{ local function execute_unit_removal
local function execute_unit_removal(reset_event, units)
    local removed_count = 0
    
    for _, unit_id in ipairs(units) do
        // Create individual removal effect
        create_unit_removal_effect(unit_id)
        
        // Remove unit entity
        EntityManager:remove_entity(unit_id)
        removed_count = removed_count + 1
    end
    
    // Update statistics
    update_reset_statistics(reset_event, removed_count)
    
    Debug:log("Removed " .. removed_count .. " units during reset")
end
-- }}}

-- {{{ local function create_unit_removal_effect
local function create_unit_removal_effect(unit_id)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local unit_pos = Vector2:new(position.x, position.y)
        
        // Teleport-out effect
        local teleport_effect = {
            type = "unit_teleport_out",
            position = unit_pos,
            duration = 0.5,
            start_time = love.timer.getTime(),
            color = Colors.WHITE,
            max_radius = 15,
            shrinking = true
        }
        EffectSystem:add_effect(teleport_effect)
        
        // Sparkle particles
        for i = 1, 6 do
            local angle = (i / 6) * 2 * math.pi
            local particle_velocity = Vector2:new(
                math.cos(angle) * 20,
                math.sin(angle) * 20
            )
            
            local sparkle_effect = {
                type = "reset_sparkle",
                position = unit_pos,
                velocity = particle_velocity,
                duration = 0.8,
                start_time = love.timer.getTime(),
                color = Colors.CYAN,
                size = 2
            }
            EffectSystem:add_effect(sparkle_effect)
        end
    end
end
-- }}}

-- {{{ local function complete_reset_phase
local function complete_reset_phase(reset_event, phase, phase_index)
    Debug:log("Completed reset phase " .. phase_index .. ": " .. phase.name)
    
    // Phase-specific completion effects
    if phase.name == "collection" then
        create_collection_complete_effect(reset_event)
    elseif phase.name == "removal" then
        create_removal_complete_effect(reset_event)
    end
end
-- }}}

-- {{{ local function complete_unit_reset
local function complete_unit_reset(reset_event)
    // Mark reset as complete
    unit_reset_data.reset_in_progress = false
    unit_reset_data.last_reset_time = love.timer.getTime()
    
    // Create completion effects
    create_reset_completion_effects(reset_event)
    
    // Notify game systems
    notify_reset_completion(reset_event)
    
    // Update statistics
    unit_reset_data.reset_statistics.total_resets = unit_reset_data.reset_statistics.total_resets + 1
    unit_reset_data.reset_statistics.team_resets[reset_event.defending_team] = 
        unit_reset_data.reset_statistics.team_resets[reset_event.defending_team] + 1
    
    Debug:log("Unit reset completed for team " .. reset_event.defending_team)
end
-- }}}

-- {{{ local function create_reset_completion_effects
local function create_reset_completion_effects(reset_event)
    // Global completion effect
    local completion_effect = {
        type = "reset_completion",
        duration = 2.0,
        start_time = love.timer.getTime(),
        defending_team = reset_event.defending_team,
        units_reset = reset_event.total_units,
        color = reset_event.defending_team == 1 and Colors.BLUE or Colors.RED,
        intensity = 0.6
    }
    EffectSystem:add_effect(completion_effect)
    
    // Success notification
    local success_text = "ENEMY FORCES RECALLED - " .. reset_event.total_units .. " UNITS"
    local success_effect = {
        type = "reset_success_notification",
        text = success_text,
        duration = 3.0,
        start_time = love.timer.getTime(),
        position = Vector2:new(400, 150),
        color = Colors.GREEN,
        font_size = 18
    }
    EffectSystem:add_effect(success_effect)
end
-- }}}

-- {{{ local function notify_reset_completion
local function notify_reset_completion(reset_event)
    // Broadcast event to all game systems
    GameEventSystem:broadcast_event("unit_reset_completed", {
        defending_team = reset_event.defending_team,
        enemy_team = reset_event.enemy_team,
        units_reset = reset_event.total_units,
        trigger_source = reset_event.trigger_source,
        timestamp = love.timer.getTime()
    })
    
    // Notify UI systems
    UISystem:show_reset_notification(reset_event.defending_team, reset_event.total_units)
    
    // Update team morale/resources if applicable
    TeamSystem:apply_reset_benefits(reset_event.defending_team)
end
-- }}}

-- {{{ local function create_reset_announcement_effect
local function create_reset_announcement_effect(reset_event)
    // Screen-wide announcement
    local announcement_effect = {
        type = "reset_announcement",
        duration = unit_reset_data.reset_duration,
        start_time = love.timer.getTime(),
        defending_team = reset_event.defending_team,
        trigger_source = reset_event.trigger_source,
        color = Colors.YELLOW,
        intensity = 0.5
    }
    EffectSystem:add_effect(announcement_effect)
end
-- }}}

-- {{{ local function update_reset_statistics
local function update_reset_statistics(reset_event, removed_count)
    table.insert(unit_reset_data.reset_statistics.units_reset_per_event, {
        timestamp = love.timer.getTime(),
        defending_team = reset_event.defending_team,
        units_count = removed_count,
        trigger_source = reset_event.trigger_source
    })
end
-- }}}

-- {{{ local function get_reset_statistics
local function get_reset_statistics()
    if not unit_reset_data then
        return {
            total_resets = 0,
            team_resets = {[1] = 0, [2] = 0},
            average_units_per_reset = 0
        }
    end
    
    local total_units = 0
    local event_count = #unit_reset_data.reset_statistics.units_reset_per_event
    
    for _, event in ipairs(unit_reset_data.reset_statistics.units_reset_per_event) do
        total_units = total_units + event.units_count
    end
    
    return {
        total_resets = unit_reset_data.reset_statistics.total_resets,
        team_resets = unit_reset_data.reset_statistics.team_resets,
        average_units_per_reset = event_count > 0 and total_units / event_count or 0,
        last_reset_time = unit_reset_data.last_reset_time
    }
end
-- }}}

-- {{{ local function is_reset_in_progress
local function is_reset_in_progress()
    return unit_reset_data and unit_reset_data.reset_in_progress
end
-- }}}
```

### Unit Reset Features
1. **Phased Removal**: Multi-stage reset process with warning, collection, and removal
2. **Visual Effects**: Comprehensive effects for each reset phase
3. **Complete Statistics**: Tracking of reset events and effectiveness
4. **System Integration**: Proper notification and coordination with other systems
5. **Preventing Exploitation**: Cooldowns and safeguards against abuse

### Reset Phases
1. **Warning Phase**: 1-second warning with global effects
2. **Collection Phase**: 1.5-second unit disable and collection effects
3. **Removal Phase**: 0.5-second actual unit removal with teleport effects

### Anti-Snowball Mechanics
- Removes all enemy units from map
- Gives defending team fresh tactical opportunity
- Prevents overwhelming advantages from accumulating
- Maintains competitive balance through game

### Tool Suggestions
- Use Write tool to create unit reset system
- Test reset triggering and phase progression
- Verify visual effects and timing
- Check statistics tracking and system integration

### Acceptance Criteria
- [ ] Shield destruction triggers enemy unit reset
- [ ] Reset process includes warning, collection, and removal phases
- [ ] Visual effects clearly communicate reset progression
- [ ] All enemy units are properly removed from map
- [ ] Statistics and notifications track reset events