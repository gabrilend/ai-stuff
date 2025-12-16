-- Ranged vs Melee Interaction System
-- Handles specialized mechanics between different unit types to create
-- tactical depth and meaningful combat differences

local RangedMeleeInteractionSystem = {}

-- Module requires
local Vector2 = require("src.utils.vector2")
local Colors = require("src.config.colors")
local Debug = require("src.utils.debug")

-- System state
local active_interactions = {}

-- {{{ local function update_ranged_melee_interactions
local function update_ranged_melee_interactions(dt)
    local all_combat_units = get_units_in_combat()
    
    for _, unit_id in ipairs(all_combat_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        
        if unit_data and unit_data.combat_target then
            update_unit_interaction_mechanics(unit_id, unit_data.combat_target, dt)
        end
    end
    
    -- Clean up expired modifiers
    cleanup_expired_modifiers(dt)
end
-- }}}

-- {{{ local function get_units_in_combat
local function get_units_in_combat()
    local combat_units = {}
    local all_units = EntityManager:get_entities_with_component("unit")
    
    for _, unit_id in ipairs(all_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        if unit_data and unit_data.state == "combat" then
            table.insert(combat_units, unit_id)
        end
    end
    
    return combat_units
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
    
    -- Apply interaction mechanics based on unit type combination
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
    
    -- Initialize interaction data if needed
    if not ranged_data.interaction_data then
        ranged_data.interaction_data = {
            distance_advantage_time = 0,
            last_successful_hit = 0,
            kiting_effectiveness = 1.0,
            pressure_level = 0
        }
    end
    
    local interaction_data = ranged_data.interaction_data
    
    -- Calculate distance advantage
    local optimal_range = 30
    local danger_range = 15
    
    if distance > optimal_range then
        -- In optimal range - accumulate advantage
        interaction_data.distance_advantage_time = interaction_data.distance_advantage_time + dt
        interaction_data.pressure_level = math.max(0, interaction_data.pressure_level - dt * 0.5)
        
        -- Apply range advantage bonuses
        apply_range_advantage_bonuses(ranged_unit_id, interaction_data)
        
    elseif distance < danger_range then
        -- In danger - apply pressure penalties
        interaction_data.pressure_level = math.min(3.0, interaction_data.pressure_level + dt * 2.0)
        interaction_data.distance_advantage_time = 0
        
        -- Apply close combat penalties
        apply_close_combat_penalties(ranged_unit_id, interaction_data)
        
    else
        -- In neutral range
        interaction_data.pressure_level = math.max(0, interaction_data.pressure_level - dt * 0.2)
    end
    
    -- Update kiting effectiveness
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
    
    -- Initialize interaction data if needed
    if not melee_data.interaction_data then
        melee_data.interaction_data = {
            closing_momentum = 0,
            time_under_fire = 0,
            charge_effectiveness = 1.0,
            closing_bonus_damage = 0
        }
    end
    
    local interaction_data = melee_data.interaction_data
    
    -- Track time under ranged fire
    interaction_data.time_under_fire = interaction_data.time_under_fire + dt
    
    -- Calculate closing mechanics
    local closing_distance = 20
    local engagement_distance = 12
    
    if distance > closing_distance then
        -- Far from target - build momentum
        update_closing_momentum(melee_unit_id, ranged_unit_id, interaction_data, dt)
        
    elseif distance > engagement_distance then
        -- Closing in - apply momentum benefits
        apply_closing_benefits(melee_unit_id, interaction_data)
        
    else
        -- In melee range - apply close combat advantages
        apply_melee_engagement_advantages(melee_unit_id, ranged_unit_id, interaction_data)
    end
    
    -- Apply survival bonuses for time under fire
    apply_under_fire_bonuses(melee_unit_id, interaction_data)
end
-- }}}

-- {{{ local function apply_range_advantage_bonuses
local function apply_range_advantage_bonuses(ranged_unit_id, interaction_data)
    local advantage_time = interaction_data.distance_advantage_time
    
    if advantage_time > 2.0 then
        -- Accuracy bonus for sustained ranging
        local accuracy_bonus = math.min(0.3, advantage_time * 0.05)  -- Up to 30% bonus
        apply_temporary_accuracy_modifier(ranged_unit_id, 1 + accuracy_bonus, 1.0)
        
        -- Damage bonus for steady aim
        if advantage_time > 5.0 then
            local damage_bonus = math.min(0.2, (advantage_time - 5.0) * 0.02)  -- Up to 20% bonus
            apply_temporary_damage_modifier(ranged_unit_id, 1 + damage_bonus, 1.0)
        end
    end
end
-- }}}

-- {{{ local function apply_close_combat_penalties
local function apply_close_combat_penalties(ranged_unit_id, interaction_data)
    local pressure = interaction_data.pressure_level
    
    -- Accuracy penalty under pressure
    local accuracy_penalty = pressure * 0.15  -- Up to 45% penalty at max pressure
    apply_temporary_accuracy_modifier(ranged_unit_id, 1 - accuracy_penalty, 0.5)
    
    -- Attack speed penalty
    local speed_penalty = pressure * 0.1  -- Up to 30% slower
    apply_temporary_attack_speed_modifier(ranged_unit_id, 1 - speed_penalty, 0.5)
    
    -- Chance to be disrupted
    if pressure > 2.0 and math.random() < 0.1 then  -- 10% chance per frame at high pressure
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
    
    -- Build momentum while moving toward ranged target
    if melee_moveable.is_moving then
        local velocity = Vector2:new(melee_moveable.velocity_x, melee_moveable.velocity_y)
        local speed = velocity:length()
        
        if speed > 10 then  -- Only if moving with purpose
            interaction_data.closing_momentum = math.min(3.0, interaction_data.closing_momentum + dt)
        end
    else
        -- Lose momentum when not moving
        interaction_data.closing_momentum = math.max(0, interaction_data.closing_momentum - dt * 2.0)
    end
end
-- }}}

-- {{{ local function apply_closing_benefits
local function apply_closing_benefits(melee_unit_id, interaction_data)
    local momentum = interaction_data.closing_momentum
    
    if momentum > 1.0 then
        -- Movement speed bonus
        local speed_bonus = momentum * 0.1  -- Up to 30% speed increase
        apply_temporary_movement_speed_modifier(melee_unit_id, 1 + speed_bonus, 1.0)
        
        -- Damage bonus for charging
        interaction_data.closing_bonus_damage = momentum * 5  -- Up to 15 extra damage
    end
end
-- }}}

-- {{{ local function apply_melee_engagement_advantages
local function apply_melee_engagement_advantages(melee_unit_id, ranged_unit_id, interaction_data)
    -- Apply closing damage bonus
    if interaction_data.closing_bonus_damage > 0 then
        apply_temporary_damage_modifier(melee_unit_id, 1 + (interaction_data.closing_bonus_damage / 50), 2.0)
        
        -- Create charge impact effect
        create_charge_impact_effect(melee_unit_id, interaction_data.closing_bonus_damage)
        
        -- Consume the bonus
        interaction_data.closing_bonus_damage = 0
    end
    
    -- Ranged unit becomes vulnerable in melee
    apply_melee_vulnerability(ranged_unit_id)
    
    -- Melee unit gets combat advantage
    apply_temporary_attack_speed_modifier(melee_unit_id, 1.2, 2.0)  -- 20% faster attacks
end
-- }}}

-- {{{ local function apply_melee_vulnerability
local function apply_melee_vulnerability(ranged_unit_id)
    -- Ranged units are vulnerable in close combat
    apply_temporary_damage_resistance_modifier(ranged_unit_id, 0.8, 1.0)  -- Take 20% more damage
    apply_temporary_accuracy_modifier(ranged_unit_id, 0.3, 1.0)  -- Severely reduced accuracy
    
    -- Chance to become stunned/disrupted
    if math.random() < 0.05 then  -- 5% chance per frame
        trigger_combat_disruption(ranged_unit_id, "melee_engagement")
    end
end
-- }}}

-- {{{ local function apply_under_fire_bonuses
local function apply_under_fire_bonuses(melee_unit_id, interaction_data)
    local time_under_fire = interaction_data.time_under_fire
    
    if time_under_fire > 3.0 then
        -- Damage resistance for surviving under fire
        local resistance_bonus = math.min(0.2, time_under_fire * 0.02)  -- Up to 20% resistance
        apply_temporary_damage_resistance_modifier(melee_unit_id, 1 + resistance_bonus, 1.0)
        
        -- Determination bonus (minor health regen)
        if time_under_fire > 8.0 and math.random() < 0.02 then  -- 2% chance per frame
            apply_minor_healing(melee_unit_id, 2)
        end
    end
end
-- }}}

-- {{{ local function apply_minor_healing
local function apply_minor_healing(unit_id, amount)
    local health = EntityManager:get_component(unit_id, "health")
    if health and health.is_alive then
        health.current = math.min(health.maximum, health.current + amount)
        
        -- Create healing effect
        create_healing_effect(unit_id, amount)
    end
end
-- }}}

-- {{{ local function create_healing_effect
local function create_healing_effect(unit_id, amount)
    local position = EntityManager:get_component(unit_id, "position")
    
    if position then
        local effect = {
            type = "minor_healing",
            position = Vector2:new(position.x, position.y - 10),
            healing = amount,
            duration = 1.0,
            start_time = love.timer.getTime(),
            color = Colors.GREEN
        }
        EffectSystem:add_effect(effect)
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
    
    -- Calculate relative movement
    local ranged_speed = Vector2:new(ranged_moveable.velocity_x, ranged_moveable.velocity_y):length()
    local melee_speed = Vector2:new(melee_moveable.velocity_x, melee_moveable.velocity_y):length()
    
    -- Effective kiting requires moving away while melee pursues
    if ranged_moveable.is_moving and melee_moveable.is_moving then
        local relative_speed = ranged_speed - melee_speed
        
        if relative_speed > 0 then
            -- Successfully kiting
            interaction_data.kiting_effectiveness = math.min(2.0, interaction_data.kiting_effectiveness + 0.1)
        else
            -- Being caught up to
            interaction_data.kiting_effectiveness = math.max(0.5, interaction_data.kiting_effectiveness - 0.2)
        end
    end
    
    -- Apply kiting bonuses/penalties
    if interaction_data.kiting_effectiveness > 1.2 then
        apply_temporary_accuracy_modifier(ranged_unit_id, interaction_data.kiting_effectiveness, 0.5)
    end
end
-- }}}

-- {{{ local function update_ranged_vs_ranged_mechanics
local function update_ranged_vs_ranged_mechanics(unit_id, target_id, dt)
    -- Ranged vs ranged focuses on positioning and accuracy
    local position1 = EntityManager:get_component(unit_id, "position")
    local position2 = EntityManager:get_component(target_id, "position")
    
    if not position1 or not position2 then
        return
    end
    
    local distance = Vector2:new(position1.x, position1.y):distance_to(
        Vector2:new(position2.x, position2.y)
    )
    
    -- Apply range-based modifiers
    if distance > 35 then
        -- Long range - accuracy penalty but damage bonus
        apply_temporary_accuracy_modifier(unit_id, 0.8, 0.5)
        apply_temporary_damage_modifier(unit_id, 1.2, 0.5)
    elseif distance < 20 then
        -- Close range - accuracy bonus but damage penalty
        apply_temporary_accuracy_modifier(unit_id, 1.2, 0.5)
        apply_temporary_damage_modifier(unit_id, 0.9, 0.5)
    end
end
-- }}}

-- {{{ local function update_melee_vs_melee_mechanics
local function update_melee_vs_melee_mechanics(unit_id, target_id, dt)
    -- Melee vs melee focuses on positioning and timing
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
    
    -- Apply experience bonuses for prolonged combat
    if duel_data.engagement_time > 5.0 then
        local experience_bonus = math.min(0.15, duel_data.engagement_time * 0.01)
        apply_temporary_damage_modifier(unit_id, 1 + experience_bonus, 1.0)
    end
end
-- }}}

-- {{{ local function trigger_combat_disruption
local function trigger_combat_disruption(unit_id, disruption_type)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if not unit_data then
        return
    end
    
    -- Add disruption effect
    unit_data.disruption = {
        type = disruption_type,
        duration = 1.0,  -- 1 second disruption
        start_time = love.timer.getTime(),
        effect_applied = false
    }
    
    -- Create visual effect
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
local function apply_temporary_accuracy_modifier(unit_id, modifier, duration)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.accuracy = {
            value = modifier,
            expiry_time = love.timer.getTime() + duration
        }
    end
end
-- }}}

-- {{{ local function apply_temporary_damage_modifier
local function apply_temporary_damage_modifier(unit_id, modifier, duration)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.damage = {
            value = modifier,
            expiry_time = love.timer.getTime() + duration
        }
    end
end
-- }}}

-- {{{ local function apply_temporary_attack_speed_modifier
local function apply_temporary_attack_speed_modifier(unit_id, modifier, duration)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.attack_speed = {
            value = modifier,
            expiry_time = love.timer.getTime() + duration
        }
    end
end
-- }}}

-- {{{ local function apply_temporary_movement_speed_modifier
local function apply_temporary_movement_speed_modifier(unit_id, modifier, duration)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.movement_speed = {
            value = modifier,
            expiry_time = love.timer.getTime() + duration
        }
    end
end
-- }}}

-- {{{ local function apply_temporary_damage_resistance_modifier
local function apply_temporary_damage_resistance_modifier(unit_id, modifier, duration)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        if not unit_data.temporary_modifiers then
            unit_data.temporary_modifiers = {}
        end
        
        unit_data.temporary_modifiers.damage_resistance = {
            value = modifier,
            expiry_time = love.timer.getTime() + duration
        }
    end
end
-- }}}

-- {{{ local function cleanup_expired_modifiers
local function cleanup_expired_modifiers(dt)
    local all_units = EntityManager:get_entities_with_component("unit")
    local current_time = love.timer.getTime()
    
    for _, unit_id in ipairs(all_units) do
        local unit_data = EntityManager:get_component(unit_id, "unit")
        
        if unit_data and unit_data.temporary_modifiers then
            local modifiers_to_remove = {}
            
            for modifier_type, modifier_data in pairs(unit_data.temporary_modifiers) do
                if modifier_data.expiry_time and current_time >= modifier_data.expiry_time then
                    table.insert(modifiers_to_remove, modifier_type)
                end
            end
            
            for _, modifier_type in ipairs(modifiers_to_remove) do
                unit_data.temporary_modifiers[modifier_type] = nil
            end
        end
    end
end
-- }}}

-- Public API
function RangedMeleeInteractionSystem:update(dt)
    update_ranged_melee_interactions(dt)
end

function RangedMeleeInteractionSystem:get_unit_modifier(unit_id, modifier_type)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data and unit_data.temporary_modifiers and unit_data.temporary_modifiers[modifier_type] then
        local modifier = unit_data.temporary_modifiers[modifier_type]
        local current_time = love.timer.getTime()
        
        if not modifier.expiry_time or current_time < modifier.expiry_time then
            return modifier.value
        end
    end
    
    return 1.0  -- Default modifier
end

function RangedMeleeInteractionSystem:clear_unit_modifiers(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        unit_data.temporary_modifiers = {}
    end
end

function RangedMeleeInteractionSystem:get_interaction_data(unit_id)
    local unit_data = EntityManager:get_component(unit_id, "unit")
    
    if unit_data then
        return unit_data.interaction_data or {}
    end
    
    return {}
end

return RangedMeleeInteractionSystem