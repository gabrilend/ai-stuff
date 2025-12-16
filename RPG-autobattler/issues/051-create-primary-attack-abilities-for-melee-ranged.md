# Issue #410: Create Primary Attack Abilities for Melee/Ranged

## Current Behavior
Ability framework and effect systems exist but lack concrete implementation of the fundamental primary attack abilities for melee and ranged unit types.

## Intended Behavior
Implement robust primary attack abilities that serve as the foundation for all unit combat, with distinct behaviors for melee and ranged units that reflect their tactical roles.

## Implementation Details

### Primary Melee Attack System (src/abilities/primary_melee_attack.lua)
```lua
-- {{{ PrimaryMeleeAttack
local AbilityComponent = require("src.components.ability")
local PrimaryMeleeAttack = {}
PrimaryMeleeAttack.__index = PrimaryMeleeAttack
setmetatable(PrimaryMeleeAttack, AbilityComponent)

function PrimaryMeleeAttack:new(config)
    local ability = AbilityComponent:new({
        name = "Primary Melee Attack",
        type = "damage",
        category = "primary",
        targeting_type = "enemy",
        range = config.range or 35,
        max_mana_cost = 100,
        mana_generation_rate = 10, -- Always generates
        base_power = config.base_power or 25,
        damage_type = "physical",
        
        -- Melee-specific properties
        weapon_type = config.weapon_type or "sword",
        attack_arc = config.attack_arc or 45, -- degrees
        cleave_targets = config.cleave_targets or 0, -- additional targets
        
        -- Animation and timing
        attack_windup = config.attack_windup or 0.3,
        attack_recovery = config.attack_recovery or 0.2,
        animation_duration = 0.5,
        
        -- Generation conditions (none - always generates)
        generation_conditions = {},
        
        -- Visual and audio
        visual_effect = config.visual_effect or "melee_slash",
        sound_effect = config.sound_effect or "sword_swing"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function PrimaryMeleeAttack:find_targets
function PrimaryMeleeAttack:find_targets(caster_id, entity_manager, targeting_system)
    local primary_target = targeting_system:find_closest_enemy(caster_id, self.range, entity_manager)
    
    if not primary_target then
        return {}
    end
    
    local targets = {primary_target}
    
    -- Add cleave targets if ability supports it
    if self.cleave_targets > 0 then
        local cleave_targets = self:find_cleave_targets(caster_id, primary_target, entity_manager)
        for i = 1, math.min(#cleave_targets, self.cleave_targets) do
            table.insert(targets, cleave_targets[i])
        end
    end
    
    return targets
end
-- }}}

-- {{{ function PrimaryMeleeAttack:find_cleave_targets
function PrimaryMeleeAttack:find_cleave_targets(caster_id, primary_target, entity_manager)
    local caster_position = entity_manager:get_component(caster_id, "position")
    local caster_team = entity_manager:get_component(caster_id, "team")
    
    if not caster_position or not caster_team then return {} end
    
    local cleave_targets = {}
    local primary_direction = primary_target.position:subtract(caster_position.value):normalize()
    
    for entity_id, team_component in entity_manager:iterate_components("team") do
        if entity_id ~= caster_id and entity_id ~= primary_target.id and 
           team_component.value ~= caster_team.value then
            
            local target_position = entity_manager:get_component(entity_id, "position")
            local target_health = entity_manager:get_component(entity_id, "health")
            
            if target_position and target_health and target_health.current > 0 then
                local distance = caster_position.value:distance_to(target_position.value)
                
                if distance <= self.range then
                    -- Check if target is within attack arc
                    local target_direction = target_position.value:subtract(caster_position.value):normalize()
                    local angle = math.deg(math.acos(primary_direction:dot(target_direction)))
                    
                    if angle <= self.attack_arc / 2 then
                        table.insert(cleave_targets, {
                            id = entity_id,
                            distance = distance,
                            position = target_position.value,
                            health = target_health,
                            angle = angle
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest cleave targets first)
    table.sort(cleave_targets, function(a, b) return a.distance < b.distance end)
    
    return cleave_targets
end
-- }}}

-- {{{ function PrimaryMeleeAttack:calculate_damage
function PrimaryMeleeAttack:calculate_damage(caster_id, target, entity_manager, is_cleave)
    local base_damage = self.base_power
    
    -- Reduced damage for cleave targets
    if is_cleave then
        base_damage = base_damage * 0.7 -- 70% damage to secondary targets
    end
    
    -- Get caster stats for scaling
    local caster_unit = entity_manager:get_component(caster_id, "unit")
    if caster_unit and caster_unit.stats then
        local attack_power = caster_unit.stats.attack or 1.0
        base_damage = base_damage * attack_power
    end
    
    -- Weapon-specific modifiers
    local weapon_modifier = self:get_weapon_modifier()
    base_damage = base_damage * weapon_modifier
    
    return base_damage
end
-- }}}

-- {{{ function PrimaryMeleeAttack:get_weapon_modifier
function PrimaryMeleeAttack:get_weapon_modifier()
    local weapon_modifiers = {
        sword = 1.0,
        axe = 1.2,    -- Higher damage, slower
        dagger = 0.8, -- Lower damage, faster
        mace = 1.1,   -- Good vs armor
        spear = 0.9   -- Longer range
    }
    
    return weapon_modifiers[self.weapon_type] or 1.0
end
-- }}}

return PrimaryMeleeAttack
```

