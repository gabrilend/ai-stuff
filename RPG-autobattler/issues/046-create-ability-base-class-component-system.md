# Issue #405: Create Ability Base Class/Component System

## Current Behavior
Mana system exists but lacks a structured ability framework for defining, storing, and executing different types of abilities.

## Intended Behavior
Implement a comprehensive ability component system that provides a flexible foundation for all unit abilities with proper inheritance, composition, and extensibility.

## Implementation Details

### Ability Base Component (src/components/ability.lua)
```lua
-- {{{ AbilityComponent
local AbilityComponent = {}
AbilityComponent.__index = AbilityComponent

function AbilityComponent:new(ability_config)
    local component = {
        -- Core ability properties
        id = ability_config.id or love.math.random(10000, 99999),
        name = ability_config.name or "Unknown Ability",
        type = ability_config.type or "basic",
        category = ability_config.category or "active", -- active, passive, triggered
        
        -- Mana and resource costs
        max_mana_cost = ability_config.max_mana_cost or 100,
        current_mana = 0,
        mana_generation_rate = ability_config.mana_generation_rate or 10,
        
        -- Targeting properties
        targeting_type = ability_config.targeting_type or "enemy", -- enemy, ally, self, ground, area
        range = ability_config.range or 50,
        area_of_effect = ability_config.area_of_effect or 0,
        max_targets = ability_config.max_targets or 1,
        line_of_sight_required = ability_config.line_of_sight_required or true,
        
        -- Effect properties
        base_power = ability_config.base_power or 50,
        scaling_factor = ability_config.scaling_factor or 1.0,
        effect_duration = ability_config.effect_duration or 0, -- 0 for instant
        cooldown_duration = ability_config.cooldown_duration or 0,
        
        -- Conditional properties
        generation_conditions = ability_config.generation_conditions or {},
        activation_conditions = ability_config.activation_conditions or {},
        
        -- State tracking
        last_used_time = 0,
        times_used = 0,
        total_damage_dealt = 0,
        total_healing_done = 0,
        
        -- Custom effect data
        effect_data = ability_config.effect_data or {},
        
        -- Visual and audio
        visual_effect = ability_config.visual_effect,
        sound_effect = ability_config.sound_effect,
        animation_duration = ability_config.animation_duration or 0.5
    }
    
    setmetatable(component, self)
    return component
end
-- }}}

-- {{{ function AbilityComponent:can_generate_mana
function AbilityComponent:can_generate_mana(unit_state, game_context)
    -- No conditions means always generate (for primary abilities)
    if not self.generation_conditions or #self.generation_conditions == 0 then
        return true
    end
    
    -- Check all generation conditions
    for _, condition in ipairs(self.generation_conditions) do
        if not self:check_condition(condition, unit_state, game_context) then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ function AbilityComponent:can_activate
function AbilityComponent:can_activate(unit_state, game_context)
    -- Check mana requirement
    if self.current_mana < self.max_mana_cost then
        return false, "insufficient_mana"
    end
    
    -- Check cooldown
    local current_time = love.timer.getTime()
    if current_time - self.last_used_time < self.cooldown_duration then
        return false, "on_cooldown"
    end
    
    -- Check activation conditions
    for _, condition in ipairs(self.activation_conditions) do
        local result, reason = self:check_condition(condition, unit_state, game_context)
        if not result then
            return false, reason or "condition_not_met"
        end
    end
    
    return true
end
-- }}}

-- {{{ function AbilityComponent:check_condition
function AbilityComponent:check_condition(condition, unit_state, game_context)
    local condition_type = condition.type
    
    if condition_type == "unit_type" then
        return unit_state.unit_type == condition.value
    elseif condition_type == "health_percentage" then
        local health_pct = unit_state.current_health / unit_state.max_health
        return self:check_comparison(health_pct, condition.operator, condition.value)
    elseif condition_type == "enemies_in_range" then
        local enemy_count = #(unit_state.enemies_in_range or {})
        return self:check_comparison(enemy_count, condition.operator, condition.value)
    elseif condition_type == "is_stationary" then
        return unit_state.is_stationary == condition.value
    elseif condition_type == "combat_state" then
        return unit_state.combat_state == condition.value
    elseif condition_type == "allies_nearby" then
        local ally_count = #(unit_state.allies_nearby or {})
        return self:check_comparison(ally_count, condition.operator, condition.value)
    elseif condition_type == "has_buff" then
        return unit_state.active_buffs and unit_state.active_buffs[condition.value] ~= nil
    elseif condition_type == "missing_buff" then
        return not (unit_state.active_buffs and unit_state.active_buffs[condition.value])
    else
        -- Custom condition - delegate to ability type handler
        return self:check_custom_condition(condition, unit_state, game_context)
    end
end
-- }}}

-- {{{ function AbilityComponent:check_comparison
function AbilityComponent:check_comparison(actual_value, operator, expected_value)
    if operator == "==" or operator == "equals" then
        return actual_value == expected_value
    elseif operator == ">" or operator == "greater_than" then
        return actual_value > expected_value
    elseif operator == ">=" or operator == "greater_equal" then
        return actual_value >= expected_value
    elseif operator == "<" or operator == "less_than" then
        return actual_value < expected_value
    elseif operator == "<=" or operator == "less_equal" then
        return actual_value <= expected_value
    else
        return false
    end
end
-- }}}

-- {{{ function AbilityComponent:check_custom_condition
function AbilityComponent:check_custom_condition(condition, unit_state, game_context)
    -- Override in specialized ability components
    return true
end
-- }}}

-- {{{ function AbilityComponent:update_mana
function AbilityComponent:update_mana(dt, unit_state, game_context)
    if self.current_mana >= self.max_mana_cost then
        return -- Already at maximum
    end
    
    if self:can_generate_mana(unit_state, game_context) then
        local generation_rate = self:get_effective_generation_rate(unit_state, game_context)
        self.current_mana = math.min(
            self.max_mana_cost,
            self.current_mana + (generation_rate * dt)
        )
    end
end
-- }}}

-- {{{ function AbilityComponent:get_effective_generation_rate
function AbilityComponent:get_effective_generation_rate(unit_state, game_context)
    local base_rate = self.mana_generation_rate
    local multiplier = 1.0
    
    -- Apply generation bonuses based on conditions
    for _, condition in ipairs(self.generation_conditions) do
        if condition.bonus_multiplier and self:check_condition(condition, unit_state, game_context) then
            multiplier = multiplier * condition.bonus_multiplier
        end
    end
    
    -- Apply global modifiers (buffs, debuffs, etc.)
    if unit_state.active_buffs then
        for buff_name, buff_data in pairs(unit_state.active_buffs) do
            if buff_data.mana_generation_modifier then
                multiplier = multiplier * buff_data.mana_generation_modifier
            end
        end
    end
    
    return base_rate * multiplier
end
-- }}}

-- {{{ function AbilityComponent:get_mana_percentage
function AbilityComponent:get_mana_percentage()
    if self.max_mana_cost == 0 then return 1.0 end
    return self.current_mana / self.max_mana_cost
end
-- }}}

-- {{{ function AbilityComponent:consume_mana
function AbilityComponent:consume_mana(amount)
    if self.current_mana >= amount then
        self.current_mana = self.current_mana - amount
        self.last_used_time = love.timer.getTime()
        self.times_used = self.times_used + 1
        return true
    end
    return false
end
-- }}}

-- {{{ function AbilityComponent:reset_mana
function AbilityComponent:reset_mana()
    self.current_mana = 0
end
-- }}}

-- {{{ function AbilityComponent:get_debug_info
function AbilityComponent:get_debug_info()
    return {
        name = self.name,
        type = self.type,
        mana_percentage = self:get_mana_percentage(),
        times_used = self.times_used,
        last_used = self.last_used_time,
        can_activate = self.current_mana >= self.max_mana_cost
    }
end
-- }}}

return AbilityComponent
```

