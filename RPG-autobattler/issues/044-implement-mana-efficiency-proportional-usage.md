# Issue #403: Implement Mana Efficiency (Proportional Usage)

## Current Behavior
Abilities use fixed mana amounts regardless of target health or effect efficiency, leading to mana waste on overkill damage or minimal healing.

## Intended Behavior
Implement proportional mana usage where abilities only consume the mana needed to achieve their effect, preventing waste on overkill damage or unnecessary healing.

## Implementation Details

### Mana Efficiency System (src/systems/mana_efficiency_system.lua)
```lua
-- {{{ ManaEfficiencySystem
local ManaEfficiencySystem = {}
ManaEfficiencySystem.__index = ManaEfficiencySystem

function ManaEfficiencySystem:new()
    local system = {
        efficiency_threshold = 0.1, -- minimum mana usage (10% of max)
        overkill_prevention = true,
        overheal_prevention = true,
        partial_effect_support = true
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function ManaEfficiencySystem:calculate_optimal_mana_usage
function ManaEfficiencySystem:calculate_optimal_mana_usage(ability, target_info, available_mana)
    local ability_type = ability.type
    local max_effect = ability.max_effect or 100
    local max_mana_cost = ability.max_mana_cost or 100
    
    if ability_type == "damage" then
        return self:calculate_damage_efficiency(ability, target_info, available_mana)
    elseif ability_type == "heal" then
        return self:calculate_heal_efficiency(ability, target_info, available_mana)
    elseif ability_type == "buff" or ability_type == "debuff" then
        return self:calculate_buff_efficiency(ability, target_info, available_mana)
    elseif ability_type == "area_effect" then
        return self:calculate_area_efficiency(ability, target_info, available_mana)
    else
        -- Default: use full mana for unknown ability types
        return {
            mana_to_use = available_mana,
            effect_power = 1.0,
            efficiency_rating = 1.0,
            can_execute = available_mana >= (max_mana_cost * self.efficiency_threshold)
        }
    end
end
-- }}}

-- {{{ function ManaEfficiencySystem:calculate_damage_efficiency
function ManaEfficiencySystem:calculate_damage_efficiency(ability, target_info, available_mana)
    local max_damage = ability.max_effect
    local max_mana = ability.max_mana_cost
    local target_health = target_info.current_health
    
    if target_health <= 0 then
        return {
            mana_to_use = 0,
            effect_power = 0,
            efficiency_rating = 0,
            can_execute = false,
            reason = "target_dead"
        }
    end
    
    -- Calculate how much damage is actually needed
    local damage_needed = math.min(target_health, max_damage)
    local damage_ratio = damage_needed / max_damage
    
    -- Calculate proportional mana cost
    local mana_needed = max_mana * damage_ratio
    
    -- Ensure minimum viable mana usage
    local minimum_mana = max_mana * self.efficiency_threshold
    local optimal_mana = math.max(minimum_mana, mana_needed)
    
    -- Check if we have enough mana
    local can_execute = available_mana >= optimal_mana
    local actual_mana_to_use = math.min(available_mana, optimal_mana)
    
    -- Calculate actual effect power based on mana we'll use
    local effect_power = (actual_mana_to_use / max_mana)
    local actual_damage = max_damage * effect_power
    
    return {
        mana_to_use = actual_mana_to_use,
        effect_power = effect_power,
        actual_damage = actual_damage,
        damage_needed = damage_needed,
        efficiency_rating = damage_needed / max_damage,
        can_execute = can_execute,
        is_overkill = actual_damage > target_health,
        overkill_amount = math.max(0, actual_damage - target_health)
    }
end
-- }}}

-- {{{ function ManaEfficiencySystem:calculate_heal_efficiency
function ManaEfficiencySystem:calculate_heal_efficiency(ability, target_info, available_mana)
    local max_heal = ability.max_effect
    local max_mana = ability.max_mana_cost
    local target_current_health = target_info.current_health
    local target_max_health = target_info.max_health
    
    if target_current_health >= target_max_health then
        return {
            mana_to_use = 0,
            effect_power = 0,
            efficiency_rating = 0,
            can_execute = false,
            reason = "target_full_health"
        }
    end
    
    -- Calculate how much healing is actually needed
    local health_missing = target_max_health - target_current_health
    local heal_needed = math.min(health_missing, max_heal)
    local heal_ratio = heal_needed / max_heal
    
    -- Calculate proportional mana cost
    local mana_needed = max_mana * heal_ratio
    
    -- Ensure minimum viable mana usage for small heals
    local minimum_mana = max_mana * self.efficiency_threshold
    local optimal_mana = math.max(minimum_mana, mana_needed)
    
    -- Check if we have enough mana
    local can_execute = available_mana >= optimal_mana
    local actual_mana_to_use = math.min(available_mana, optimal_mana)
    
    -- Calculate actual effect power based on mana we'll use
    local effect_power = (actual_mana_to_use / max_mana)
    local actual_heal = max_heal * effect_power
    
    return {
        mana_to_use = actual_mana_to_use,
        effect_power = effect_power,
        actual_heal = actual_heal,
        heal_needed = heal_needed,
        efficiency_rating = heal_needed / max_heal,
        can_execute = can_execute,
        is_overheal = actual_heal > health_missing,
        overheal_amount = math.max(0, actual_heal - health_missing)
    }
end
-- }}}

-- {{{ function ManaEfficiencySystem:calculate_buff_efficiency
function ManaEfficiencySystem:calculate_buff_efficiency(ability, target_info, available_mana)
    local max_mana = ability.max_mana_cost
    local buff_duration = ability.duration or 10
    local buff_power = ability.power or 1.0
    
    -- Check if target already has this buff
    if target_info.active_buffs and target_info.active_buffs[ability.buff_type] then
        local existing_buff = target_info.active_buffs[ability.buff_type]
        
        -- If buff is already stronger or longer, don't waste mana
        if existing_buff.power >= buff_power and existing_buff.remaining_time > buff_duration * 0.5 then
            return {
                mana_to_use = 0,
                effect_power = 0,
                efficiency_rating = 0,
                can_execute = false,
                reason = "buff_already_active"
            }
        end
        
        -- If refreshing/upgrading buff, use partial mana based on remaining time
        local time_efficiency = 1.0 - (existing_buff.remaining_time / buff_duration)
        local power_efficiency = math.max(0, buff_power - existing_buff.power) / buff_power
        local efficiency = math.max(time_efficiency, power_efficiency)
        
        local optimal_mana = max_mana * efficiency
        local actual_mana_to_use = math.min(available_mana, optimal_mana)
        
        return {
            mana_to_use = actual_mana_to_use,
            effect_power = actual_mana_to_use / max_mana,
            efficiency_rating = efficiency,
            can_execute = actual_mana_to_use >= (max_mana * self.efficiency_threshold),
            is_refresh = true
        }
    end
    
    -- New buff - use full mana for maximum effect
    local can_execute = available_mana >= (max_mana * self.efficiency_threshold)
    local actual_mana_to_use = math.min(available_mana, max_mana)
    
    return {
        mana_to_use = actual_mana_to_use,
        effect_power = actual_mana_to_use / max_mana,
        efficiency_rating = 1.0,
        can_execute = can_execute,
        is_new_buff = true
    }
end
-- }}}

-- {{{ function ManaEfficiencySystem:calculate_area_efficiency
function ManaEfficiencySystem:calculate_area_efficiency(ability, target_info, available_mana)
    local max_mana = ability.max_mana_cost
    local targets_in_area = target_info.targets_in_area or {}
    local optimal_target_count = ability.optimal_targets or 3
    
    if #targets_in_area == 0 then
        return {
            mana_to_use = 0,
            effect_power = 0,
            efficiency_rating = 0,
            can_execute = false,
            reason = "no_targets_in_area"
        }
    end
    
    -- Calculate efficiency based on target count vs optimal
    local target_efficiency = math.min(1.0, #targets_in_area / optimal_target_count)
    
    -- For area abilities, also consider target health/value
    local total_target_value = 0
    local max_possible_value = 0
    
    for _, target in ipairs(targets_in_area) do
        if ability.type == "damage" then
            total_target_value = total_target_value + target.current_health
            max_possible_value = max_possible_value + target.max_health
        elseif ability.type == "heal" then
            total_target_value = total_target_value + (target.max_health - target.current_health)
            max_possible_value = max_possible_value + target.max_health
        end
    end
    
    local value_efficiency = max_possible_value > 0 and (total_target_value / max_possible_value) or 1.0
    local combined_efficiency = (target_efficiency + value_efficiency) / 2
    
    -- Calculate optimal mana usage
    local optimal_mana = max_mana * combined_efficiency
    local minimum_mana = max_mana * self.efficiency_threshold
    local final_optimal_mana = math.max(minimum_mana, optimal_mana)
    
    local can_execute = available_mana >= final_optimal_mana
    local actual_mana_to_use = math.min(available_mana, final_optimal_mana)
    
    return {
        mana_to_use = actual_mana_to_use,
        effect_power = actual_mana_to_use / max_mana,
        efficiency_rating = combined_efficiency,
        can_execute = can_execute,
        target_count = #targets_in_area,
        target_efficiency = target_efficiency,
        value_efficiency = value_efficiency
    }
end
-- }}}

-- {{{ function ManaEfficiencySystem:apply_efficient_ability
function ManaEfficiencySystem:apply_efficient_ability(entity_id, ability_index, target_ids, entity_manager)
    local mana_component = entity_manager:get_component(entity_id, "mana")
    if not mana_component then return false end
    
    local ability = mana_component.abilities[ability_index]
    if not ability then return false end
    
    local available_mana = mana_component.current_mana[ability_index]
    
    -- Gather target information
    local target_info = self:gather_target_info(target_ids, ability, entity_manager)
    
    -- Calculate optimal mana usage
    local efficiency_result = self:calculate_optimal_mana_usage(ability, target_info, available_mana)
    
    if not efficiency_result.can_execute then
        return false, efficiency_result.reason
    end
    
    -- Consume the calculated amount of mana
    local success = mana_component:consume_mana(ability_index, efficiency_result.mana_to_use)
    if not success then
        return false, "insufficient_mana"
    end
    
    -- Apply the effect with the calculated power
    self:apply_ability_effect(ability, target_info, efficiency_result, entity_manager)
    
    return true, efficiency_result
end
-- }}}

-- {{{ function ManaEfficiencySystem:gather_target_info
function ManaEfficiencySystem:gather_target_info(target_ids, ability, entity_manager)
    local target_info = {}
    
    if ability.type == "area_effect" then
        target_info.targets_in_area = {}
        for _, target_id in ipairs(target_ids) do
            local health = entity_manager:get_component(target_id, "health")
            if health then
                table.insert(target_info.targets_in_area, {
                    id = target_id,
                    current_health = health.current,
                    max_health = health.max
                })
            end
        end
    else
        -- Single target ability
        local target_id = target_ids[1]
        if target_id then
            local health = entity_manager:get_component(target_id, "health")
            local unit = entity_manager:get_component(target_id, "unit")
            
            if health then
                target_info.current_health = health.current
                target_info.max_health = health.max
                target_info.active_buffs = unit and unit.active_buffs or {}
            end
        end
    end
    
    return target_info
end
-- }}}

-- {{{ function ManaEfficiencySystem:apply_ability_effect
function ManaEfficiencySystem:apply_ability_effect(ability, target_info, efficiency_result, entity_manager)
    -- This would interface with the combat/effect system
    -- For now, just log the efficient usage
    if DEBUG_MODE then
        print(string.format(
            "Efficient ability use: %s, power: %.2f, mana used: %.1f/%.1f (%.1f%% efficiency)",
            ability.name or ability.type,
            efficiency_result.effect_power,
            efficiency_result.mana_to_use,
            ability.max_mana_cost,
            efficiency_result.efficiency_rating * 100
        ))
    end
end
-- }}}

return ManaEfficiencySystem
```