### Primary Ranged Attack System (src/abilities/primary_ranged_attack.lua)
```lua
-- {{{ PrimaryRangedAttack
local AbilityComponent = require("src.components.ability")
local PrimaryRangedAttack = {}
PrimaryRangedAttack.__index = PrimaryRangedAttack
setmetatable(PrimaryRangedAttack, AbilityComponent)

function PrimaryRangedAttack:new(config)
    local ability = AbilityComponent:new({
        name = "Primary Ranged Attack",
        type = "projectile",
        category = "primary",
        targeting_type = "enemy",
        range = config.range or 80,
        max_mana_cost = 100,
        mana_generation_rate = 10, -- Always generates
        base_power = config.base_power or 20,
        damage_type = "physical",
        
        -- Ranged-specific properties
        projectile_speed = config.projectile_speed or 120,
        projectile_type = config.projectile_type or "arrow",
        accuracy = config.accuracy or 0.95, -- 95% hit chance at max range
        crit_range_bonus = config.crit_range_bonus or 0.1, -- +10% crit at close range
        
        -- Projectile behavior
        piercing = config.piercing or false,
        homing = config.homing or false,
        drop_off_distance = config.drop_off_distance or 100, -- damage reduction beyond this
        
        -- Animation and timing
        draw_time = config.draw_time or 0.4,
        release_time = config.release_time or 0.1,
        animation_duration = 0.5,
        
        -- Generation conditions (none - always generates)
        generation_conditions = {},
        
        -- Visual and audio
        visual_effect = config.visual_effect or "arrow_shot",
        sound_effect = config.sound_effect or "bow_release"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function PrimaryRangedAttack:find_targets
function PrimaryRangedAttack:find_targets(caster_id, entity_manager, targeting_system)
    -- Find best target considering range, line of sight, and priority
    local targets = targeting_system:find_enemy_targets(caster_id, 
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager)
    
    if #targets == 0 then return {} end
    
    -- Sort by targeting priority for ranged units
    targets = self:sort_ranged_targets(caster_id, targets, entity_manager)
    
    -- Return primary target (ranged attacks typically single-target)
    return {targets[1]}
end
-- }}}

-- {{{ function PrimaryRangedAttack:sort_ranged_targets
function PrimaryRangedAttack:sort_ranged_targets(caster_id, targets, entity_manager)
    local caster_position = entity_manager:get_component(caster_id, "position")
    
    -- Calculate targeting scores for each potential target
    for _, target in ipairs(targets) do
        target.targeting_score = self:calculate_target_score(caster_position.value, target, entity_manager)
    end
    
    -- Sort by targeting score (highest first)
    table.sort(targets, function(a, b) return a.targeting_score > b.targeting_score end)
    
    return targets
end
-- }}}

-- {{{ function PrimaryRangedAttack:calculate_target_score
function PrimaryRangedAttack:calculate_target_score(caster_position, target, entity_manager)
    local score = 0
    
    -- Distance scoring (prefer optimal range)
    local distance = target.distance
    local optimal_range = self.range * 0.7 -- 70% of max range is optimal
    
    if distance <= optimal_range then
        score = score + (100 - (distance / optimal_range) * 30) -- 70-100 points
    else
        score = score + (70 - ((distance - optimal_range) / (self.range - optimal_range)) * 40) -- 30-70 points
    end
    
    -- Health scoring (prefer weaker targets for finishing)
    if target.health then
        local health_percentage = target.health.current / target.health.max
        if health_percentage < 0.3 then
            score = score + 20 -- Bonus for low health targets
        end
    end
    
    -- Unit type priority (prefer high-value targets)
    local target_unit = entity_manager:get_component(target.id, "unit")
    if target_unit then
        if target_unit.unit_type == "ranged" then
            score = score + 15 -- Prioritize enemy ranged units
        elseif target_unit.unit_type == "healer" then
            score = score + 25 -- High priority on healers
        end
    end
    
    -- Line of sight bonus
    if self:has_clear_shot(caster_position, target.position, entity_manager) then
        score = score + 10
    else
        score = score - 30 -- Heavy penalty for blocked shots
    end
    
    return score
end
-- }}}

-- {{{ function PrimaryRangedAttack:has_clear_shot
function PrimaryRangedAttack:has_clear_shot(start_pos, end_pos, entity_manager)
    -- Simple line of sight check - would integrate with proper collision system
    local direction = end_pos:subtract(start_pos)
    local distance = direction:length()
    direction = direction:normalize()
    
    local check_interval = 10 -- Check every 10 units
    local num_checks = math.floor(distance / check_interval)
    
    for i = 1, num_checks do
        local check_pos = start_pos:add(direction:multiply(check_interval * i))
        
        -- Check for blocking units (allies)
        if self:is_position_blocked_by_ally(check_pos, entity_manager) then
            return false
        end
    end
    
    return true
end
-- }}}

-- {{{ function PrimaryRangedAttack:calculate_damage
function PrimaryRangedAttack:calculate_damage(caster_id, target, entity_manager, distance)
    local base_damage = self.base_power
    
    -- Distance-based damage modification
    if distance > self.drop_off_distance then
        local drop_off_factor = 1 - ((distance - self.drop_off_distance) / (self.range - self.drop_off_distance)) * 0.3
        base_damage = base_damage * math.max(0.7, drop_off_factor) -- Minimum 70% damage
    end
    
    -- Close range critical bonus
    local close_range_threshold = self.range * 0.4
    if distance <= close_range_threshold then
        local crit_chance = self.crit_range_bonus * (1 - distance / close_range_threshold)
        if love.math.random() < crit_chance then
            base_damage = base_damage * 1.5 -- 50% crit bonus
        end
    end
    
    -- Get caster stats for scaling
    local caster_unit = entity_manager:get_component(caster_id, "unit")
    if caster_unit and caster_unit.stats then
        local attack_power = caster_unit.stats.attack or 1.0
        base_damage = base_damage * attack_power
    end
    
    -- Projectile type modifiers
    local projectile_modifier = self:get_projectile_modifier()
    base_damage = base_damage * projectile_modifier
    
    return base_damage
end
-- }}}

-- {{{ function PrimaryRangedAttack:get_projectile_modifier
function PrimaryRangedAttack:get_projectile_modifier()
    local projectile_modifiers = {
        arrow = 1.0,
        bolt = 1.1,      -- Crossbow bolts - higher damage
        stone = 0.8,     -- Sling stones - lower damage, higher speed
        javelin = 1.2,   -- High damage, shorter range
        magic_missile = 0.9 -- Magic projectile - consistent damage
    }
    
    return projectile_modifiers[self.projectile_type] or 1.0
end
-- }}}

return PrimaryRangedAttack
```