### Specialized Ability Components (src/components/abilities/)

#### Damage Ability Component (src/components/abilities/damage_ability.lua)
```lua
-- {{{ DamageAbilityComponent
local AbilityComponent = require("src.components.ability")
local DamageAbilityComponent = {}
DamageAbilityComponent.__index = DamageAbilityComponent
setmetatable(DamageAbilityComponent, AbilityComponent)

function DamageAbilityComponent:new(config)
    local ability = AbilityComponent:new(config)
    
    -- Damage-specific properties
    ability.damage_type = config.damage_type or "physical" -- physical, magical, true
    ability.armor_penetration = config.armor_penetration or 0
    ability.critical_chance = config.critical_chance or 0
    ability.critical_multiplier = config.critical_multiplier or 2.0
    ability.damage_over_time = config.damage_over_time or 0
    ability.knockback_force = config.knockback_force or 0
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function DamageAbilityComponent:calculate_damage
function DamageAbilityComponent:calculate_damage(target_info, power_percentage)
    local base_damage = self.base_power * power_percentage
    
    -- Apply scaling based on unit stats
    if target_info.attacker_stats then
        base_damage = base_damage * self.scaling_factor * (target_info.attacker_stats.attack or 1.0)
    end
    
    -- Calculate critical hit
    local is_critical = love.math.random() < self.critical_chance
    if is_critical then
        base_damage = base_damage * self.critical_multiplier
    end
    
    -- Apply armor and resistances
    local final_damage = self:apply_damage_reduction(base_damage, target_info)
    
    return {
        damage = final_damage,
        is_critical = is_critical,
        damage_type = self.damage_type,
        knockback = self.knockback_force * power_percentage
    }
end
-- }}}

-- {{{ function DamageAbilityComponent:apply_damage_reduction
function DamageAbilityComponent:apply_damage_reduction(damage, target_info)
    if not target_info.target_stats then return damage end
    
    local armor = target_info.target_stats.armor or 0
    local magic_resist = target_info.target_stats.magic_resist or 0
    
    if self.damage_type == "physical" then
        local effective_armor = math.max(0, armor - self.armor_penetration)
        local damage_reduction = effective_armor / (effective_armor + 100)
        return damage * (1 - damage_reduction)
    elseif self.damage_type == "magical" then
        local damage_reduction = magic_resist / (magic_resist + 100)
        return damage * (1 - damage_reduction)
    else -- true damage
        return damage
    end
end
-- }}}

return DamageAbilityComponent
```

