# Issue #408: Create Different Ability Types (Damage, Heal, Buff, etc.)

## Current Behavior
Ability framework exists but lacks concrete implementation of specific ability types with their unique behaviors and effects.

## Intended Behavior
Implement comprehensive ability type system with damage, healing, buff, debuff, and area effect abilities, each with specialized behavior and visual effects.

## Implementation Details

### Ability Effect System (src/systems/ability_effect_system.lua)
```lua
-- {{{ AbilityEffectSystem
local AbilityEffectSystem = {}
AbilityEffectSystem.__index = AbilityEffectSystem

function AbilityEffectSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        
        -- Active effects tracking
        active_effects = {},
        effect_id_counter = 1,
        
        -- Effect processors
        effect_processors = {
            damage = self:create_damage_processor(),
            heal = self:create_heal_processor(),
            buff = self:create_buff_processor(),
            debuff = self:create_debuff_processor(),
            area_effect = self:create_area_processor(),
            projectile = self:create_projectile_processor()
        },
        
        -- Visual effects
        visual_effects = {},
        effect_duration_tracking = {}
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function AbilityEffectSystem:process_ability_activation
function AbilityEffectSystem:process_ability_activation(activation_event)
    local ability = activation_event.ability
    local effect_type = ability.type
    local processor = self.effect_processors[effect_type]
    
    if processor then
        return processor(activation_event)
    else
        print("Warning: No processor for ability type: " .. tostring(effect_type))
        return false
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:create_damage_processor
function AbilityEffectSystem:create_damage_processor()
    return function(activation_event)
        local caster_id = activation_event.caster_id
        local ability = activation_event.ability
        local targets = activation_event.targets
        local efficiency = activation_event.efficiency
        
        for _, target in ipairs(targets) do
            self:apply_damage_effect(caster_id, target, ability, efficiency)
        end
        
        return true
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:apply_damage_effect
function AbilityEffectSystem:apply_damage_effect(caster_id, target, ability, efficiency)
    local target_id = target.id
    local target_health = self.entity_manager:get_component(target_id, "health")
    
    if not target_health then return end
    
    -- Calculate damage based on ability and efficiency
    local base_damage = ability.base_power * (efficiency.efficiency or 1.0)
    
    -- Apply damage modifiers
    local final_damage = self:calculate_final_damage(caster_id, target_id, base_damage, ability)
    
    -- Apply damage
    local actual_damage = math.min(final_damage, target_health.current)
    target_health.current = target_health.current - actual_damage
    
    -- Create damage visual effect
    self:create_damage_visual_effect(target_id, actual_damage, ability)
    
    -- Check for death
    if target_health.current <= 0 then
        self:handle_unit_death(caster_id, target_id, ability)
    end
    
    -- Apply secondary effects
    if ability.damage_over_time and ability.damage_over_time > 0 then
        self:apply_damage_over_time(caster_id, target_id, ability)
    end
    
    if ability.knockback_force and ability.knockback_force > 0 then
        self:apply_knockback(caster_id, target_id, ability)
    end
    
    -- Update statistics
    self:update_damage_stats(caster_id, target_id, actual_damage)
end
-- }}}

-- {{{ function AbilityEffectSystem:calculate_final_damage
function AbilityEffectSystem:calculate_final_damage(caster_id, target_id, base_damage, ability)
    -- Get caster stats
    local caster_unit = self.entity_manager:get_component(caster_id, "unit")
    local caster_stats = caster_unit and caster_unit.stats or {}
    
    -- Get target stats
    local target_unit = self.entity_manager:get_component(target_id, "unit")
    local target_stats = target_unit and target_unit.stats or {}
    
    -- Apply attack scaling
    local attack_power = caster_stats.attack or 1.0
    local scaled_damage = base_damage * attack_power * (ability.scaling_factor or 1.0)
    
    -- Apply damage type modifiers
    local damage_type = ability.damage_type or "physical"
    local final_damage = scaled_damage
    
    if damage_type == "physical" then
        local armor = target_stats.armor or 0
        local armor_penetration = ability.armor_penetration or 0
        local effective_armor = math.max(0, armor - armor_penetration)
        local damage_reduction = effective_armor / (effective_armor + 100)
        final_damage = scaled_damage * (1 - damage_reduction)
    elseif damage_type == "magical" then
        local magic_resist = target_stats.magic_resist or 0
        local damage_reduction = magic_resist / (magic_resist + 100)
        final_damage = scaled_damage * (1 - damage_reduction)
    end
    -- "true" damage bypasses all resistances
    
    -- Apply random variance (±10%)
    local variance = 0.9 + (love.math.random() * 0.2)
    final_damage = final_damage * variance
    
    return math.floor(final_damage)
end
-- }}}

-- {{{ function AbilityEffectSystem:create_heal_processor
function AbilityEffectSystem:create_heal_processor()
    return function(activation_event)
        local caster_id = activation_event.caster_id
        local ability = activation_event.ability
        local targets = activation_event.targets
        local efficiency = activation_event.efficiency
        
        for _, target in ipairs(targets) do
            self:apply_heal_effect(caster_id, target, ability, efficiency)
        end
        
        return true
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:apply_heal_effect
function AbilityEffectSystem:apply_heal_effect(caster_id, target, ability, efficiency)
    local target_id = target.id
    local target_health = self.entity_manager:get_component(target_id, "health")
    
    if not target_health then return end
    
    -- Calculate healing based on ability and efficiency
    local base_heal = ability.base_power * (efficiency.efficiency or 1.0)
    
    -- Apply healing modifiers
    local final_heal = self:calculate_final_healing(caster_id, target_id, base_heal, ability)
    
    -- Apply healing
    local health_missing = target_health.max - target_health.current
    local actual_heal = math.min(final_heal, health_missing)
    target_health.current = target_health.current + actual_heal
    
    -- Create healing visual effect
    self:create_heal_visual_effect(target_id, actual_heal, ability)
    
    -- Apply secondary effects
    if ability.cleanse_debuffs then
        self:cleanse_debuffs(target_id)
    end
    
    if ability.heal_over_time_duration and ability.heal_over_time_duration > 0 then
        self:apply_heal_over_time(caster_id, target_id, ability)
    end
    
    -- Self-healing for caster
    if ability.self_heal_ratio and ability.self_heal_ratio > 0 then
        local self_heal = actual_heal * ability.self_heal_ratio
        self:apply_direct_healing(caster_id, self_heal)
    end
    
    -- Update statistics
    self:update_healing_stats(caster_id, target_id, actual_heal)
end
-- }}}

-- {{{ function AbilityEffectSystem:calculate_final_healing
function AbilityEffectSystem:calculate_final_healing(caster_id, target_id, base_heal, ability)
    local caster_unit = self.entity_manager:get_component(caster_id, "unit")
    local caster_stats = caster_unit and caster_unit.stats or {}
    
    local target_unit = self.entity_manager:get_component(target_id, "unit")
    local target_health = self.entity_manager:get_component(target_id, "health")
    
    -- Apply healing power scaling
    local healing_power = caster_stats.healing_power or 1.0
    local scaled_heal = base_heal * healing_power * (ability.scaling_factor or 1.0)
    
    -- Bonus healing for low health targets
    if ability.bonus_low_health and ability.bonus_low_health > 0 and target_health then
        local health_percentage = target_health.current / target_health.max
        if health_percentage < 0.5 then
            scaled_heal = scaled_heal * (1 + ability.bonus_low_health)
        end
    end
    
    return math.floor(scaled_heal)
end
-- }}}

-- {{{ function AbilityEffectSystem:create_buff_processor
function AbilityEffectSystem:create_buff_processor()
    return function(activation_event)
        local caster_id = activation_event.caster_id
        local ability = activation_event.ability
        local targets = activation_event.targets
        
        for _, target in ipairs(targets) do
            self:apply_buff_effect(caster_id, target, ability)
        end
        
        return true
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:apply_buff_effect
function AbilityEffectSystem:apply_buff_effect(caster_id, target, ability)
    local target_id = target.id
    local target_unit = self.entity_manager:get_component(target_id, "unit")
    
    if not target_unit then return end
    
    -- Ensure active_buffs table exists
    if not target_unit.active_buffs then
        target_unit.active_buffs = {}
    end
    
    local buff_type = ability.effect_data.buff_type or ability.name
    local buff_data = {
        type = buff_type,
        power = ability.base_power,
        duration = ability.effect_duration or 10,
        remaining_time = ability.effect_duration or 10,
        caster_id = caster_id,
        stacks = 1,
        max_stacks = ability.effect_data.max_stacks or 1,
        stat_modifiers = ability.effect_data.stat_modifiers or {},
        special_effects = ability.effect_data.special_effects or {}
    }
    
    -- Handle existing buff
    local existing_buff = target_unit.active_buffs[buff_type]
    if existing_buff then
        if existing_buff.stacks < buff_data.max_stacks then
            existing_buff.stacks = existing_buff.stacks + 1
            existing_buff.remaining_time = buff_data.duration -- Refresh duration
        else
            existing_buff.remaining_time = buff_data.duration -- Just refresh duration
        end
    else
        target_unit.active_buffs[buff_type] = buff_data
    end
    
    -- Apply stat modifiers
    self:apply_stat_modifiers(target_id, buff_data.stat_modifiers, 1) -- 1 for adding
    
    -- Create buff visual effect
    self:create_buff_visual_effect(target_id, buff_type, buff_data)
    
    -- Update statistics
    self:update_buff_stats(caster_id, target_id, buff_type)
end
-- }}}

-- {{{ function AbilityEffectSystem:create_area_processor
function AbilityEffectSystem:create_area_processor()
    return function(activation_event)
        local caster_id = activation_event.caster_id
        local ability = activation_event.ability
        local targets = activation_event.targets
        local efficiency = activation_event.efficiency
        
        -- Area effects apply to all targets in the area
        local area_center = self:calculate_area_center(targets)
        
        -- Create area visual effect first
        self:create_area_visual_effect(area_center, ability)
        
        -- Apply effect to each target based on their distance from center
        for _, target in ipairs(targets) do
            local distance_factor = self:calculate_distance_factor(target.position, area_center, ability.area_of_effect)
            self:apply_area_effect_to_target(caster_id, target, ability, efficiency, distance_factor)
        end
        
        return true
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:apply_area_effect_to_target
function AbilityEffectSystem:apply_area_effect_to_target(caster_id, target, ability, efficiency, distance_factor)
    -- Modify ability power based on distance from center
    local modified_ability = {}
    for k, v in pairs(ability) do
        modified_ability[k] = v
    end
    modified_ability.base_power = ability.base_power * distance_factor
    
    -- Apply the underlying effect type
    if ability.area_effect_type == "damage" then
        self:apply_damage_effect(caster_id, target, modified_ability, efficiency)
    elseif ability.area_effect_type == "heal" then
        self:apply_heal_effect(caster_id, target, modified_ability, efficiency)
    elseif ability.area_effect_type == "buff" then
        self:apply_buff_effect(caster_id, target, modified_ability)
    elseif ability.area_effect_type == "debuff" then
        self:apply_debuff_effect(caster_id, target, modified_ability)
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:update
function AbilityEffectSystem:update(dt)
    -- Update all active effects (DoT, HoT, buffs, debuffs)
    self:update_damage_over_time_effects(dt)
    self:update_heal_over_time_effects(dt)
    self:update_buff_durations(dt)
    self:update_visual_effects(dt)
end
-- }}}

-- {{{ function AbilityEffectSystem:update_buff_durations
function AbilityEffectSystem:update_buff_durations(dt)
    for entity_id, unit_component in self.entity_manager:iterate_components("unit") do
        if unit_component.active_buffs then
            local buffs_to_remove = {}
            
            for buff_type, buff_data in pairs(unit_component.active_buffs) do
                buff_data.remaining_time = buff_data.remaining_time - dt
                
                if buff_data.remaining_time <= 0 then
                    table.insert(buffs_to_remove, buff_type)
                end
            end
            
            -- Remove expired buffs
            for _, buff_type in ipairs(buffs_to_remove) do
                self:remove_buff(entity_id, buff_type)
            end
        end
    end
end
-- }}}

-- {{{ function AbilityEffectSystem:remove_buff
function AbilityEffectSystem:remove_buff(entity_id, buff_type)
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if not unit or not unit.active_buffs then return end
    
    local buff_data = unit.active_buffs[buff_type]
    if not buff_data then return end
    
    -- Remove stat modifiers
    self:apply_stat_modifiers(entity_id, buff_data.stat_modifiers, -1) -- -1 for removing
    
    -- Remove buff
    unit.active_buffs[buff_type] = nil
    
    -- Create removal visual effect
    self:create_buff_removal_visual_effect(entity_id, buff_type)
end
-- }}}

-- {{{ function AbilityEffectSystem:apply_stat_modifiers
function AbilityEffectSystem:apply_stat_modifiers(entity_id, stat_modifiers, multiplier)
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if not unit then return end
    
    if not unit.stats then
        unit.stats = {}
    end
    
    for stat_name, modifier_value in pairs(stat_modifiers) do
        local current_value = unit.stats[stat_name] or 0
        unit.stats[stat_name] = current_value + (modifier_value * multiplier)
    end
end
-- }}}

-- Visual effect creation functions would be implemented here
-- These would integrate with the visual effects system

return AbilityEffectSystem
```

