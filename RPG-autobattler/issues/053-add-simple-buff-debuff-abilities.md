# Issue #412: Add Simple Buff/Debuff Abilities

## Current Behavior
Damage and healing abilities exist but the game lacks buff and debuff mechanics to create tactical depth and unit synergies.

## Intended Behavior
Implement comprehensive buff and debuff system with stat modifications, duration tracking, stacking mechanics, and strategic counterplay options.

## Implementation Details

### Basic Buff Ability (src/abilities/battle_fury.lua)
```lua
-- {{{ BattleFury
local AbilityComponent = require("src.components.ability")
local BattleFury = {}
BattleFury.__index = BattleFury
setmetatable(BattleFury, AbilityComponent)

function BattleFury:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Battle Fury",
        type = "buff",
        category = "secondary",
        targeting_type = "ally",
        range = config.range or 40,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 4,
        effect_duration = config.duration or 12,
        
        -- Buff properties
        effect_data = {
            buff_type = "battle_fury",
            max_stacks = config.max_stacks or 3,
            stat_modifiers = {
                attack = config.attack_bonus or 0.25,
                attack_speed = config.speed_bonus or 0.15,
                critical_chance = config.crit_bonus or 0.1
            },
            special_effects = {
                damage_bonus = config.damage_bonus or 0.2
            }
        },
        
        -- Targeting preferences
        prefer_damage_dealers = true,
        avoid_full_health_if_combat = true,
        
        -- Generation conditions
        generation_conditions = {
            {type = "combat_state", value = "in_combat"},
            {type = "allies_nearby", operator = ">", value = 0}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "fury_aura",
        sound_effect = config.sound_effect or "buff_cast"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function BattleFury:find_targets
function BattleFury:find_targets(caster_id, entity_manager, targeting_system)
    local allies = targeting_system:find_ally_targets(caster_id,
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager)
    
    if #allies == 0 then return {} end
    
    -- Filter and prioritize targets for battle fury
    local viable_targets = {}
    
    for _, ally in ipairs(allies) do
        local ally_unit = entity_manager:get_component(ally.id, "unit")
        local priority = self:calculate_buff_priority(ally, ally_unit)
        
        if priority > 0 then
            table.insert(viable_targets, {
                id = ally.id,
                position = ally.position,
                health = ally.health,
                unit = ally_unit,
                priority = priority
            })
        end
    end
    
    if #viable_targets == 0 then return {} end
    
    -- Sort by priority (highest first)
    table.sort(viable_targets, function(a, b) return a.priority > b.priority end)
    
    return {viable_targets[1]}
end
-- }}}

-- {{{ function BattleFury:calculate_buff_priority
function BattleFury:calculate_buff_priority(ally, ally_unit)
    local priority = 0
    
    -- Check if already has battle fury
    if ally_unit and ally_unit.active_buffs and ally_unit.active_buffs["battle_fury"] then
        local existing_buff = ally_unit.active_buffs["battle_fury"]
        
        -- Don't rebuff if at max stacks with good duration
        if existing_buff.stacks >= self.effect_data.max_stacks and existing_buff.remaining_time > 6 then
            return 0
        end
        
        -- Lower priority for refreshing existing buff
        priority = priority + 30
    else
        -- Higher priority for new buff
        priority = priority + 60
    end
    
    -- Unit type preferences
    if ally_unit then
        local unit_type_priorities = {
            melee = 40,     -- High priority for melee fighters
            ranged = 35,    -- Good for ranged damage dealers
            hybrid = 30,    -- Decent for hybrid units
            healer = 10,    -- Low priority for pure healers
            tank = 15       -- Low priority for pure tanks
        }
        
        priority = priority + (unit_type_priorities[ally_unit.unit_type] or 20)
    end
    
    -- Combat state bonus
    if ally_unit and ally_unit.combat_state == "in_combat" then
        priority = priority + 25
    end
    
    -- Health consideration (prefer healthy units in combat)
    if ally.health then
        local health_percentage = ally.health.current / ally.health.max
        if health_percentage > 0.7 then
            priority = priority + 15
        end
    end
    
    return priority
end
-- }}}

return BattleFury
```