#### Healing Ability Component (src/components/abilities/heal_ability.lua)
```lua
-- {{{ HealAbilityComponent
local AbilityComponent = require("src.components.ability")
local HealAbilityComponent = {}
HealAbilityComponent.__index = HealAbilityComponent
setmetatable(HealAbilityComponent, AbilityComponent)

function HealAbilityComponent:new(config)
    local ability = AbilityComponent:new(config)
    
    -- Healing-specific properties
    ability.heal_type = config.heal_type or "instant" -- instant, over_time, burst
    ability.heal_over_time_duration = config.heal_over_time_duration or 5
    ability.bonus_low_health = config.bonus_low_health or 0 -- bonus healing when target < 50% health
    ability.self_heal_ratio = config.self_heal_ratio or 0 -- heal caster for portion of amount healed
    ability.cleanse_debuffs = config.cleanse_debuffs or false
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function HealAbilityComponent:calculate_healing
function HealAbilityComponent:calculate_healing(target_info, power_percentage)
    local base_heal = self.base_power * power_percentage
    
    -- Apply scaling based on healer stats
    if target_info.healer_stats then
        base_heal = base_heal * self.scaling_factor * (target_info.healer_stats.healing_power or 1.0)
    end
    
    -- Bonus healing for low health targets
    if target_info.target_health_percentage < 0.5 then
        base_heal = base_heal * (1 + self.bonus_low_health)
    end
    
    -- Calculate actual healing needed (prevent overheal waste)
    local health_missing = target_info.max_health - target_info.current_health
    local effective_heal = math.min(base_heal, health_missing)
    
    return {
        healing = effective_heal,
        overheal = base_heal - effective_heal,
        heal_type = self.heal_type,
        duration = self.heal_over_time_duration,
        cleanse = self.cleanse_debuffs
    }
end
-- }}}

return HealAbilityComponent
```