### Integration with Ability Activation (src/systems/ability_activation_system.lua)
```lua
-- {{{ AbilityActivationSystem enhancement
-- This would be part of the main ability activation system

-- {{{ function AbilityActivationSystem:attempt_ability_use
function AbilityActivationSystem:attempt_ability_use(entity_id, ability_index)
    local mana_component = self.entity_manager:get_component(entity_id, "mana")
    if not mana_component then return false end
    
    -- Check if mana is full (traditional trigger)
    local mana_percentage = mana_component:get_mana_percentage(ability_index)
    if mana_percentage < 1.0 then return false end
    
    -- Find valid targets
    local targets = self:find_valid_targets(entity_id, ability_index)
    if #targets == 0 then return false end
    
    -- Use efficiency system to determine optimal usage
    local success, result = self.mana_efficiency_system:apply_efficient_ability(
        entity_id, ability_index, targets, self.entity_manager
    )
    
    if success then
        -- Log efficiency metrics for balancing
        self:log_ability_efficiency(entity_id, ability_index, result)
    end
    
    return success
end
-- }}}

-- {{{ function AbilityActivationSystem:log_ability_efficiency
function AbilityActivationSystem:log_ability_efficiency(entity_id, ability_index, result)
    -- Track efficiency statistics for game balancing
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if unit then
        unit.ability_stats = unit.ability_stats or {}
        unit.ability_stats[ability_index] = unit.ability_stats[ability_index] or {
            uses = 0,
            total_efficiency = 0,
            mana_saved = 0
        }
        
        local stats = unit.ability_stats[ability_index]
        stats.uses = stats.uses + 1
        stats.total_efficiency = stats.total_efficiency + result.efficiency_rating
        stats.mana_saved = stats.mana_saved + (ability.max_mana_cost - result.mana_to_use)
    end
end
-- }}}
```

### Acceptance Criteria
- [ ] Damage abilities use only mana proportional to target's remaining health
- [ ] Healing abilities use only mana needed to heal target to full
- [ ] Buff abilities check for existing buffs to avoid redundant mana usage
- [ ] Area abilities scale mana usage based on number and value of targets
- [ ] Minimum mana threshold prevents abilities from being completely free
- [ ] System tracks efficiency statistics for balancing purposes
- [ ] Performance impact is minimal during combat with many abilities firing