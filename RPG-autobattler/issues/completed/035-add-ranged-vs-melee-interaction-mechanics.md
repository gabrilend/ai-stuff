# Issue #035: Add Ranged vs Melee Interaction Mechanics

## Current Behavior
Ranged and melee units interact using basic combat systems without specialized mechanics that reflect their different combat roles and tactical advantages.

## Intended Behavior
Ranged and melee units should have distinct interaction mechanics that create meaningful tactical differences, with ranged units having advantages at distance and melee units having advantages at close range.

## Implementation Details

### Ranged vs Melee Interaction System (src/systems/ranged_melee_interaction_system.lua)
```lua
-- {{{ local function update_ranged_melee_interactions
local function update_ranged_melee_interactions(dt)
    local all_combat_units = get_units_in_combat()
    
    for _, unit_id in ipairs(all_combat_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        
        if unit_data and unit_data.combat_target then
            update_unit_interaction_mechanics(unit_id, unit_data.combat_target, dt)
        end
    end
end
-- }}}

-- {{{ local function update_unit_interaction_mechanics
local function update_unit_interaction_mechanics(unit_id, target_id, dt)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    local target_data = EntityManager:get_component(target_id, "unit")
    
    if not unit_data or not target_data then
        return
    end
    
    local unit_type = unit_data.unit_type
    local target_type = target_data.unit_type
    
    // Apply interaction mechanics based on unit type combination
    if unit_type == "ranged" and target_type == "melee" then
        update_ranged_vs_melee_mechanics(unit_id, target_id, dt)
    elseif unit_type == "melee" and target_type == "ranged" then
        update_melee_vs_ranged_mechanics(unit_id, target_id, dt)
    elseif unit_type == "ranged" and target_type == "ranged" then
        update_ranged_vs_ranged_mechanics(unit_id, target_id, dt)
    elseif unit_type == "melee" and target_type == "melee" then
        update_melee_vs_melee_mechanics(unit_id, target_id, dt)
    end
end
-- }}}

-- {{{ local function update_ranged_vs_melee_mechanics
local function update_ranged_vs_melee_mechanics(ranged_unit_id, melee_unit_id, dt)
    local ranged_pos = EntityManager:get_component(ranged_unit_id, "position")
    local melee_pos = EntityManager:get_component(melee_unit_id, "position")
    local ranged_data = EntityManager:get_component(ranged_unit_id, "unit")
    
    if not ranged_pos or not melee_pos or not ranged_data then
        return
    end
    
    local distance = Vector2:new(ranged_pos.x, ranged_pos.y):distance_to(
        Vector2:new(melee_pos.x, melee_pos.y)
    )
    
    // Initialize interaction data if needed
    if not ranged_data.interaction_data then
        ranged_data.interaction_data = {
            distance_advantage_time = 0,
            last_successful_hit = 0,
            kiting_effectiveness = 1.0,
            pressure_level = 0
        }
    end
    
    local interaction_data = ranged_data.interaction_data
    
    // Calculate distance advantage
    local optimal_range = 30
    local danger_range = 15
    
    if distance > optimal_range then
        // In optimal range - accumulate advantage
        interaction_data.distance_advantage_time = interaction_data.distance_advantage_time + dt
        interaction_data.pressure_level = math.max(0, interaction_data.pressure_level - dt * 0.5)
        
        // Apply range advantage bonuses
        apply_range_advantage_bonuses(ranged_unit_id, interaction_data)
        
    elseif distance < danger_range then
        // In danger - apply pressure penalties
        interaction_data.pressure_level = math.min(3.0, interaction_data.pressure_level + dt * 2.0)
        interaction_data.distance_advantage_time = 0
        
        // Apply close combat penalties
        apply_close_combat_penalties(ranged_unit_id, interaction_data)
        
    else
        // In neutral range
        interaction_data.pressure_level = math.max(0, interaction_data.pressure_level - dt * 0.2)
    end
    
    // Update kiting effectiveness
    update_kiting_effectiveness(ranged_unit_id, melee_unit_id, interaction_data)
end
-- }}}

-- {{{ local function update_melee_vs_ranged_mechanics
local function update_melee_vs_ranged_mechanics(melee_unit_id, ranged_unit_id, dt)
    local melee_pos = EntityManager:get_component(melee_unit_id, "position")
    local ranged_pos = EntityManager:get_component(ranged_unit_id, "position")
    local melee_data = EntityManager:get_component(melee_unit_id, "unit")
    
    if not melee_pos or not ranged_pos or not melee_data then
        return
    end
    
    local distance = Vector2:new(melee_pos.x, melee_pos.y):distance_to(
        Vector2:new(ranged_pos.x, ranged_pos.y)
    )
    
    // Initialize interaction data if needed
    if not melee_data.interaction_data then
        melee_data.interaction_data = {
            closing_momentum = 0,
            time_under_fire = 0,
            charge_effectiveness = 1.0,
            closing_bonus_damage = 0
        }
    end
    
    local interaction_data = melee_data.interaction_data
    
    // Track time under ranged fire
    interaction_data.time_under_fire = interaction_data.time_under_fire + dt
    
    // Calculate closing mechanics
    local closing_distance = 20
    local engagement_distance = 12
    
    if distance > closing_distance then
        // Far from target - build momentum
        update_closing_momentum(melee_unit_id, ranged_unit_id, interaction_data, dt)
        
    elseif distance > engagement_distance then
        // Closing in - apply momentum benefits
        apply_closing_benefits(melee_unit_id, interaction_data)
        
    else
        // In melee range - apply close combat advantages
        apply_melee_engagement_advantages(melee_unit_id, ranged_unit_id, interaction_data)
    end
    
    // Apply survival bonuses for time under fire
    apply_under_fire_bonuses(melee_unit_id, interaction_data)
end
-- }}}

-- {{{ local function apply_range_advantage_bonuses
local function apply_range_advantage_bonuses(ranged_unit_id, interaction_data)
    local advantage_time = interaction_data.distance_advantage_time
    
    if advantage_time > 2.0 then
        // Accuracy bonus for sustained ranging
        local accuracy_bonus = math.min(0.3, advantage_time * 0.05)  // Up to 30% bonus
        apply_temporary_accuracy_modifier(ranged_unit_id, 1 + accuracy_bonus)
        
        // Damage bonus for steady aim
        if advantage_time > 5.0 then
            local damage_bonus = math.min(0.2, (advantage_time - 5.0) * 0.02)  // Up to 20% bonus
            apply_temporary_damage_modifier(ranged_unit_id, 1 + damage_bonus)
        end
    end
end
-- }}}

-- {{{ local function apply_close_combat_penalties
local function apply_close_combat_penalties(ranged_unit_id, interaction_data)
    local pressure = interaction_data.pressure_level
    
    // Accuracy penalty under pressure
    local accuracy_penalty = pressure * 0.15  // Up to 45% penalty at max pressure
    apply_temporary_accuracy_modifier(ranged_unit_id, 1 - accuracy_penalty)
    
    // Attack speed penalty
    local speed_penalty = pressure * 0.1  // Up to 30% slower
    apply_temporary_attack_speed_modifier(ranged_unit_id, 1 - speed_penalty)
    
    // Chance to be disrupted
    if pressure > 2.0 and math.random() < 0.1 then  // 10% chance per frame at high pressure
        trigger_combat_disruption(ranged_unit_id, "melee_pressure")
    end
end
-- }}}

-- {{{ local function update_closing_momentum
local function update_closing_momentum(melee_unit_id, ranged_unit_id, interaction_data, dt)
    local melee_moveable = EntityManager:get_component(melee_unit_id, "moveable")
    
    if not melee_moveable then
        return
    end
    
    // Build momentum while moving toward ranged target
    if melee_moveable.is_moving then
        local velocity = Vector2:new(melee_moveable.velocity_x, melee_moveable.velocity_y)
        local speed = velocity:length()
        
        if speed > 10 then  // Only if moving with purpose
            interaction_data.closing_momentum = math.min(3.0, interaction_data.closing_momentum + dt)
        end
    else
        // Lose momentum when not moving
        interaction_data.closing_momentum = math.max(0, interaction_data.closing_momentum - dt * 2.0)
    end
end
-- }}}

-- {{{ local function apply_closing_benefits
local function apply_closing_benefits(melee_unit_id, interaction_data)
    local momentum = interaction_data.closing_momentum
    
    if momentum > 1.0 then
        // Movement speed bonus
        local speed_bonus = momentum * 0.1  // Up to 30% speed increase
        apply_temporary_movement_speed_modifier(melee_unit_id, 1 + speed_bonus)
        
        // Damage bonus for charging
        interaction_data.closing_bonus_damage = momentum * 5  // Up to 15 extra damage
    end
end
-- }}}

-- {{{ local function apply_melee_engagement_advantages
local function apply_melee_engagement_advantages(melee_unit_id, ranged_unit_id, interaction_data)
    // Apply closing damage bonus
    if interaction_data.closing_bonus_damage > 0 then
        apply_temporary_damage_modifier(melee_unit_id, 1 + (interaction_data.closing_bonus_damage / 50))
        
        // Create charge impact effect
        create_charge_impact_effect(melee_unit_id, interaction_data.closing_bonus_damage)
        
        // Consume the bonus
        interaction_data.closing_bonus_damage = 0
    end
    
    // Ranged unit becomes vulnerable in melee
    apply_melee_vulnerability(ranged_unit_id)
    
    // Melee unit gets combat advantage
    apply_temporary_attack_speed_modifier(melee_unit_id, 1.2)  // 20% faster attacks
end
-- }}}

-- {{{ local function apply_melee_vulnerability
local function apply_melee_vulnerability(ranged_unit_id)
    // Ranged units are vulnerable in close combat
    apply_temporary_damage_resistance_modifier(ranged_unit_id, 0.8)  // Take 20% more damage
    apply_temporary_accuracy_modifier(ranged_unit_id, 0.3)  // Severely reduced accuracy
    
    // Chance to become stunned/disrupted
    if math.random() < 0.05 then  // 5% chance per frame
        trigger_combat_disruption(ranged_unit_id, "melee_engagement")
    end
end
-- }}}

-- {{{ local function apply_under_fire_bonuses
local function apply_under_fire_bonuses(melee_unit_id, interaction_data)
    local time_under_fire = interaction_data.time_under_fire
    
    if time_under_fire > 3.0 then
        // Damage resistance for surviving under fire
        local resistance_bonus = math.min(0.2, time_under_fire * 0.02)  // Up to 20% resistance
        apply_temporary_damage_resistance_modifier(melee_unit_id, 1 + resistance_bonus)
        
        // Determination bonus (minor health regen)
        if time_under_fire > 8.0 and math.random() < 0.02 then  // 2% chance per frame
            apply_minor_healing(melee_unit_id, 2)
        end
    end
end
-- }}}

-- {{{ local function update_kiting_effectiveness
local function update_kiting_effectiveness(ranged_unit_id, melee_unit_id, interaction_data)
    local ranged_moveable = EntityManager:get_component(ranged_unit_id, "moveable")
    local melee_moveable = EntityManager:get_component(melee_unit_id, "moveable")
    
    if not ranged_moveable or not melee_moveable then
        return
    end
    
    // Calculate relative movement
    local ranged_speed = Vector2:new(ranged_moveable.velocity_x, ranged_moveable.velocity_y):length()
    local melee_speed = Vector2:new(melee_moveable.velocity_x, melee_moveable.velocity_y):length()
    
    // Effective kiting requires moving away while melee pursues
    if ranged_moveable.is_moving and melee_moveable.is_moving then
        local relative_speed = ranged_speed - melee_speed
        
        if relative_speed > 0 then
            // Successfully kiting
            interaction_data.kiting_effectiveness = math.min(2.0, interaction_data.kiting_effectiveness + 0.1)
        else
            // Being caught up to
            interaction_data.kiting_effectiveness = math.max(0.5, interaction_data.kiting_effectiveness - 0.2)
        end
    end
    
    // Apply kiting bonuses/penalties
    if interaction_data.kiting_effectiveness > 1.2 then
        apply_temporary_accuracy_modifier(ranged_unit_id, interaction_data.kiting_effectiveness)
    end
end
-- }}}

-- {{{ local function update_ranged_vs_ranged_mechanics
local function update_ranged_vs_ranged_mechanics(unit_id, target_id, dt)
    // Ranged vs ranged focuses on positioning and accuracy
    local position1 = EntityManager:get_component(unit_id, "position")
    local position2 = EntityManager:get_component(target_id, "position")
    
    if not position1 or not position2 then
        return
    end
    
    local distance = Vector2:new(position1.x, position1.y):distance_to(
        Vector2:new(position2.x, position2.y)
    )
    
    // Apply range-based modifiers
    if distance > 35 then
        // Long range - accuracy penalty but damage bonus
        apply_temporary_accuracy_modifier(unit_id, 0.8)
        apply_temporary_damage_modifier(unit_id, 1.2)
    elseif distance < 20 then
        // Close range - accuracy bonus but damage penalty
        apply_temporary_accuracy_modifier(unit_id, 1.2)
        apply_temporary_damage_modifier(unit_id, 0.9)
    end
end
-- }}}

-- {{{ local function update_melee_vs_melee_mechanics
local function update_melee_vs_melee_mechanics(unit_id, target_id, dt)
    // Melee vs melee focuses on positioning and timing
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    if not unit_data.melee_duel_data then
        unit_data.melee_duel_data = {
            engagement_time = 0,
            successful_hits = 0,
            blocks_or_dodges = 0
        }
    end
    
    local duel_data = unit_data.melee_duel_data
    duel_data.engagement_time = duel_data.engagement_time + dt
    
    // Apply experience bonuses for prolonged combat
    if duel_data.engagement_time > 5.0 then
        local experience_bonus = math.min(0.15, duel_data.engagement_time * 0.01)
        apply_temporary_damage_modifier(unit_id, 1 + experience_bonus)
    end
end
-- }}}

-- {{{ local function trigger_combat_disruption
local function trigger_combat_disruption(unit_id, disruption_type)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    // Add disruption effect
    unit_data.disruption = {
        type = disruption_type,
        duration = 1.0,  // 1 second disruption
        start_time = love.timer.getTime(),
        effect_applied = false
    }
    
    // Create visual effect
    create_disruption_effect(unit_id, disruption_type)
    
    Debug:log("Unit " .. unit_id .. " disrupted by " .. disruption_type)
end
-- }}}

-- {{{ local function create_charge_impact_effect
local function create_charge_impact_effect(melee_unit_id, bonus_damage)
    local position = EntityManager:get_component(melee_unit_id, "position")
    
    if position then
        local effect = {
            type = "charge_impact",
            position = Vector2:new(position.x, position.y),
            duration = 0.5,
            start_time = love.timer.getTime(),
            intensity = math.min(1.0, bonus_damage / 15),
            color = Colors.ORANGE
        }
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function create_disruption_effect
local function create_disruption_effect(unit_id, disruption_type)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local effect_color = Colors.YELLOW
        if disruption_type == "melee_pressure" then
            effect_color = Colors.RED
        elseif disruption_type == "melee_engagement" then
            effect_color = Colors.ORANGE
        end
        
        local effect = {
            type = "combat_disruption",
            position = Vector2:new(position.x, position.y),
            duration = 1.0,
            start_time = love.timer.getTime(),
            color = effect_color,
            disruption_type = disruption_type
        }
        EffectSystem:add_effect(effect)
    end
end
-- }}}

-- {{{ local function apply_temporary_accuracy_modifier
local function apply_temporary_accuracy_modifier(unit_id, modifier)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.accuracy = modifier
    end
end
-- }}}

-- {{{ local function apply_temporary_damage_modifier
local function apply_temporary_damage_modifier(unit_id, modifier)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.damage = modifier
    end
end
-- }}}
```

