# Issue #411: Implement Basic Healing Abilities

## Current Behavior
Damage abilities exist but the game lacks healing mechanics to provide counterplay and support unit strategies.

## Intended Behavior
Implement comprehensive healing ability system with instant healing, heal over time, and advanced healing mechanics that create tactical depth and unit synergies.

## Implementation Details

### Basic Healing Ability (src/abilities/basic_heal.lua)
```lua
-- {{{ BasicHeal
local AbilityComponent = require("src.components.ability")
local BasicHeal = {}
BasicHeal.__index = BasicHeal
setmetatable(BasicHeal, AbilityComponent)

function BasicHeal:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Basic Heal",
        type = "heal",
        category = "secondary",
        targeting_type = "ally",
        range = config.range or 60,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 6,
        base_power = config.base_power or 30,
        
        -- Healing-specific properties
        heal_efficiency = config.heal_efficiency or 1.0,
        bonus_low_health = config.bonus_low_health or 0.5, -- 50% bonus when target < 50% health
        self_heal_ratio = config.self_heal_ratio or 0.2, -- Healer gets 20% of healing done
        
        -- Targeting preferences
        target_priority = "lowest_health_percentage",
        can_target_self = true,
        prefer_injured_targets = true,
        
        -- Generation conditions
        generation_conditions = {
            {type = "allies_nearby", operator = ">", value = 0},
            {type = "unit_type", value = config.required_unit_type or "any"}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "healing_light",
        sound_effect = config.sound_effect or "heal_cast"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function BasicHeal:find_targets
function BasicHeal:find_targets(caster_id, entity_manager, targeting_system)
    local caster_position = entity_manager:get_component(caster_id, "position")
    local caster_team = entity_manager:get_component(caster_id, "team")
    
    if not caster_position or not caster_team then return {} end
    
    local potential_targets = {}
    
    -- Find all allies in range (including self)
    for entity_id, team_component in entity_manager:iterate_components("team") do
        if team_component.value == caster_team.value then
            local target_position = entity_manager:get_component(entity_id, "position")
            local target_health = entity_manager:get_component(entity_id, "health")
            
            if target_position and target_health then
                local distance = caster_position.value:distance_to(target_position.value)
                
                if distance <= self.range then
                    local health_percentage = target_health.current / target_health.max
                    local health_missing = target_health.max - target_health.current
                    
                    -- Only consider targets that need healing
                    if health_missing > 0 then
                        table.insert(potential_targets, {
                            id = entity_id,
                            distance = distance,
                            position = target_position.value,
                            health = target_health,
                            health_percentage = health_percentage,
                            health_missing = health_missing,
                            healing_priority = self:calculate_healing_priority(entity_id, target_health, entity_manager)
                        })
                    end
                end
            end
        end
    end
    
    if #potential_targets == 0 then return {} end
    
    -- Sort by healing priority
    table.sort(potential_targets, function(a, b) 
        return a.healing_priority > b.healing_priority 
    end)
    
    -- Return highest priority target
    return {potential_targets[1]}
end
-- }}}

-- {{{ function BasicHeal:calculate_healing_priority
function BasicHeal:calculate_healing_priority(target_id, target_health, entity_manager)
    local priority = 0
    
    -- Base priority from health percentage (lower health = higher priority)
    local health_percentage = target_health.current / target_health.max
    priority = priority + (100 - (health_percentage * 100))
    
    -- Bonus for critically low health
    if health_percentage < 0.25 then
        priority = priority + 50
    elseif health_percentage < 0.5 then
        priority = priority + 25
    end
    
    -- Unit type priorities
    local target_unit = entity_manager:get_component(target_id, "unit")
    if target_unit then
        local unit_type_priorities = {
            healer = 30,    -- Protect other healers
            ranged = 20,    -- Protect ranged damage dealers
            melee = 10,     -- Standard priority
            tank = 5        -- Tanks are lower priority
        }
        
        priority = priority + (unit_type_priorities[target_unit.unit_type] or 10)
    end
    
    -- Ability count bonus (units with more abilities get priority)
    local target_abilities = entity_manager:get_component(target_id, "abilities")
    if target_abilities then
        priority = priority + (target_abilities.ability_count * 5)
    end
    
    return priority
end
-- }}}

-- {{{ function BasicHeal:calculate_healing_amount
function BasicHeal:calculate_healing_amount(caster_id, target, entity_manager, efficiency_factor)
    local base_heal = self.base_power * (efficiency_factor or 1.0)
    
    -- Apply caster's healing power stat
    local caster_unit = entity_manager:get_component(caster_id, "unit")
    if caster_unit and caster_unit.stats and caster_unit.stats.healing_power then
        base_heal = base_heal * caster_unit.stats.healing_power
    end
    
    -- Bonus healing for low health targets
    if target.health_percentage < 0.5 then
        base_heal = base_heal * (1 + self.bonus_low_health)
    end
    
    -- Apply healing efficiency
    base_heal = base_heal * self.heal_efficiency
    
    -- Calculate actual healing needed (prevent overheal)
    local actual_heal = math.min(base_heal, target.health_missing)
    
    return {
        intended_heal = base_heal,
        actual_heal = actual_heal,
        overheal = base_heal - actual_heal,
        efficiency = actual_heal / base_heal
    }
end
-- }}}

return BasicHeal
```