### Protective Buff Ability (src/abilities/protective_ward.lua)
```lua
-- {{{ ProtectiveWard
local AbilityComponent = require("src.components.ability")
local ProtectiveWard = {}
ProtectiveWard.__index = ProtectiveWard
setmetatable(ProtectiveWard, AbilityComponent)

function ProtectiveWard:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Protective Ward",
        type = "buff",
        category = "secondary",
        targeting_type = "ally",
        range = config.range or 60,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 4,
        effect_duration = config.duration or 15,
        
        -- Protective buff properties
        effect_data = {
            buff_type = "protective_ward",
            max_stacks = config.max_stacks or 1,
            stat_modifiers = {
                armor = config.armor_bonus or 10,
                magic_resist = config.magic_resist_bonus or 8,
                health_regen = config.health_regen or 2
            },
            special_effects = {
                damage_reduction = config.damage_reduction or 0.15,
                debuff_resistance = config.debuff_resistance or 0.3
            }
        },
        
        -- Targeting preferences
        prefer_low_health = true,
        prefer_frontline = true,
        
        -- Generation conditions
        generation_conditions = {
            {type = "allies_nearby", operator = ">=", value = 2},
            {type = "health_percentage", operator = "<", value = 0.8}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "protective_shield",
        sound_effect = config.sound_effect or "ward_cast"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function ProtectiveWard:find_targets
function ProtectiveWard:find_targets(caster_id, entity_manager, targeting_system)
    local allies = targeting_system:find_ally_targets(caster_id,
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager)
    
    if #allies == 0 then return {} end
    
    -- Find allies who would benefit most from protection
    local protection_candidates = {}
    
    for _, ally in ipairs(allies) do
        local ally_unit = entity_manager:get_component(ally.id, "unit")
        local protection_value = self:calculate_protection_value(ally, ally_unit)
        
        if protection_value > 0 then
            table.insert(protection_candidates, {
                id = ally.id,
                position = ally.position,
                health = ally.health,
                unit = ally_unit,
                protection_value = protection_value
            })
        end
    end
    
    if #protection_candidates == 0 then return {} end
    
    -- Sort by protection value (highest first)
    table.sort(protection_candidates, function(a, b) 
        return a.protection_value > b.protection_value 
    end)
    
    return {protection_candidates[1]}
end
-- }}}

-- {{{ function ProtectiveWard:calculate_protection_value
function ProtectiveWard:calculate_protection_value(ally, ally_unit)
    local value = 0
    
    -- Check if already protected
    if ally_unit and ally_unit.active_buffs and ally_unit.active_buffs["protective_ward"] then
        local existing_ward = ally_unit.active_buffs["protective_ward"]
        
        -- Don't recast if ward is still strong
        if existing_ward.remaining_time > 8 then
            return 0
        end
        
        -- Lower value for refreshing
        value = value + 20
    else
        -- Higher value for new protection
        value = value + 50
    end
    
    -- Health-based value (lower health = higher value)
    if ally.health then
        local health_percentage = ally.health.current / ally.health.max
        value = value + (50 - (health_percentage * 40))
        
        -- Extra value for critically injured
        if health_percentage < 0.3 then
            value = value + 30
        end
    end
    
    -- Unit role value
    if ally_unit then
        local role_values = {
            healer = 40,    -- Protect healers first
            ranged = 35,    -- Protect ranged damage dealers
            melee = 25,     -- Standard protection value
            tank = 15       -- Tanks need it least
        }
        
        value = value + (role_values[ally_unit.unit_type] or 25)
    end
    
    return value
end
-- }}}

return ProtectiveWard
```