### Ability Configuration Templates (src/data/ability_templates.lua)
```lua
-- {{{ AbilityTemplates
local AbilityTemplates = {
    -- Primary Abilities
    primary_melee_attack = {
        type = "damage",
        targeting_type = "enemy",
        range = 35,
        max_mana_cost = 100,
        mana_generation_rate = 10,
        base_power = 25,
        damage_type = "physical",
        generation_conditions = {}, -- Always generates
        visual_effect = "melee_slash",
        sound_effect = "sword_hit"
    },
    
    primary_ranged_attack = {
        type = "projectile",
        targeting_type = "enemy", 
        range = 80,
        max_mana_cost = 100,
        mana_generation_rate = 10,
        base_power = 20,
        damage_type = "physical",
        projectile_speed = 150,
        generation_conditions = {},
        visual_effect = "arrow_shot",
        sound_effect = "bow_release"
    },
    
    -- Secondary Damage Abilities
    power_strike = {
        type = "damage",
        targeting_type = "enemy",
        range = 40,
        max_mana_cost = 100,
        mana_generation_rate = 8,
        base_power = 45,
        damage_type = "physical",
        critical_chance = 0.3,
        critical_multiplier = 2.5,
        generation_conditions = {
            {type = "unit_type", value = "melee"},
            {type = "enemies_in_range", operator = ">", value = 0}
        },
        visual_effect = "power_strike",
        sound_effect = "heavy_hit"
    },
    
    piercing_shot = {
        type = "projectile",
        targeting_type = "enemy",
        range = 100,
        max_mana_cost = 100,
        mana_generation_rate = 8,
        base_power = 35,
        damage_type = "physical",
        armor_penetration = 10,
        max_targets = 3, -- Can hit multiple enemies in line
        generation_conditions = {
            {type = "unit_type", value = "ranged"},
            {type = "is_stationary", value = true}
        },
        visual_effect = "piercing_arrow",
        sound_effect = "pierce_shot"
    },
    
    -- Healing Abilities
    minor_heal = {
        type = "heal",
        targeting_type = "ally",
        range = 60,
        max_mana_cost = 100,
        mana_generation_rate = 6,
        base_power = 30,
        bonus_low_health = 0.5, -- 50% bonus when target < 50% health
        generation_conditions = {
            {type = "allies_nearby", operator = ">", value = 0}
        },
        visual_effect = "healing_light",
        sound_effect = "heal_cast"
    },
    
    regeneration = {
        type = "heal",
        targeting_type = "ally",
        range = 50,
        max_mana_cost = 100,
        mana_generation_rate = 5,
        base_power = 15,
        heal_type = "over_time",
        heal_over_time_duration = 8,
        cleanse_debuffs = true,
        generation_conditions = {
            {type = "health_percentage", operator = "<", value = 0.7}
        },
        visual_effect = "regeneration_aura",
        sound_effect = "regen_cast"
    },
    
    -- Buff Abilities
    battle_fury = {
        type = "buff",
        targeting_type = "ally",
        range = 40,
        max_mana_cost = 100,
        mana_generation_rate = 4,
        effect_duration = 12,
        effect_data = {
            buff_type = "battle_fury",
            max_stacks = 3,
            stat_modifiers = {
                attack = 0.25,
                attack_speed = 0.15
            }
        },
        generation_conditions = {
            {type = "combat_state", value = "in_combat"}
        },
        visual_effect = "fury_aura",
        sound_effect = "buff_cast"
    },
    
    protective_ward = {
        type = "buff",
        targeting_type = "ally",
        range = 60,
        max_mana_cost = 100,
        mana_generation_rate = 4,
        effect_duration = 15,
        effect_data = {
            buff_type = "protective_ward",
            stat_modifiers = {
                armor = 10,
                magic_resist = 8
            },
            special_effects = {
                damage_reduction = 0.15
            }
        },
        generation_conditions = {
            {type = "allies_nearby", operator = ">=", value = 2}
        },
        visual_effect = "protective_shield",
        sound_effect = "ward_cast"
    },
    
    -- Area Effect Abilities
    meteor_strike = {
        type = "area_effect",
        targeting_type = "area",
        range = 90,
        area_of_effect = 35,
        max_mana_cost = 100,
        mana_generation_rate = 3,
        base_power = 40,
        area_effect_type = "damage",
        damage_type = "magical",
        optimal_targets = 3,
        generation_conditions = {
            {type = "enemies_in_range", operator = ">=", value = 2}
        },
        visual_effect = "meteor_impact",
        sound_effect = "explosion"
    },
    
    healing_circle = {
        type = "area_effect",
        targeting_type = "area",
        range = 50,
        area_of_effect = 40,
        max_mana_cost = 100,
        mana_generation_rate = 4,
        base_power = 25,
        area_effect_type = "heal",
        area_target_type = "allies",
        generation_conditions = {
            {type = "allies_nearby", operator = ">=", value = 2}
        },
        visual_effect = "healing_wave",
        sound_effect = "group_heal"
    }
}
-- }}}

return AbilityTemplates
```