### Heal Over Time Ability (src/abilities/regeneration.lua)
```lua
-- {{{ Regeneration
local AbilityComponent = require("src.components.ability")
local Regeneration = {}
Regeneration.__index = Regeneration
setmetatable(Regeneration, AbilityComponent)

function Regeneration:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Regeneration",
        type = "heal",
        category = "secondary",
        targeting_type = "ally",
        range = config.range or 50,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 5,
        base_power = config.base_power or 15, -- Per tick
        
        -- Regeneration-specific properties
        heal_over_time_duration = config.duration or 8,
        heal_over_time_interval = config.tick_interval or 1.0,
        total_healing = config.base_power * (config.duration / config.tick_interval),
        
        -- Special effects
        cleanse_debuffs = config.cleanse_debuffs or true,
        stacks_with_self = config.stacks_with_self or false,
        max_stacks = config.max_stacks or 1,
        
        -- Generation conditions
        generation_conditions = {
            {type = "health_percentage", operator = "<", value = 0.7},
            {type = "allies_nearby", operator = ">", value = 0}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "regeneration_aura",
        sound_effect = config.sound_effect or "regen_cast"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function Regeneration:find_targets
function Regeneration:find_targets(caster_id, entity_manager, targeting_system)
    local targets = targeting_system:find_ally_targets(caster_id,
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager)
    
    -- Filter for targets that would benefit from regeneration
    local beneficial_targets = {}
    
    for _, target in ipairs(targets) do
        local health_percentage = target.health.current / target.health.max
        local needs_healing = health_percentage < 0.8
        
        -- Check if target already has regeneration
        local target_unit = entity_manager:get_component(target.id, "unit")
        local has_regen = false
        
        if target_unit and target_unit.active_buffs then
            has_regen = target_unit.active_buffs["regeneration"] ~= nil
        end
        
        -- Include target if they need healing and either don't have regen or stacking is allowed
        if needs_healing and (not has_regen or self.stacks_with_self) then
            table.insert(beneficial_targets, target)
        end
    end
    
    if #beneficial_targets == 0 then return {} end
    
    -- Sort by health percentage (lowest first)
    table.sort(beneficial_targets, function(a, b)
        local a_pct = a.health.current / a.health.max
        local b_pct = b.health.current / b.health.max
        return a_pct < b_pct
    end)
    
    return {beneficial_targets[1]}
end
-- }}}

return Regeneration
```