### Basic Debuff Ability (src/abilities/weakness_curse.lua)
```lua
-- {{{ WeaknessCurse
local AbilityComponent = require("src.components.ability")
local WeaknessCurse = {}
WeaknessCurse.__index = WeaknessCurse
setmetatable(WeaknessCurse, AbilityComponent)

function WeaknessCurse:new(config)
    local ability = AbilityComponent:new({
        name = config.name or "Weakness Curse",
        type = "debuff",
        category = "secondary",
        targeting_type = "enemy",
        range = config.range or 70,
        max_mana_cost = 100,
        mana_generation_rate = config.mana_rate or 5,
        effect_duration = config.duration or 10,
        
        -- Debuff properties
        effect_data = {
            debuff_type = "weakness_curse",
            max_stacks = config.max_stacks or 2,
            stat_modifiers = {
                attack = config.attack_reduction or -0.3,
                attack_speed = config.speed_reduction or -0.2,
                movement_speed = config.movement_reduction or -0.15
            },
            special_effects = {
                damage_reduction = config.damage_reduction or -0.25,
                healing_received_modifier = config.healing_penalty or -0.2
            }
        },
        
        -- Targeting preferences
        target_priority = "highest_value",
        prefer_damage_dealers = true,
        
        -- Generation conditions
        generation_conditions = {
            {type = "enemies_in_range", operator = ">", value = 0},
            {type = "combat_state", value = "in_combat"}
        },
        
        -- Visual and audio
        visual_effect = config.visual_effect or "dark_aura",
        sound_effect = config.sound_effect or "curse_cast"
    })
    
    setmetatable(ability, self)
    return ability
end
-- }}}

-- {{{ function WeaknessCurse:find_targets
function WeaknessCurse:find_targets(caster_id, entity_manager, targeting_system)
    local enemies = targeting_system:find_enemy_targets(caster_id,
        entity_manager:get_component(caster_id, "position"),
        entity_manager:get_component(caster_id, "team"),
        self, entity_manager)
    
    if #enemies == 0 then return {} end
    
    -- Calculate curse priority for each enemy
    local curse_candidates = {}
    
    for _, enemy in ipairs(enemies) do
        local enemy_unit = entity_manager:get_component(enemy.id, "unit")
        local curse_value = self:calculate_curse_value(enemy, enemy_unit)
        
        if curse_value > 0 then
            table.insert(curse_candidates, {
                id = enemy.id,
                position = enemy.position,
                health = enemy.health,
                unit = enemy_unit,
                curse_value = curse_value
            })
        end
    end
    
    if #curse_candidates == 0 then return {} end
    
    -- Sort by curse value (highest first)
    table.sort(curse_candidates, function(a, b) 
        return a.curse_value > b.curse_value 
    end)
    
    return {curse_candidates[1]}
end
-- }}}

-- {{{ function WeaknessCurse:calculate_curse_value
function WeaknessCurse:calculate_curse_value(enemy, enemy_unit)
    local value = 0
    
    -- Check if already cursed
    if enemy_unit and enemy_unit.active_buffs and enemy_unit.active_buffs["weakness_curse"] then
        local existing_curse = enemy_unit.active_buffs["weakness_curse"]
        
        -- Don't recast if curse is at max stacks with good duration
        if existing_curse.stacks >= self.effect_data.max_stacks and existing_curse.remaining_time > 5 then
            return 0
        end
        
        -- Lower value for refreshing/stacking
        value = value + 25
    else
        -- Higher value for new curse
        value = value + 60
    end
    
    -- Target priority based on unit type
    if enemy_unit then
        local target_priorities = {
            melee = 40,     -- High value on melee damage dealers
            ranged = 45,    -- Very high value on ranged threats
            healer = 50,    -- Highest priority on healers
            tank = 20       -- Lower value on tanks
        }
        
        value = value + (target_priorities[enemy_unit.unit_type] or 30)
    end
    
    -- Health consideration (prefer healthier enemies)
    if enemy.health then
        local health_percentage = enemy.health.current / enemy.health.max
        value = value + (health_percentage * 20)
    end
    
    -- Distance consideration (prefer closer enemies)
    value = value + math.max(0, 20 - (enemy.distance / 5))
    
    return value
end
-- }}}

return WeaknessCurse
```