### Interaction Mechanics Features
1. **Type-Specific Combat**: Different mechanics for each unit type combination
2. **Dynamic Modifiers**: Temporary bonuses and penalties based on combat situation
3. **Momentum Systems**: Building advantages through sustained tactics
4. **Pressure Mechanics**: Psychological effects of combat stress
5. **Visual Feedback**: Clear indicators of special combat states

### Combat Interactions
- **Ranged vs Melee**: Range advantage vs closing momentum
- **Melee vs Ranged**: Charge bonuses vs kiting penalties
- **Ranged vs Ranged**: Range optimization and positioning
- **Melee vs Melee**: Experience and endurance factors

### Tactical Depth
- Ranged units stronger at distance, vulnerable up close
- Melee units build momentum when closing distance
- Kiting effectiveness varies based on execution
- Combat disruption adds unpredictability

### Tool Suggestions
- Use Write tool to create interaction mechanics system
- Test with various unit type combinations
- Verify modifier applications and combat balance
- Check visual effects and feedback systems

### Acceptance Criteria
- [ ] Different unit type combinations have distinct mechanics
- [ ] Range advantages and disadvantages are clearly felt
- [ ] Momentum and pressure systems create tactical depth
- [ ] Visual feedback clearly communicates special states
- [ ] Combat balance encourages different tactical approaches