### Ability Container Component (src/components/unit_abilities.lua)
```lua
-- {{{ UnitAbilitiesComponent
local UnitAbilitiesComponent = {}
UnitAbilitiesComponent.__index = UnitAbilitiesComponent

function UnitAbilitiesComponent:new(ability_configs)
    local component = {
        abilities = {},
        ability_count = 0,
        active_cooldowns = {},
        global_cooldown = 0,
        last_ability_used = 0
    }
    
    -- Create ability components from configs
    for i, config in ipairs(ability_configs or {}) do
        component.abilities[i] = self:create_ability_from_config(config)
        component.ability_count = component.ability_count + 1
    end
    
    setmetatable(component, self)
    return component
end
-- }}}

-- {{{ function UnitAbilitiesComponent:create_ability_from_config
function UnitAbilitiesComponent:create_ability_from_config(config)
    local AbilityComponent = require("src.components.ability")
    local ability_type = config.type
    
    if ability_type == "damage" then
        local DamageAbilityComponent = require("src.components.abilities.damage_ability")
        return DamageAbilityComponent:new(config)
    elseif ability_type == "heal" then
        local HealAbilityComponent = require("src.components.abilities.heal_ability")
        return HealAbilityComponent:new(config)
    elseif ability_type == "buff" then
        local BuffAbilityComponent = require("src.components.abilities.buff_ability")
        return BuffAbilityComponent:new(config)
    elseif ability_type == "area_effect" then
        local AreaAbilityComponent = require("src.components.abilities.area_ability")
        return AreaAbilityComponent:new(config)
    else
        -- Default to base ability component
        return AbilityComponent:new(config)
    end
end
-- }}}

-- {{{ function UnitAbilitiesComponent:get_ability
function UnitAbilitiesComponent:get_ability(index)
    return self.abilities[index]
end
-- }}}

-- {{{ function UnitAbilitiesComponent:update_all_abilities
function UnitAbilitiesComponent:update_all_abilities(dt, unit_state, game_context)
    for _, ability in pairs(self.abilities) do
        ability:update_mana(dt, unit_state, game_context)
    end
    
    -- Update global cooldown
    if self.global_cooldown > 0 then
        self.global_cooldown = math.max(0, self.global_cooldown - dt)
    end
end
-- }}}

-- {{{ function UnitAbilitiesComponent:get_ready_abilities
function UnitAbilitiesComponent:get_ready_abilities(unit_state, game_context)
    local ready_abilities = {}
    
    for i, ability in pairs(self.abilities) do
        local can_activate, reason = ability:can_activate(unit_state, game_context)
        if can_activate and self.global_cooldown <= 0 then
            table.insert(ready_abilities, {index = i, ability = ability})
        end
    end
    
    return ready_abilities
end
-- }}}

return UnitAbilitiesComponent
```

### Integration Points
- Component system registration for ability components
- Entity manager support for ability queries
- Connection with targeting system for ability execution
- Interface with effect system for ability results

### Acceptance Criteria
- [ ] Flexible ability component system supports all ability types
- [ ] Proper inheritance structure for specialized abilities
- [ ] Condition system works for both generation and activation
- [ ] Mana efficiency calculations integrate correctly
- [ ] Component composition allows complex ability behaviors
- [ ] Performance is optimized for many abilities per unit
- [ ] Debug information is available for ability state inspection