### Buff/Debuff Manager System (src/systems/buff_debuff_system.lua)
```lua
-- {{{ BuffDebuffSystem
local BuffDebuffSystem = {}
BuffDebuffSystem.__index = BuffDebuffSystem

function BuffDebuffSystem:new(entity_manager)
    local system = {
        entity_manager = entity_manager,
        
        -- Active effect tracking
        active_effects = {}, -- [entity_id] = {buff_type = effect_data}
        effect_update_interval = 0.5,
        last_update = 0,
        
        -- Effect categories
        buff_categories = {
            combat = {"battle_fury", "berserker_rage", "precision_aim"},
            protection = {"protective_ward", "magic_shield", "armor_blessing"},
            utility = {"speed_boost", "mana_regen", "invisibility"}
        },
        
        debuff_categories = {
            weakness = {"weakness_curse", "vulnerability", "fatigue"},
            control = {"slow", "stun", "silence"},
            damage = {"poison", "burn", "bleeding"}
        },
        
        -- Stacking rules
        stacking_rules = {
            same_effect = "refresh_duration",  -- Same effect refreshes duration
            same_category = "coexist",         -- Different effects in same category coexist
            opposite_effects = "cancel"        -- Buffs and debuffs can cancel each other
        }
    }
    setmetatable(system, self)
    return system
end
-- }}}

-- {{{ function BuffDebuffSystem:update
function BuffDebuffSystem:update(dt)
    self.last_update = self.last_update + dt
    
    if self.last_update >= self.effect_update_interval then
        self:update_all_effects(self.last_update)
        self.last_update = 0
    end
end
-- }}}

-- {{{ function BuffDebuffSystem:update_all_effects
function BuffDebuffSystem:update_all_effects(dt)
    for entity_id, unit_component in self.entity_manager:iterate_components("unit") do
        if unit_component.active_buffs then
            self:update_entity_effects(entity_id, unit_component, dt)
        end
    end
end
-- }}}

-- {{{ function BuffDebuffSystem:update_entity_effects
function BuffDebuffSystem:update_entity_effects(entity_id, unit_component, dt)
    local effects_to_remove = {}
    
    for effect_type, effect_data in pairs(unit_component.active_buffs) do
        effect_data.remaining_time = effect_data.remaining_time - dt
        
        -- Apply periodic effects
        if effect_data.periodic_effects then
            self:apply_periodic_effects(entity_id, effect_data, dt)
        end
        
        -- Check for expiration
        if effect_data.remaining_time <= 0 then
            table.insert(effects_to_remove, effect_type)
        end
    end
    
    -- Remove expired effects
    for _, effect_type in ipairs(effects_to_remove) do
        self:remove_effect(entity_id, effect_type)
    end
end
-- }}}

-- {{{ function BuffDebuffSystem:apply_effect
function BuffDebuffSystem:apply_effect(entity_id, effect_data)
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if not unit then return false end
    
    if not unit.active_buffs then
        unit.active_buffs = {}
    end
    
    local effect_type = effect_data.debuff_type or effect_data.buff_type
    local existing_effect = unit.active_buffs[effect_type]
    
    if existing_effect then
        -- Handle stacking/refreshing
        self:handle_effect_stacking(existing_effect, effect_data)
    else
        -- Apply new effect
        unit.active_buffs[effect_type] = effect_data
        self:apply_stat_modifiers(entity_id, effect_data.stat_modifiers, 1)
        
        -- Create visual effect
        self:create_effect_visual(entity_id, effect_type, true)
    end
    
    return true
end
-- }}}

-- {{{ function BuffDebuffSystem:handle_effect_stacking
function BuffDebuffSystem:handle_effect_stacking(existing_effect, new_effect)
    if existing_effect.max_stacks and existing_effect.stacks < existing_effect.max_stacks then
        -- Stack the effect
        existing_effect.stacks = existing_effect.stacks + 1
        existing_effect.remaining_time = new_effect.duration
        
        -- Apply additional stat modifiers for stack
        self:apply_stat_modifiers(entity_id, new_effect.stat_modifiers, 1)
    else
        -- Just refresh duration
        existing_effect.remaining_time = new_effect.duration
    end
end
-- }}}

-- {{{ function BuffDebuffSystem:remove_effect
function BuffDebuffSystem:remove_effect(entity_id, effect_type)
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if not unit or not unit.active_buffs then return end
    
    local effect_data = unit.active_buffs[effect_type]
    if not effect_data then return end
    
    -- Remove stat modifiers
    local stacks = effect_data.stacks or 1
    self:apply_stat_modifiers(entity_id, effect_data.stat_modifiers, -stacks)
    
    -- Remove from active effects
    unit.active_buffs[effect_type] = nil
    
    -- Create removal visual effect
    self:create_effect_visual(entity_id, effect_type, false)
end
-- }}}

-- {{{ function BuffDebuffSystem:apply_stat_modifiers
function BuffDebuffSystem:apply_stat_modifiers(entity_id, stat_modifiers, multiplier)
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

-- {{{ function BuffDebuffSystem:cleanse_effects
function BuffDebuffSystem:cleanse_effects(entity_id, effect_types)
    local unit = self.entity_manager:get_component(entity_id, "unit")
    if not unit or not unit.active_buffs then return 0 end
    
    local effects_removed = 0
    effect_types = effect_types or {"debuff"}
    
    for effect_type, effect_data in pairs(unit.active_buffs) do
        local should_remove = false
        
        for _, category in ipairs(effect_types) do
            if category == "debuff" and effect_data.debuff_type then
                should_remove = true
                break
            elseif category == "buff" and effect_data.buff_type then
                should_remove = true
                break
            elseif category == effect_type then
                should_remove = true
                break
            end
        end
        
        if should_remove then
            self:remove_effect(entity_id, effect_type)
            effects_removed = effects_removed + 1
        end
    end
    
    return effects_removed
end
-- }}}

return BuffDebuffSystem
```