### Primary Ability Factory Integration (src/factories/primary_ability_factory.lua)
```lua
-- {{{ PrimaryAbilityFactory
local PrimaryAbilityFactory = {}
local PrimaryMeleeAttack = require("src.abilities.primary_melee_attack")
local PrimaryRangedAttack = require("src.abilities.primary_ranged_attack")

-- {{{ function PrimaryAbilityFactory:create_primary_ability
function PrimaryAbilityFactory:create_primary_ability(unit_type, weapon_config)
    if unit_type == "melee" then
        return self:create_primary_melee_ability(weapon_config)
    elseif unit_type == "ranged" then
        return self:create_primary_ranged_ability(weapon_config)
    else
        error("Unknown unit type for primary ability: " .. tostring(unit_type))
    end
end
-- }}}

-- {{{ function PrimaryAbilityFactory:create_primary_melee_ability
function PrimaryAbilityFactory:create_primary_melee_ability(config)
    local default_config = {
        range = 35,
        base_power = 25,
        weapon_type = "sword",
        attack_arc = 45,
        cleave_targets = 0
    }
    
    -- Merge with provided config
    local final_config = {}
    for k, v in pairs(default_config) do
        final_config[k] = v
    end
    if config then
        for k, v in pairs(config) do
            final_config[k] = v
        end
    end
    
    return PrimaryMeleeAttack:new(final_config)
end
-- }}}

-- {{{ function PrimaryAbilityFactory:create_primary_ranged_ability
function PrimaryAbilityFactory:create_primary_ranged_ability(config)
    local default_config = {
        range = 80,
        base_power = 20,
        projectile_type = "arrow",
        projectile_speed = 120,
        accuracy = 0.95
    }
    
    -- Merge with provided config
    local final_config = {}
    for k, v in pairs(default_config) do
        final_config[k] = v
    end
    if config then
        for k, v in pairs(config) do
            final_config[k] = v
        end
    end
    
    return PrimaryRangedAttack:new(final_config)
end
-- }}}

-- {{{ function PrimaryAbilityFactory:create_weapon_variant
function PrimaryAbilityFactory:create_weapon_variant(unit_type, weapon_name)
    local weapon_configs = {
        -- Melee weapons
        basic_sword = {
            weapon_type = "sword",
            range = 35,
            base_power = 25,
            attack_arc = 45
        },
        heavy_axe = {
            weapon_type = "axe", 
            range = 30,
            base_power = 32,
            attack_arc = 60,
            cleave_targets = 1
        },
        quick_dagger = {
            weapon_type = "dagger",
            range = 25,
            base_power = 18,
            attack_arc = 30,
            mana_generation_rate = 12 -- Faster generation
        },
        long_spear = {
            weapon_type = "spear",
            range = 45,
            base_power = 22,
            attack_arc = 30
        },
        
        -- Ranged weapons
        hunting_bow = {
            projectile_type = "arrow",
            range = 80,
            base_power = 20,
            projectile_speed = 120
        },
        heavy_crossbow = {
            projectile_type = "bolt",
            range = 90,
            base_power = 28,
            projectile_speed = 150,
            accuracy = 0.98
        },
        war_sling = {
            projectile_type = "stone",
            range = 60,
            base_power = 16,
            projectile_speed = 140
        },
        throwing_spear = {
            projectile_type = "javelin",
            range = 50,
            base_power = 30,
            projectile_speed = 100
        }
    }
    
    local config = weapon_configs[weapon_name]
    if not config then
        error("Unknown weapon variant: " .. tostring(weapon_name))
    end
    
    return self:create_primary_ability(unit_type, config)
end
-- }}}

return PrimaryAbilityFactory
```