### Group Healing Ability (src/abilities/group_heal.lua)
```lua
-- {{{ GroupHeal
local AbilityComponent = require("src.components.ability")
local GroupHeal = {}
GroupHeal.__index = GroupHeal
setmetatable(GroupHeal, AbilityComponent)

function GroupHeal:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Group Heal",
        type = "area_effect",
        category = "secondary",
        targeting_type = "area",
        range = config.range or 50,
        area_of_effect = config.area_radius or 40,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 4,
        base_power = config.base_power or 25,
        
        -- Group healing properties
        area_effect_type = "heal",
        area_target_type = "allies",
        max_targets = config.max_targets or 5,
        healing_distribution = config.distribution or "equal", -- equal, proportional, priority
        
        -- Efficiency bonuses
        group_size_bonus = config.group_size_bonus or 0.1, -- 10% per additional target
        range_efficiency = config.range_efficiency or true, -- Closer targets get more healing
        
        -- Generation conditions
        generation_conditions = {
            {type = "allies_nearby", operator = ">=", value = 2}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "healing_wave",
        sound_effect = config.sound_effect or "group_heal"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function GroupHeal:find_targets
function GroupHeal:find_targets(caster_id, entity_manager, targeting_system)
    -- Find optimal center point for group healing
    local allies = targeting_system:find_ally_targets(caster_id,
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager)
    
    if #allies < 2 then return {} end -- Need at least 2 allies for group heal
    
    -- Find best center point that includes the most injured allies
    local best_center = self:find_optimal_healing_center(allies)
    
    if not best_center then return {} end
    
    -- Find all allies within area of effect from center
    local targets_in_area = {}
    
    for _, ally in ipairs(allies) do
        local distance_to_center = ally.position:distance_to(best_center)
        
        if distance_to_center <= self.area_of_effect then
            table.insert(targets_in_area, {
                id = ally.id,
                position = ally.position,
                health = ally.health,
                distance_to_center = distance_to_center,
                healing_need = (ally.health.max - ally.health.current) / ally.health.max
            })
        end
    end
    
    -- Sort by healing need and limit to max targets
    table.sort(targets_in_area, function(a, b) return a.healing_need > b.healing_need end)
    
    if #targets_in_area > self.max_targets then
        local limited_targets = {}
        for i = 1, self.max_targets do
            table.insert(limited_targets, targets_in_area[i])
        end
        targets_in_area = limited_targets
    end
    
    return targets_in_area
end
-- }}}

-- {{{ function GroupHeal:find_optimal_healing_center
function GroupHeal:find_optimal_healing_center(allies)
    local best_center = nil
    local best_score = 0
    
    -- Test center points around each ally
    for _, ally in ipairs(allies) do
        local score = self:evaluate_healing_center(ally.position, allies)
        
        if score > best_score then
            best_score = score
            best_center = ally.position
        end
    end
    
    return best_center
end
-- }}}

-- {{{ function GroupHeal:evaluate_healing_center
function GroupHeal:evaluate_healing_center(center, allies)
    local score = 0
    local allies_in_range = 0
    local total_healing_need = 0
    
    for _, ally in ipairs(allies) do
        local distance = ally.position:distance_to(center)
        
        if distance <= self.area_of_effect then
            allies_in_range = allies_in_range + 1
            
            local healing_need = (ally.health.max - ally.health.current) / ally.health.max
            total_healing_need = total_healing_need + healing_need
            
            -- Bonus for including critically injured allies
            if healing_need > 0.5 then
                score = score + 20
            end
        end
    end
    
    -- Score based on number of allies and their healing needs
    score = score + (allies_in_range * 10) + (total_healing_need * 30)
    
    return score
end
-- }}}

return GroupHeal
```