### Buff/Debuff Factory (src/factories/buff_debuff_factory.lua)
```lua
-- {{{ BuffDebuffFactory
local BuffDebuffFactory = {}
local BattleFury = require("src.abilities.battle_fury")
local ProtectiveWard = require("src.abilities.protective_ward") 
local WeaknessCurse = require("src.abilities.weakness_curse")

-- {{{ function BuffDebuffFactory:create_buff_ability
function BuffDebuffFactory:create_buff_ability(buff_type, config)
    config = config or {}
    
    if buff_type == "battle_fury" then
        return BattleFury:new(config)
    elseif buff_type == "protective_ward" then
        return ProtectiveWard:new(config)
    elseif buff_type == "speed_boost" then
        return self:create_speed_boost(config)
    elseif buff_type == "mana_regeneration" then
        return self:create_mana_regen_buff(config)
    else
        error("Unknown buff type: " .. tostring(buff_type))
    end
end
-- }}}

-- {{{ function BuffDebuffFactory:create_debuff_ability
function BuffDebuffFactory:create_debuff_ability(debuff_type, config)
    config = config or {}
    
    if debuff_type == "weakness_curse" then
        return WeaknessCurse:new(config)
    elseif debuff_type == "slow" then
        return self:create_slow_debuff(config)
    elseif debuff_type == "vulnerability" then
        return self:create_vulnerability_debuff(config)
    else
        error("Unknown debuff type: " .. tostring(debuff_type))
    end
end
-- }}}

-- {{{ function BuffDebuffFactory:create_support_ability_set
function BuffDebuffFactory:create_support_ability_set(role)
    local ability_sets = {
        commander = {
            self:create_buff_ability("battle_fury"),
            self:create_buff_ability("protective_ward")
        },
        enchanter = {
            self:create_buff_ability("speed_boost"),
            self:create_debuff_ability("weakness_curse")
        },
        guardian = {
            self:create_buff_ability("protective_ward"),
            self:create_debuff_ability("slow")
        }
    }
    
    return ability_sets[role] or ability_sets.commander
end
-- }}}

return BuffDebuffFactory
```

### Acceptance Criteria
- [ ] Buff abilities enhance ally stats and provide tactical advantages
- [ ] Debuff abilities weaken enemy capabilities effectively
- [ ] Effect stacking and duration mechanics work correctly
- [ ] Cleanse abilities can remove appropriate effect types
- [ ] Stat modifiers are applied and removed properly
- [ ] Visual feedback clearly shows active buffs/debuffs
- [ ] Performance scales with many simultaneous effects
- [ ] Integration with existing ability and effect systems works seamlessly
- [ ] Balance between buff power and mana cost is appropriate
- [ ] Targeting prioritization selects optimal buff/debuff targets