### Ability Factory (src/factories/ability_factory.lua)
```lua
-- {{{ AbilityFactory
local AbilityFactory = {}
local AbilityTemplates = require("src.data.ability_templates")

-- {{{ function AbilityFactory:create_ability_from_template
function AbilityFactory:create_ability_from_template(template_name, modifications)
    local template = AbilityTemplates[template_name]
    if not template then
        error("Unknown ability template: " .. tostring(template_name))
    end
    
    -- Create copy of template
    local ability_config = {}
    for k, v in pairs(template) do
        if type(v) == "table" then
            ability_config[k] = {}
            for k2, v2 in pairs(v) do
                ability_config[k][k2] = v2
            end
        else
            ability_config[k] = v
        end
    end
    
    -- Apply modifications
    if modifications then
        for k, v in pairs(modifications) do
            ability_config[k] = v
        end
    end
    
    return ability_config
end
-- }}}

-- {{{ function AbilityFactory:create_unit_ability_set
function AbilityFactory:create_unit_ability_set(unit_type, ability_set_name)
    local ability_sets = {
        basic_warrior = {
            "primary_melee_attack",
            "power_strike"
        },
        basic_archer = {
            "primary_ranged_attack", 
            "piercing_shot"
        },
        support_cleric = {
            "primary_melee_attack",
            "minor_heal",
            "protective_ward"
        },
        battle_mage = {
            "primary_ranged_attack",
            "meteor_strike",
            "battle_fury"
        }
    }
    
    local template_names = ability_sets[ability_set_name]
    if not template_names then
        error("Unknown ability set: " .. tostring(ability_set_name))
    end
    
    local abilities = {}
    for i, template_name in ipairs(template_names) do
        abilities[i] = self:create_ability_from_template(template_name)
    end
    
    return abilities
end
-- }}}

return AbilityFactory
```

### Acceptance Criteria
- [ ] Damage abilities correctly calculate and apply damage with armor/resistance
- [ ] Healing abilities efficiently heal targets and prevent overheal waste
- [ ] Buff abilities stack and expire correctly with stat modifications
- [ ] Debuff abilities apply negative effects with proper duration tracking  
- [ ] Area effect abilities find optimal centers and affect multiple targets
- [ ] Projectile abilities travel and hit targets along their path
- [ ] All ability types integrate with mana efficiency system
- [ ] Visual and audio effects play correctly for each ability type
- [ ] Ability templates allow easy creation of new abilities
- [ ] Performance remains stable with many simultaneous ability effects