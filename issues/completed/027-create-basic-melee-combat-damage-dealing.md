# Issue #027: Create Basic Melee Combat (Damage Dealing)

## Current Behavior
Units can detect and engage enemies but lack the actual combat mechanics to deal damage and resolve fights.

## Intended Behavior
Melee units should engage in close combat, dealing damage over time to enemy units based on their attack capabilities and positioning.

## Implementation Details

### Melee Combat System (src/systems/melee_combat_system.lua)
```lua
-- {{{ local function update_melee_combat
local function update_melee_combat(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    
    if not unit_data or not position or unit_data.state ~= "combat" then
        return
    end
    
    -- Only process melee units
    if unit_data.unit_type ~= "melee" then
        return
    end
    
    local target_id = unit_data.combat_target
    if not target_id then
        return
    end
    
    -- Validate target is still valid
    if not is_valid_combat_target(target_id) then
        disengage_from_combat(unit_id)
        return
    end
    
    -- Update combat positioning
    update_melee_positioning(unit_id, target_id, dt)
    
    -- Process combat attacks
    process_melee_attacks(unit_id, target_id, dt)
    
    -- Update combat state
    update_combat_state(unit_id, dt)
end
-- }}}

-- {{{ local function update_melee_positioning
local function update_melee_positioning(unit_id, target_id, dt)
    local position = EntityManager:get_component(unit_id, "position")
    local moveable = EntityManager:get_component(unit_id, "moveable")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not position or not moveable or not target_position then
        return
    end
    
    local unit_pos = Vector2:new(position.x, position.y)
    local target_pos = Vector2:new(target_position.x, target_position.y)
    
    local distance_to_target = unit_pos:distance_to(target_pos)
    local optimal_distance = 12  -- Melee engagement distance
    
    if distance_to_target > optimal_distance + 2 then
        -- Move closer to target
        local direction = target_pos:subtract(unit_pos):normalize()
        local movement_speed = 20  -- Slower speed during combat positioning
        
        moveable.velocity_x = direction.x * movement_speed
        moveable.velocity_y = direction.y * movement_speed
        moveable.is_moving = true
        
        -- Update position
        position.x = position.x + moveable.velocity_x * dt
        position.y = position.y + moveable.velocity_y * dt
        
        -- Ensure position stays within bounds
        local sub_path = LaneSystem:get_sub_path(position.sub_path_id)
        if sub_path then
            local corrected_pos = CollisionSystem:correct_unit_position(
                {position = Vector2:new(position.x, position.y)}, sub_path
            )
            position.x = corrected_pos.x
            position.y = corrected_pos.y
        end
        
    elseif distance_to_target < optimal_distance - 2 then
        -- Move away to maintain optimal distance
        local direction = unit_pos:subtract(target_pos):normalize()
        local movement_speed = 10
        
        moveable.velocity_x = direction.x * movement_speed
        moveable.velocity_y = direction.y * movement_speed
        moveable.is_moving = true
        
        position.x = position.x + moveable.velocity_x * dt
        position.y = position.y + moveable.velocity_y * dt
        
    else
        -- In optimal range, stop moving
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
end
-- }}}

-- {{{ local function process_melee_attacks
local function process_melee_attacks(unit_id, target_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local position = EntityManager:get_component(unit_id, "position")
    local target_position = EntityManager:get_component(target_id, "position")
    
    if not unit_data or not position or not target_position then
        return
    end
    
    -- Initialize combat data if needed
    if not unit_data.combat_data then
        unit_data.combat_data = {
            last_attack_time = 0,
            attack_cooldown = 1.0,  -- 1 second between attacks
            base_damage = 15,
            attack_range = 15
        }
    end
    
    local combat_data = unit_data.combat_data
    local current_time = love.timer.getTime()
    
    -- Check if unit can attack
    if current_time - combat_data.last_attack_time >= combat_data.attack_cooldown then
        local unit_pos = Vector2:new(position.x, position.y)
        local target_pos = Vector2:new(target_position.x, target_position.y)
        local distance = unit_pos:distance_to(target_pos)
        
        if distance <= combat_data.attack_range then
            perform_melee_attack(unit_id, target_id, combat_data)
            combat_data.last_attack_time = current_time
        end
    end
    
    -- Update attack cooldown visualization
    update_attack_cooldown_display(unit_id, combat_data, current_time)
end
-- }}}

-- {{{ local function perform_melee_attack
local function perform_melee_attack(attacker_id, target_id, combat_data)
    local target_health = EntityManager:get_component(target_id, "health")
    
    if not target_health or not target_health.is_alive then
        return
    end
    
    -- Calculate damage
    local base_damage = combat_data.base_damage
    local damage_variance = 0.2  -- ±20% damage variation
    local random_factor = 1 + (math.random() - 0.5) * 2 * damage_variance
    local final_damage = math.floor(base_damage * random_factor)
    
    -- Apply damage
    local damage_dealt = apply_damage_to_unit(target_id, final_damage, attacker_id)
    
    -- Create combat effects
    create_melee_attack_effect(attacker_id, target_id, damage_dealt)
    
    -- Log combat action
    Debug:log("Unit " .. attacker_id .. " attacks " .. target_id .. " for " .. damage_dealt .. " damage")
    
    -- Check if target was killed
    if not target_health.is_alive then
        handle_target_death(attacker_id, target_id)
    end
end
-- }}}

-- {{{ local function apply_damage_to_unit
local function apply_damage_to_unit(target_id, damage, attacker_id)
    local health = EntityManager:get_component(target_id, "health")
    
    if not health or not health.is_alive then
        return 0
    end
    
    -- Calculate actual damage dealt
    local damage_dealt = math.min(damage, health.current)
    
    -- Apply damage
    health.current = health.current - damage_dealt
    health.last_damage_time = love.timer.getTime()
    health.last_attacker = attacker_id
    
    -- Check if unit dies
    if health.current <= 0 then
        health.current = 0
        health.is_alive = false
        handle_unit_death(target_id, attacker_id)
    end
    
    -- Create damage number effect
    create_damage_number_effect(target_id, damage_dealt)
    
    return damage_dealt
end
-- }}}

-- {{{ local function handle_unit_death
local function handle_unit_death(dead_unit_id, killer_id)
    local unit_data = EntityManager:get_component(dead_unit_id, "unit")
    local position = EntityManager:get_component(dead_unit_id, "position")
    
    if unit_data then
        unit_data.state = "dead"
        unit_data.death_time = love.timer.getTime()
        
        -- Clear any combat engagement
        if unit_data.combat_target then
            CombatSystem:unregister_combat_engagement(dead_unit_id, unit_data.combat_target)
            unit_data.combat_target = nil
        end
    end
    
    -- Update rendering to show death state
    local renderable = EntityManager:get_component(dead_unit_id, "renderable")
    if renderable then
        renderable.color = Colors.DARK_GRAY
        renderable.alpha = 0.5
    end
    
    -- Stop movement
    local moveable = EntityManager:get_component(dead_unit_id, "moveable")
    if moveable then
        moveable.velocity_x = 0
        moveable.velocity_y = 0
        moveable.is_moving = false
    end
    
    -- Create death effect
    create_death_effect(dead_unit_id, position)
    
    -- Schedule removal after delay
    schedule_unit_removal(dead_unit_id, 3.0)  -- Remove after 3 seconds
    
    Debug:log("Unit " .. dead_unit_id .. " was killed by " .. (killer_id or "unknown"))
end
-- }}}

-- {{{ local function handle_target_death
local function handle_target_death(attacker_id, dead_target_id)
    local unit_data = EntityManager:get_component(attacker_id, "unit")
    
    if unit_data and unit_data.combat_target == dead_target_id then
        -- Target is dead, look for new target or resume movement
        unit_data.combat_target = nil
        
        -- Try to find another enemy in range
        local detection_range = get_unit_detection_range(unit_data)
        local enemy_units = find_enemy_units_in_range(attacker_id, detection_range)
        
        if #enemy_units > 0 then
            -- Engage new target
            local new_target = select_combat_target(attacker_id, enemy_units)
            if new_target then
                initiate_combat_engagement(attacker_id, new_target)
            else
                -- No suitable target, resume movement
                unit_data.state = "moving"
            end
        else
            -- No enemies in range, resume movement
            unit_data.state = "moving"
            local moveable = EntityManager:get_component(attacker_id, "moveable")
            if moveable then
                moveable.is_moving = true
            end
        end
    end
end
-- }}}

-- {{{ local function create_melee_attack_effect
local function create_melee_attack_effect(attacker_id, target_id, damage)
    local attacker_pos = EntityManager:get_component(attacker_id, "position")
    local target_pos = EntityManager:get_component(target_id, "position")
    
    if attacker_pos and target_pos then
        local effect = {
            type = "melee_attack",
            attacker_position = Vector2:new(attacker_pos.x, attacker_pos.y),
            target_position = Vector2:new(target_pos.x, target_pos.y),
            damage = damage,
            duration = 0.2,
            start_time = love.timer.getTime()
        }
        
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function create_damage_number_effect
local function create_damage_number_effect(target_id, damage)
    local position = EntityManager:get_component(target_id, "position")
    
    if position then
        local effect = {
            type = "damage_number",
            position = Vector2:new(position.x, position.y - 10),  -- Slightly above unit
            damage = damage,
            duration = 1.5,
            start_time = love.timer.getTime(),
            velocity = Vector2:new(0, -20)  -- Float upward
        }
        
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function create_death_effect
local function create_death_effect(unit_id, position)
    if position then
        local effect = {
            type = "unit_death",
            position = Vector2:new(position.x, position.y),
            duration = 1.0,
            start_time = love.timer.getTime(),
            expansion_rate = 15  -- How fast the effect expands
        }
        
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function update_combat_state
local function update_combat_state(unit_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data or not unit_data.combat_data then
        return
    end
    
    -- Update any combat state timers or conditions
    local current_time = love.timer.getTime()
    local combat_duration = current_time - (unit_data.combat_engagement_time or current_time)
    
    -- Add combat fatigue or other state changes based on duration
    if combat_duration > 10.0 then  -- 10 seconds of combat
        -- Slight damage reduction due to fatigue
        unit_data.combat_data.fatigue_factor = 0.9
    end
end
-- }}}

-- {{{ local function schedule_unit_removal
local function schedule_unit_removal(unit_id, delay)
    local removal_time = love.timer.getTime() + delay
    
    -- Add to removal queue
    UnitManager:schedule_removal(unit_id, removal_time)
end
-- }}}
```

### Melee Combat Features
1. **Damage Calculation**: Base damage with random variation
2. **Attack Timing**: Cooldown-based attack system
3. **Combat Positioning**: Automatic positioning for optimal engagement
4. **Death Handling**: Complete unit death and cleanup process
5. **Visual Effects**: Attack effects, damage numbers, and death animations

### Combat Mechanics
- Attack cooldown prevents instant kills
- Damage variation adds combat unpredictability
- Positioning system maintains proper engagement distance
- Target switching when current target dies

### Integration Points
- Works with detection system for target acquisition
- Uses health system for damage application
- Coordinates with movement system for positioning
- Integrates with effect system for visual feedback

### Tool Suggestions
- Use Write tool to create melee combat system
- Test with different unit configurations and health values
- Verify combat positioning and damage dealing
- Check visual effects and combat feedback

### Acceptance Criteria
- [ ] Melee units deal damage to enemies in close range
- [ ] Attack cooldown system prevents instant combat resolution
- [ ] Combat positioning maintains proper engagement distance
- [ ] Unit death is handled correctly with effects
- [ ] Target switching works when enemies are defeated