### Healing Factory (src/factories/healing_ability_factory.lua)
```lua
-- {{{ HealingAbilityFactory
local HealingAbilityFactory = {}
local BasicHeal = require("src.abilities.basic_heal")
local Regeneration = require("src.abilities.regeneration")
local GroupHeal = require("src.abilities.group_heal")

-- {{{ function HealingAbilityFactory:create_healing_ability
function HealingAbilityFactory:create_healing_ability(ability_type, config)
    config = config or {}
    
    if ability_type == "basic_heal" then
        return BasicHeal:new(config)
    elseif ability_type == "regeneration" then
        return Regeneration:new(config)
    elseif ability_type == "group_heal" then
        return GroupHeal:new(config)
    elseif ability_type == "emergency_heal" then
        return self:create_emergency_heal(config)
    else
        error("Unknown healing ability type: " .. tostring(ability_type))
    end
end
-- }}}

-- {{{ function HealingAbilityFactory:create_emergency_heal
function HealingAbilityFactory:create_emergency_heal(config)
    local emergency_config = {
        name = "Emergency Heal",
        base_power = 50,
        range = 70,
        mana_rate = 8,
        bonus_low_health = 1.0, -- 100% bonus for low health
        generation_conditions = {
            {type = "health_percentage", operator = "<", value = 0.3}
        }
    }
    
    -- Merge with provided config
    for k, v in pairs(config or {}) do
        emergency_config[k] = v
    end
    
    return BasicHeal:new(emergency_config)
end
-- }}}

-- {{{ function HealingAbilityFactory:create_support_ability_set
function HealingAbilityFactory:create_support_ability_set(support_type)
    local ability_sets = {
        cleric = {
            self:create_healing_ability("basic_heal", {base_power = 30}),
            self:create_healing_ability("regeneration", {duration = 10})
        },
        paladin = {
            self:create_healing_ability("emergency_heal", {base_power = 40}),
            self:create_healing_ability("group_heal", {base_power = 20, area_radius = 35})
        },
        druid = {
            self:create_healing_ability("regeneration", {duration = 12, base_power = 20}),
            self:create_healing_ability("group_heal", {base_power = 25, max_targets = 4})
        }
    }
    
    return ability_sets[support_type] or ability_sets.cleric
end
-- }}}

return HealingAbilityFactory
```

### Healing Balance Data (src/data/healing_balance.lua)
```lua
-- {{{ HealingBalance
local HealingBalance = {
    -- Base healing values
    healing_power_base = {
        instant_heal = 30,
        heal_over_time = 15, -- per tick
        group_heal = 25,
        emergency_heal = 50
    },
    
    -- Mana generation rates for healing abilities
    mana_rates = {
        frequent_heal = 8,
        standard_heal = 6,
        powerful_heal = 4,
        emergency_heal = 10 -- Generates faster in emergencies
    },
    
    -- Efficiency modifiers
    efficiency_modifiers = {
        low_health_bonus = 0.5,  -- 50% bonus when target < 50% health
        critical_health_bonus = 1.0, -- 100% bonus when target < 25% health
        overheal_penalty = 0.1,  -- 10% mana waste on overheal
        group_size_bonus = 0.1   -- 10% bonus per additional target
    },
    
    -- Range and area values
    ranges = {
        close_heal = 40,
        standard_heal = 60,
        long_heal = 80,
        group_heal_radius = 40
    }
}
-- }}}

return HealingBalance
```

### Integration with Effect System Enhancement (src/systems/ability_effect_system.lua)
```lua
-- {{{ HealingEffectProcessor enhancement
function AbilityEffectSystem:create_heal_processor()
    return function(activation_event)
        local caster_id = activation_event.caster_id
        local ability = activation_event.ability
        local targets = activation_event.targets
        local efficiency = activation_event.efficiency
        
        local total_healing = 0
        
        for _, target in ipairs(targets) do
            local healing_result = self:apply_healing_effect(caster_id, target, ability, efficiency)
            total_healing = total_healing + healing_result.actual_healing
            
            -- Apply self-healing if ability supports it
            if ability.self_heal_ratio and ability.self_heal_ratio > 0 then
                local self_heal = healing_result.actual_healing * ability.self_heal_ratio
                self:apply_self_healing(caster_id, self_heal)
            end
        end
        
        -- Update healing statistics
        self:update_healing_statistics(caster_id, ability, total_healing)
        
        return true
    end
end
-- }}}
```

### Acceptance Criteria
- [ ] Basic heal abilities target allies with lowest health efficiently
- [ ] Heal over time effects provide sustained healing without overheal waste
- [ ] Group healing abilities find optimal positions to heal multiple allies
- [ ] Emergency healing provides burst healing for critically injured units
- [ ] Healing abilities integrate with mana efficiency system
- [ ] Overheal prevention ensures no mana waste on full health targets
- [ ] Self-healing mechanics provide sustainability for healer units
- [ ] Visual and audio effects clearly indicate healing types
- [ ] Healing abilities balance appropriately with damage output
- [ ] Performance scales with multiple healers and healing effects