### Unit Creation Integration (src/entities/unit.lua enhancement)
```lua
-- {{{ Unit:create_with_primary_ability enhancement
function Unit:create_with_primary_ability(unit_config)
    local unit = self:new(unit_config)
    
    -- Create primary ability based on unit type
    local primary_ability_factory = require("src.factories.primary_ability_factory")
    local primary_ability = primary_ability_factory:create_primary_ability(
        unit.unit_type, 
        unit_config.weapon_config
    )
    
    -- Add to unit's ability list
    local abilities_component = UnitAbilitiesComponent:new({primary_ability})
    
    return unit, abilities_component
end
-- }}}
```

### Balancing and Tuning Data (src/data/primary_ability_balance.lua)
```lua
-- {{{ PrimaryAbilityBalance
local PrimaryAbilityBalance = {
    -- Base damage values for different weapon tiers
    damage_tiers = {
        basic = {melee = 25, ranged = 20},
        improved = {melee = 30, ranged = 24},
        advanced = {melee = 35, ranged = 28},
        elite = {melee = 40, ranged = 32}
    },
    
    -- Range values for different weapon types
    range_values = {
        melee = {min = 25, standard = 35, extended = 45},
        ranged = {short = 60, standard = 80, long = 100}
    },
    
    -- Mana generation rates
    mana_rates = {
        primary_standard = 10,
        primary_fast = 12,
        primary_slow = 8
    },
    
    -- Weapon-specific modifiers
    weapon_balance = {
        sword = {damage_mod = 1.0, speed_mod = 1.0, range_mod = 1.0},
        axe = {damage_mod = 1.3, speed_mod = 0.8, range_mod = 0.9},
        dagger = {damage_mod = 0.7, speed_mod = 1.4, range_mod = 0.8},
        spear = {damage_mod = 0.9, speed_mod = 1.0, range_mod = 1.3},
        bow = {damage_mod = 1.0, speed_mod = 1.0, range_mod = 1.0},
        crossbow = {damage_mod = 1.4, speed_mod = 0.7, range_mod = 1.1},
        sling = {damage_mod = 0.8, speed_mod = 1.3, range_mod = 0.8}
    }
}
-- }}}

return PrimaryAbilityBalance
```

### Acceptance Criteria
- [ ] Melee primary abilities target closest enemies with appropriate range
- [ ] Ranged primary abilities prioritize optimal targets with line-of-sight
- [ ] Weapon types provide distinct tactical differences
- [ ] Cleave mechanics work for multi-target melee weapons
- [ ] Projectile mechanics handle accuracy and damage drop-off
- [ ] Always-generating mana ensures primary abilities are reliable
- [ ] Visual and audio effects differentiate weapon types
- [ ] Performance scales with many units using primary abilities
- [ ] Balance between melee and ranged damage/range is appropriate
- [ ] Integration with existing ability and targeting systems works seamlessly